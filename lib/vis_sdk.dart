/// Flutter plugin for the Vis identity verification SDKs.
///
/// Wraps the native Android (`vis-sdk-android`) and iOS (`vis-sdk-ios`)
/// SDKs: configure once with [Vis.configure], then run [Vis.verify] with
/// the attempt handoff your backend obtained.
library;

export 'src/config.dart';
export 'src/events.dart';
export 'src/verify_request.dart';
export 'src/verify_result.dart';
export 'src/vis.dart';
