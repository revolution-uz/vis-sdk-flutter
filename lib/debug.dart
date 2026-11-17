/// Debug-only hooks for internal test apps. Never use in production.
///
/// Not exported from `package:vis_sdk/vis_sdk.dart`; import this library
/// explicitly.
library;

import 'package:flutter/services.dart';

const _methods = MethodChannel('uz.vis.sdk/flutter');

/// Debug-only hooks. Never use in production.
abstract final class VisDebug {
  /// Keeps a copy of every uploaded selfie clip on the device: raw biometric
  /// video, never deleted by the SDK. For internal test builds only.
  ///
  /// Android writes to `<external files dir>/<directoryName>`; iOS writes to
  /// `Documents/<directoryName>` (visible in Files when the app enables file
  /// sharing). Applies from the next [Vis.configure] call.
  static Future<void> enableClipExport({String directoryName = 'vis-clips'}) =>
      _methods.invokeMethod<void>('debugClipExport', {'directoryName': directoryName});
}
