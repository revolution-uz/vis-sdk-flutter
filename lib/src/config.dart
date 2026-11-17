import 'dart:ui' show Color;

/// One-time SDK configuration, passed to [Vis.configure].
///
/// Mirrors `VisConfig` of the native Android and iOS SDKs.
class VisConfig {
  /// Creates a configuration.
  ///
  /// [baseUrl] is the Vis platform origin, e.g. `https://vis.uz`: `https`,
  /// no path, no trailing slash. [pins] are SPKI pins in `sha256/<base64>`
  /// form; production integrations must provide them.
  const VisConfig({
    required this.baseUrl,
    this.pins = const {},
    this.locale = 'uz',
    this.theme = const VisTheme(),
    this.processingTimeout = 90,
    this.showsConsentScreen = false,
    this.allowUnpinned = false,
    this.playIntegrityCloudProjectNumber,
  });

  /// Vis platform origin, e.g. `https://vis.uz`.
  final String baseUrl;

  /// SPKI certificate pins, `sha256/<base64>`. Required unless
  /// [allowUnpinned] is set (non-production only).
  final Set<String> pins;

  /// UI language: `uz`, `ru` or `en`.
  final String locale;

  /// Colours, corner radius and fonts of the SDK screens.
  final VisTheme theme;

  /// Seconds to wait for the verification decision before returning
  /// [VerifyTimeout] (10–600). The webhook still arrives on your backend.
  final int processingTimeout;

  /// Shows the SDK's own consent screen before capture. Leave `false` when
  /// your app collects consent itself.
  final bool showsConsentScreen;

  /// Allows running without [pins]. Never enable in production.
  final bool allowUnpinned;

  /// Android only: the Google Cloud project number linked to your app in
  /// Play Console, used for Play Integrity. Required whenever your backend
  /// issues attempts with `app_check: required` or `graded`.
  final int? playIntegrityCloudProjectNumber;

  /// Throws [ArgumentError] for values the native SDKs reject.
  void validate() {
    final uri = Uri.tryParse(baseUrl);
    final loopback = uri != null && const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
    if (uri == null ||
        !(uri.scheme == 'https' || (uri.scheme == 'http' && loopback)) ||
        uri.host.isEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'must be an https origin without a path');
    }
    if (pins.any((p) => !p.startsWith('sha256/'))) {
      throw ArgumentError.value(pins, 'pins', 'must be sha256/<base64> SPKI pins');
    }
    if (pins.isEmpty && !allowUnpinned) {
      throw ArgumentError.value(pins, 'pins', 'are required unless allowUnpinned is true');
    }
    if (processingTimeout < 10 || processingTimeout > 600) {
      throw RangeError.range(processingTimeout, 10, 600, 'processingTimeout');
    }
    if (!const {'uz', 'ru', 'en'}.contains(locale)) {
      throw ArgumentError.value(locale, 'locale', 'must be uz, ru or en');
    }
  }

  Map<String, Object?> toChannel() => {
    'baseUrl': baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
    'pins': pins.toList(),
    'locale': locale,
    'theme': theme.toChannel(),
    'processingTimeout': processingTimeout,
    'showsConsentScreen': showsConsentScreen,
    'allowUnpinned': allowUnpinned,
    'playIntegrityCloudProjectNumber': playIntegrityCloudProjectNumber,
  };
}

/// Look of the SDK screens. Every field defaults to the native SDK default.
class VisTheme {
  const VisTheme({
    this.primary,
    this.success,
    this.warning,
    this.warningText,
    this.error,
    this.neutral,
    this.track,
    this.livenessBackground,
    this.cameraBackground,
    this.surface,
    this.textPrimary,
    this.textSecondary,
    this.textOnDark,
    this.disabled,
    this.cornerRadius,
    this.typography = const VisTypography(),
  });

  /// Buttons, progress and accents.
  final Color? primary;
  final Color? success;
  final Color? warning;
  final Color? warningText;
  final Color? error;
  final Color? neutral;
  final Color? track;
  final Color? livenessBackground;
  final Color? cameraBackground;
  final Color? surface;
  final Color? textPrimary;
  final Color? textSecondary;
  final Color? textOnDark;
  final Color? disabled;

  /// Button and card corner radius, in logical pixels (dp / pt).
  final double? cornerRadius;

  final VisTypography typography;

  Map<String, Object?> toChannel() => {
    'primary': ?_argb(primary),
    'success': ?_argb(success),
    'warning': ?_argb(warning),
    'warningText': ?_argb(warningText),
    'error': ?_argb(error),
    'neutral': ?_argb(neutral),
    'track': ?_argb(track),
    'livenessBackground': ?_argb(livenessBackground),
    'cameraBackground': ?_argb(cameraBackground),
    'surface': ?_argb(surface),
    'textPrimary': ?_argb(textPrimary),
    'textSecondary': ?_argb(textSecondary),
    'textOnDark': ?_argb(textOnDark),
    'disabled': ?_argb(disabled),
    'cornerRadius': ?cornerRadius,
    'typography': typography.toChannel(),
  };

  static int? _argb(Color? c) => c?.toARGB32();
}

/// Fonts for the SDK screens, as Flutter asset paths declared in your
/// `pubspec.yaml` (e.g. `assets/fonts/Onest-Regular.ttf`). The plugin
/// registers them with the platform; `null` keeps the system font.
class VisTypography {
  const VisTypography({this.regular, this.medium, this.semibold});

  final String? regular;
  final String? medium;
  final String? semibold;

  Map<String, Object?> toChannel() => {'regular': ?regular, 'medium': ?medium, 'semibold': ?semibold};
}
