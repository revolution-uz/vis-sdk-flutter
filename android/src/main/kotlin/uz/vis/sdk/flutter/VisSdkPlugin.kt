package uz.vis.sdk.flutter

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import uz.vis.sdk.FlowStep
import uz.vis.sdk.SdkError
import uz.vis.sdk.SdkEvent
import uz.vis.sdk.VerifyRequest
import uz.vis.sdk.VerifyResult
import uz.vis.sdk.Vis
import uz.vis.sdk.VisConfig
import uz.vis.sdk.VisDebugApi
import uz.vis.sdk.VisTheme
import uz.vis.sdk.VisTypography

/**
 * Bridges the Vis Android SDK to Dart (`package:vis_sdk`). The channel
 * contract is mirrored by the iOS `VisSdkPlugin.swift`; keep both in sync.
 *
 * The SDK flow is started with `startActivityForResult`, so any Flutter
 * activity works (FlutterActivity or FlutterFragmentActivity).
 */
class VisSdkPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private lateinit var context: Context
    private lateinit var flutterAssets: FlutterPlugin.FlutterAssets
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventsJob: Job? = null

    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null
    private var debugClipDirectory: String? = null
    private val contract = Vis.VerifyContract()

    // ------------------------------------------------------------ lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        flutterAssets = binding.flutterAssets
        methods = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also { it.setStreamHandler(eventHandler) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // -------------------------------------------------------------- methods

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> configure(call, result)
            "verify" -> verify(call, result)
            "sdkVersion" -> result.success(Vis.sdkVersion)
            "debugClipExport" -> {
                debugClipDirectory = call.argument<String>("directoryName") ?: "vis-clips"
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    @OptIn(VisDebugApi::class)
    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        try {
            val theme = call.argument<Map<String, Any?>>("theme").orEmpty()
            Vis.configure(
                context.applicationContext as Application,
                VisConfig(
                    baseUrl = call.argument<String>("baseUrl")!!,
                    pins = call.argument<List<String>>("pins").orEmpty().toSet(),
                    locale = Locale(call.argument<String>("locale") ?: "uz"),
                    theme = theme(theme),
                    processingTimeout = call.argument<Int>("processingTimeout") ?: 90,
                    showsConsentScreen = call.argument<Boolean>("showsConsentScreen") ?: false,
                    allowUnpinned = call.argument<Boolean>("allowUnpinned") ?: false,
                    playIntegrityCloudProjectNumber =
                        call.argument<Number>("playIntegrityCloudProjectNumber")?.toLong(),
                ).apply {
                    debugClipExportDir = debugClipDirectory?.let { File(context.getExternalFilesDir(null), it) }
                },
            )
            result.success(null)
        } catch (e: IllegalArgumentException) {
            result.error("invalid_config", e.message, null)
        } catch (e: RuntimeException) {
            result.error("invalid_config", e.message, null)
        }
    }

    private fun verify(call: MethodCall, result: MethodChannel.Result) {
        val activity = activityBinding?.activity
        when {
            pendingResult != null -> return result.error("busy", "A verification is already running", null)
            !Vis.isConfigured -> return result.error("not_configured", "Call Vis.configure before Vis.verify", null)
            activity == null -> return result.error("no_activity", "The plugin is not attached to an activity", null)
        }
        val request = VerifyRequest(
            attemptId = call.argument<String>("attemptId").orEmpty(),
            bootstrapSecret = call.argument<String>("bootstrapSecret").orEmpty(),
            bootstrapExpiresAt = call.argument<String>("bootstrapExpiresAt").orEmpty(),
            bindNonce = call.argument<String>("bindNonce").orEmpty(),
            capturePolicyVersion = call.argument<String>("capturePolicyVersion").orEmpty(),
            appCheck = call.argument<String>("appCheck"),
            documents = call.argument<String>("documents"),
        )
        pendingResult = result
        activity!!.startActivityForResult(contract.createIntent(activity, request), REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = contract.parseResult(resultCode, data)
        pendingResult?.success(encode(result))
        pendingResult = null
        return true
    }

    // --------------------------------------------------------------- events

    private val eventHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
            eventsJob?.cancel()
            eventsJob = scope.launch {
                Vis.events.collect { event -> mainHandler.post { sink.success(encode(event)) } }
            }
        }

        override fun onCancel(arguments: Any?) {
            eventsJob?.cancel()
            eventsJob = null
        }
    }

    // ---------------------------------------------------------------- theme

    private fun theme(map: Map<String, Any?>): VisTheme {
        val defaults = VisTheme()
        fun color(key: String, fallback: Color) = (map[key] as? Number)?.let { Color(it.toLong() and 0xFFFFFFFFL) } ?: fallback
        @Suppress("UNCHECKED_CAST")
        val fonts = map["typography"] as? Map<String, Any?> ?: emptyMap()
        return VisTheme(
            primary = color("primary", defaults.primary),
            cornerRadius = (map["cornerRadius"] as? Number)?.toFloat()?.dp ?: defaults.cornerRadius,
            success = color("success", defaults.success),
            warning = color("warning", defaults.warning),
            warningText = color("warningText", defaults.warningText),
            error = color("error", defaults.error),
            neutral = color("neutral", defaults.neutral),
            track = color("track", defaults.track),
            livenessBackground = color("livenessBackground", defaults.livenessBackground),
            cameraBackground = color("cameraBackground", defaults.cameraBackground),
            surface = color("surface", defaults.surface),
            textPrimary = color("textPrimary", defaults.textPrimary),
            textSecondary = color("textSecondary", defaults.textSecondary),
            textOnDark = color("textOnDark", defaults.textOnDark),
            disabled = color("disabled", defaults.disabled),
            typography = VisTypography(
                regular = typeface(fonts["regular"] as? String),
                medium = typeface(fonts["medium"] as? String),
                semibold = typeface(fonts["semibold"] as? String),
            ),
        )
    }

    /** A Flutter asset path (as declared in pubspec.yaml) as a Typeface. */
    private fun typeface(assetPath: String?): Typeface? = assetPath?.let {
        runCatching { Typeface.createFromAsset(context.assets, flutterAssets.getAssetFilePathByName(it)) }.getOrNull()
    }

    // ------------------------------------------------------------- encoding

    private fun encode(result: VerifyResult): Map<String, Any?> = when (result) {
        is VerifyResult.Approved -> mapOf("status" to "approved", "attemptId" to result.attemptId)
        is VerifyResult.Rejected -> mapOf("status" to "rejected", "reason" to result.reason.name.lowercase())
        VerifyResult.Review -> mapOf("status" to "review")
        VerifyResult.Timeout -> mapOf("status" to "timeout")
        VerifyResult.Cancelled -> mapOf("status" to "cancelled")
        is VerifyResult.Failed -> mapOf("status" to "failed") + encode(result.error)
    }

    private fun encode(error: SdkError): Map<String, Any?> = when (error) {
        SdkError.SessionNotFound -> mapOf("error" to "session_not_found")
        SdkError.SessionExpired -> mapOf("error" to "session_expired")
        is SdkError.DeviceUnsupported -> mapOf("error" to "device_unsupported", "detail" to error.reason)
        SdkError.AttestationFailed -> mapOf("error" to "attestation_failed")
        is SdkError.CaptureRejected -> mapOf(
            "error" to "capture_rejected",
            "detail" to error.hint,
            "captureReason" to error.reason,
            "attempt" to error.attempt,
            "maxAttempts" to error.maxAttempts,
        )
        is SdkError.RateLimited -> mapOf(
            "error" to "rate_limited",
            "detail" to "retry after ${error.retryAfterSeconds}s",
            "retryAfterSeconds" to error.retryAfterSeconds,
        )
        SdkError.NetworkUnavailable -> mapOf("error" to "network_unavailable")
        SdkError.PermissionDenied -> mapOf("error" to "permission_denied")
        is SdkError.Internal -> mapOf("error" to "internal", "detail" to error.detail)
    }

    private fun encode(event: SdkEvent): Map<String, Any?> = when (event) {
        is SdkEvent.StepStarted -> mapOf("type" to "step_started", "step" to event.step.wireName())
        is SdkEvent.StepCompleted -> mapOf(
            "type" to "step_completed",
            "step" to event.step.wireName(),
            "durationMs" to event.durationMs,
        )
        is SdkEvent.CaptureRetaken -> mapOf(
            "type" to "capture_retaken",
            "step" to event.step.wireName(),
            "gate" to event.gate,
        )
        is SdkEvent.FlowCompleted -> mapOf("type" to "flow_completed", "outcome" to event.outcome)
        is SdkEvent.DocumentTypeChosen -> mapOf("type" to "document_type_chosen", "documentType" to event.documentType)
        is SdkEvent.LivenessIntroShown -> mapOf("type" to "liveness_intro_shown")
        is SdkEvent.LivenessIntroStartTapped -> mapOf(
            "type" to "liveness_intro_start_tapped",
            "timeOnScreenMs" to event.timeOnScreenMs,
        )
        is SdkEvent.LivenessIntroBack -> mapOf("type" to "liveness_intro_back")
        is SdkEvent.LivenessHelpOpened -> buildMap {
            put("type", "liveness_help_opened")
            put("phase", event.phase.wireName)
            put("attempt", event.attempt)
            event.turnSide?.let { put("turnSide", it.wireName) }
        }
        is SdkEvent.LivenessHelpClosed -> buildMap {
            put("type", "liveness_help_closed")
            put("method", event.method.wireName)
            put("timeOpenMs", event.timeOpenMs)
            put("attempt", event.attempt)
            event.turnSide?.let { put("turnSide", it.wireName) }
        }
    }

    private fun FlowStep.wireName() = name.lowercase()

    private companion object {
        const val METHOD_CHANNEL = "uz.vis.sdk/flutter"
        const val EVENT_CHANNEL = "uz.vis.sdk/flutter/events"
        const val REQUEST_CODE = 0x5649 // "VI"
    }
}
