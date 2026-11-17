import CoreText
import Flutter
import UIKit
@_spi(VisDebug) import VisSDK

/// Bridges the Vis iOS SDK to Dart (`package:vis_sdk`). The channel contract
/// is mirrored by the Android `VisSdkPlugin.kt`; keep both in sync.
public final class VisSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private static let methodChannel = "uz.vis.sdk/flutter"
    private static let eventChannel = "uz.vis.sdk/flutter/events"

    private let registrar: FlutterPluginRegistrar
    private var verifying = false
    private var debugClipDirectory: String?

    private init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VisSdkPlugin(registrar: registrar)
        let methods = FlutterMethodChannel(name: methodChannel, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methods)
        FlutterEventChannel(name: eventChannel, binaryMessenger: registrar.messenger())
            .setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "configure": configure(args, result: result)
        case "verify": verify(args, result: result)
        case "sdkVersion": result(Vis.sdkVersion)
        case "debugClipExport":
            debugClipDirectory = args["directoryName"] as? String ?? "vis-clips"
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Methods

    private func configure(_ args: [String: Any], result: @escaping FlutterResult) {
        // VisConfig enforces its invariants with preconditions (a crash, not a
        // throw). Dart validates first; re-check the invariants here so a bad
        // call can never crash the host.
        guard let raw = args["baseUrl"] as? String, let baseURL = URL(string: raw),
              baseURL.scheme == "https" || ["localhost", "127.0.0.1"].contains(baseURL.host ?? "")
        else {
            result(FlutterError(code: "invalid_config", message: "baseUrl must be an https origin", details: nil))
            return
        }
        let pins = Set(args["pins"] as? [String] ?? [])
        let allowUnpinned = args["allowUnpinned"] as? Bool ?? false
        let timeout = args["processingTimeout"] as? Int ?? 90
        guard pins.allSatisfy({ $0.hasPrefix("sha256/") }), !pins.isEmpty || allowUnpinned,
              (10...600).contains(timeout)
        else {
            result(FlutterError(code: "invalid_config", message: "invalid pins or processingTimeout", details: nil))
            return
        }
        var config = VisConfig(
            baseURL: baseURL,
            pins: pins,
            locale: Locale(identifier: args["locale"] as? String ?? "uz"),
            theme: theme(args["theme"] as? [String: Any] ?? [:]),
            processingTimeout: timeout,
            showsConsentScreen: args["showsConsentScreen"] as? Bool ?? false,
            allowUnpinned: allowUnpinned
        )
        if let debugClipDirectory {
            config.debugClipExportDirectory = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent(debugClipDirectory, isDirectory: true)
        }
        Vis.configure(config)
        result(nil)
    }

    private func verify(_ args: [String: Any], result: @escaping FlutterResult) {
        guard !verifying else {
            result(FlutterError(code: "busy", message: "A verification is already running", details: nil))
            return
        }
        guard Vis.isConfigured else {
            result(FlutterError(code: "not_configured", message: "Call Vis.configure before Vis.verify", details: nil))
            return
        }
        guard let presenter = Self.topViewController() else {
            result(FlutterError(code: "no_activity", message: "No view controller to present from", details: nil))
            return
        }
        let request = VerifyRequest(
            attemptId: args["attemptId"] as? String ?? "",
            bootstrapSecret: args["bootstrapSecret"] as? String ?? "",
            bootstrapExpiresAt: args["bootstrapExpiresAt"] as? String ?? "",
            bindNonce: args["bindNonce"] as? String ?? "",
            capturePolicyVersion: args["capturePolicyVersion"] as? String ?? "",
            appCheck: args["appCheck"] as? String,
            documents: args["documents"] as? String
        )
        verifying = true
        Vis.verification(request).present(from: presenter) { [weak self] outcome in
            self?.verifying = false
            result(Self.encode(outcome))
        }
    }

    // MARK: - Events

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Vis delivers events on the main thread.
        Vis.eventHandler = { event in events(Self.encode(event)) }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Vis.eventHandler = nil
        return nil
    }

    // MARK: - Theme

    private func theme(_ map: [String: Any]) -> VisTheme {
        var theme = VisTheme()
        func color(_ key: String) -> UIColor? {
            guard let argb = (map[key] as? NSNumber)?.uint32Value else { return nil }
            return UIColor(
                red: CGFloat((argb >> 16) & 0xFF) / 255,
                green: CGFloat((argb >> 8) & 0xFF) / 255,
                blue: CGFloat(argb & 0xFF) / 255,
                alpha: CGFloat((argb >> 24) & 0xFF) / 255
            )
        }
        let colors: [(String, WritableKeyPath<VisTheme, UIColor>)] = [
            ("primary", \.primary), ("success", \.success), ("warning", \.warning),
            ("warningText", \.warningText), ("error", \.error), ("neutral", \.neutral),
            ("track", \.track), ("livenessBackground", \.livenessBackground),
            ("cameraBackground", \.cameraBackground), ("surface", \.surface),
            ("textPrimary", \.textPrimary), ("textSecondary", \.textSecondary),
            ("textOnDark", \.textOnDark), ("disabled", \.disabled),
        ]
        for (key, path) in colors {
            if let value = color(key) { theme[keyPath: path] = value }
        }
        if let radius = (map["cornerRadius"] as? NSNumber)?.doubleValue {
            theme.cornerRadius = CGFloat(radius)
        }
        let fonts = map["typography"] as? [String: Any] ?? [:]
        theme.typography = VisTypography(
            regular: fontName(asset: fonts["regular"] as? String),
            medium: fontName(asset: fonts["medium"] as? String),
            semibold: fontName(asset: fonts["semibold"] as? String)
        )
        return theme
    }

    /// Registers a Flutter font asset with Core Text (UIKit does not see
    /// Flutter assets) and returns its PostScript name.
    private func fontName(asset: String?) -> String? {
        guard let asset else { return nil }
        let key = registrar.lookupKey(forAsset: asset)
        guard let url = Bundle.main.url(forResource: key, withExtension: nil),
              let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider),
              let name = font.postScriptName as String?
        else { return nil }
        // A repeat registration fails harmlessly: the font is already there.
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return name
    }

    // MARK: - Encoding (wire names match the Android plugin)

    private static func encode(_ result: VerifyResult) -> [String: Any] {
        switch result {
        case .approved(let attemptId): return ["status": "approved", "attemptId": attemptId]
        case .rejected(let reason): return ["status": "rejected", "reason": snakeCase(reason.rawValue)]
        case .review: return ["status": "review"]
        case .timeout: return ["status": "timeout"]
        case .cancelled: return ["status": "cancelled"]
        case .failed(let error): return ["status": "failed"].merging(encode(error)) { $1 }
        @unknown default: return ["status": "failed", "error": "internal", "detail": "unknown result"]
        }
    }

    private static func encode(_ error: VisError) -> [String: Any] {
        switch error {
        case .sessionNotFound: return ["error": "session_not_found"]
        case .sessionExpired: return ["error": "session_expired"]
        case .deviceUnsupported(let reason): return ["error": "device_unsupported", "detail": reason]
        case .attestationFailed: return ["error": "attestation_failed"]
        case .captureRejected(let hint):
            var map: [String: Any] = ["error": "capture_rejected", "detail": hint]
            if let rejection = error.captureRejection {
                map["captureReason"] = rejection.reason
                if let attempt = rejection.attempt { map["attempt"] = attempt }
                if let maxAttempts = rejection.maxAttempts { map["maxAttempts"] = maxAttempts }
            }
            return map
        case .rateLimited(let seconds):
            return ["error": "rate_limited", "detail": "retry after \(seconds)s", "retryAfterSeconds": seconds]
        case .networkUnavailable: return ["error": "network_unavailable"]
        case .permissionDenied: return ["error": "permission_denied"]
        case .internalError(let detail): return ["error": "internal", "detail": detail]
        @unknown default: return ["error": "internal", "detail": "unknown error"]
        }
    }

    private static func encode(_ event: VisEvent) -> [String: Any] {
        switch event {
        case .stepStarted(let step):
            return ["type": "step_started", "step": snakeCase(step.rawValue)]
        case .stepCompleted(let step, let durationMs):
            return ["type": "step_completed", "step": snakeCase(step.rawValue), "durationMs": durationMs]
        case .captureRetaken(let step, let gate):
            return ["type": "capture_retaken", "step": snakeCase(step.rawValue), "gate": gate]
        case .flowCompleted(let outcome):
            return ["type": "flow_completed", "outcome": outcome]
        case .documentTypeChosen(let documentType):
            return ["type": "document_type_chosen", "documentType": documentType]
        case .livenessIntroShown:
            return ["type": "liveness_intro_shown"]
        case .livenessIntroStartTapped(let timeOnScreenMs):
            return ["type": "liveness_intro_start_tapped", "timeOnScreenMs": timeOnScreenMs]
        case .livenessIntroBack:
            return ["type": "liveness_intro_back"]
        case .livenessHelpOpened(let phase, let attempt, let turnSide):
            return withSide(["type": "liveness_help_opened", "phase": phase.rawValue, "attempt": attempt], turnSide)
        case .livenessHelpClosed(let method, let timeOpenMs, let attempt, let turnSide):
            return withSide(["type": "liveness_help_closed", "method": method.rawValue,
                             "timeOpenMs": timeOpenMs, "attempt": attempt], turnSide)
        @unknown default:
            return ["type": "unknown"]
        }
    }

    private static func withSide(_ fields: [String: Any], _ side: LivenessTurnSide?) -> [String: Any] {
        var fields = fields
        if let side { fields["turnSide"] = side.rawValue }
        return fields
    }

    /// `capturingDocumentFront` -> `capturing_document_front`
    private static func snakeCase(_ camel: String) -> String {
        camel.reduce(into: "") { out, ch in
            if ch.isUppercase { out += "_" + ch.lowercased() } else { out.append(ch) }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
