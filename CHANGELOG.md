# Changelog

All notable changes to the Vis Flutter plugin. This project follows
Semantic Versioning; the plugin version matches the native SDK version it
wraps.

## [1.0.0] — 2026-11-18

First public release.

- `Vis.configure`, `Vis.verify` and `Vis.events`, mirroring the native Vis
  Android and iOS SDKs 1.0.0.
- Typed results: `VerifyApproved`, `VerifyRejected` (`RejectReason`),
  `VerifyReview`, `VerifyTimeout`, `VerifyCancelled`, `VerifyFailed`
  (`VisError` with `VisErrorCode`, parsed `CaptureRejection`).
- Typed analytics events (`VisEvent`), unknown future events kept as
  `UnknownVisEvent`.
- Theme colours, corner radius and fonts (Flutter font assets) passed to
  the native screens.
- Works with a plain `FlutterActivity`; no changes to `MainActivity`.
- iOS through Swift Package Manager or CocoaPods.
