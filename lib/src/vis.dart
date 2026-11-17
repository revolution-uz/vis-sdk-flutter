import 'package:flutter/services.dart';

import 'config.dart';
import 'events.dart';
import 'verify_request.dart';
import 'verify_result.dart';

const _methods = MethodChannel('uz.vis.sdk/flutter');
const _events = EventChannel('uz.vis.sdk/flutter/events');

/// Entry point of the Vis identity verification SDK.
///
/// ```dart
/// await Vis.configure(const VisConfig(baseUrl: 'https://vis.uz', pins: {...}));
/// final result = await Vis.verify(request);
/// ```
abstract final class Vis {
  /// Configures the SDK. Call once, before [verify]; calling again replaces
  /// the configuration. Throws [ArgumentError] for an invalid [config].
  static Future<void> configure(VisConfig config) {
    config.validate();
    return _methods.invokeMethod<void>('configure', config.toChannel());
  }

  /// Runs one verification and completes with its outcome. The SDK presents
  /// its own full-screen flow; only one verification can run at a time.
  ///
  /// Throws [PlatformException] with code `not_configured`, `busy` or
  /// `no_activity` when the flow cannot start. Everything that happens once
  /// it starts is reported as a [VerifyResult].
  static Future<VerifyResult> verify(VerifyRequest request) async {
    final map = await _methods.invokeMapMethod<Object?, Object?>('verify', request.toChannel());
    return VerifyResult.fromChannel(map ?? const {});
  }

  /// Version of the linked native SDK, e.g. `1.0.0`.
  static Future<String> get nativeSdkVersion async => await _methods.invokeMethod<String>('sdkVersion') ?? '';

  /// Analytics events of the running verification.
  static final Stream<VisEvent> events = _events.receiveBroadcastStream().cast<Map<Object?, Object?>>().map(
    VisEvent.fromChannel,
  );
}
