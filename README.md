# Vis Flutter plugin

`vis_sdk` brings Vis identity verification to Flutter apps: identity
document capture, a liveness selfie and attested upload, decided by the Vis
platform. It wraps the native SDKs, so the flow, security and UI are the
same as in native apps:

- Android: [vis-sdk-android](https://github.com/revolution-uz/vis-sdk-android)
- iOS: [vis-sdk-ios](https://github.com/revolution-uz/vis-sdk-ios)

| Plugin | Native SDKs | Android | iOS | Flutter |
|---|---|---|---|---|
| 1.0.0 | 1.0.0 | 8.0+ (API 26) | 15.0+ | 3.32+ |

## How it works

1. Your **backend** creates an attempt: it calls
   `POST https://vis.uz/api/sdk/v1/session/start` with your partner
   credentials (OAuth client credentials). Partner credentials never ship
   inside an app.
2. The backend hands the response (the *handoff*) to your app.
3. The app calls `Vis.verify` with it. The SDK runs its own full-screen
   flow and returns one typed result.
4. The final decision is also delivered to your backend by webhook.

The handoff is single-use and expires after about five minutes: create the
attempt when the user is ready. There is no resume; if the app is killed
mid-flow, create a new attempt.

## Installation

```yaml
dependencies:
  vis_sdk: ^1.0.0
```

### Android

The native SDK, `uz.vis:vis-sdk-android`, comes from Maven Central, which
Flutter projects already include; no repository setup is needed.

Set `minSdk = 26` in `android/app/build.gradle.kts`.

If you build an App Bundle, keep all languages in the base module so the
SDK's Uzbek and Russian texts are not stripped:

```kotlin
android {
    bundle { language { enableSplit = false } }
}
```

**Play Integrity:** the SDK attests the app with Play Integrity. Link a
Google Cloud project to your app in Play Console, pass its project number
as `playIntegrityCloudProjectNumber`, and distribute through Google Play
(an internal testing track is enough for testing). Register your package
name and Play app-signing certificate with vis.uz.

### iOS

Set the platform to iOS 15 (`platform :ios, '15.0'` in `ios/Podfile` when
using CocoaPods). The plugin supports both Swift Package Manager and
CocoaPods.

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>The camera is used to capture your ID document and a selfie for identity verification.</string>
```

**App Attest:** add the *App Attest* capability to the Runner target
(entitlement `com.apple.developer.devicecheck.appattest-environment` =
`production`) and register your Team ID and bundle ID with vis.uz.

## Usage

```dart
import 'package:vis_sdk/vis_sdk.dart';

// Once, e.g. at app start.
await Vis.configure(
  const VisConfig(
    baseUrl: 'https://vis.uz',
    pins: {
      'sha256/brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=',
      'sha256/sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w=',
    },
    locale: 'uz', // uz | ru | en
    playIntegrityCloudProjectNumber: 123456789012, // Android
  ),
);

// Per verification, with the handoff JSON from your backend.
final request = VerifyRequest.fromJson(handoffJson)!;
final result = await Vis.verify(request);

switch (result) {
  case VerifyApproved(:final attemptId):
    onApproved(attemptId);
  case VerifyRejected(:final reason):
    showRejected(reason); // a category only, never a score
  case VerifyReview():
    showPending(); // decision arrives on your backend
  case VerifyTimeout():
    showCheckBackLater(); // the webhook still arrives
  case VerifyCancelled():
    break;
  case VerifyFailed(:final error):
    showError(error); // a platform error, not a rejection of the user
}
```

### Configuration

| Field | Default | |
|---|---|---|
| `baseUrl` | — | Vis origin, `https://vis.uz`. |
| `pins` | `{}` | SPKI pins, `sha256/<base64>`. Required in production. |
| `locale` | `uz` | `uz`, `ru` or `en`. |
| `theme` | native defaults | `VisTheme`: colours, `cornerRadius`, `VisTypography` fonts. |
| `processingTimeout` | `90` | Seconds to wait for a decision (10–600) before `VerifyTimeout`. |
| `showsConsentScreen` | `false` | Show the SDK's consent screen; leave off if your app collects consent. |
| `allowUnpinned` | `false` | Run without pins. Never in production. |
| `playIntegrityCloudProjectNumber` | — | Android, required when attempts require app check. |

### Theme and fonts

```dart
VisTheme(
  primary: Color(0xFF1C62F4),
  cornerRadius: 20,
  typography: VisTypography(
    regular: 'assets/fonts/Onest-Regular.ttf',
    medium: 'assets/fonts/Onest-Medium.ttf',
    semibold: 'assets/fonts/Onest-SemiBold.ttf',
  ),
)
```

Fonts are Flutter asset paths declared in your `pubspec.yaml`; the plugin
registers them with the platform.

### Results

| Result | Meaning | Tell the user |
|---|---|---|
| `VerifyApproved` | Verified. | Continue. |
| `VerifyRejected` | Not verified: `livenessFailed`, `faceMismatch`, `invalidDocument`, `documentDataMismatch` or `unknown`. | Explain the category and offer a new attempt. |
| `VerifyReview` | Sent to manual review. | "We'll let you know." |
| `VerifyTimeout` | No decision within `processingTimeout`. | "Check back later." |
| `VerifyCancelled` | The user left the flow. | Nothing. |
| `VerifyFailed` | A platform or device problem (`VisError.code`), not a decision about the user. | See below. |

| `VisErrorCode` | Meaning |
|---|---|
| `sessionNotFound`, `sessionExpired` | The handoff is unknown, used or expired: create a new attempt. |
| `deviceUnsupported` | The device cannot run verification (e.g. no front camera, no secure key storage). |
| `attestationFailed` | The app or device failed attestation (Play Integrity / App Attest). |
| `captureRejected` | Capture could not be completed; `captureRejection` says why. |
| `rateLimited` | Too many attempts; retry after `retryAfterSeconds`. |
| `networkUnavailable` | No connection. |
| `permissionDenied` | Camera permission denied. |
| `internal` | Unexpected error; `detail` is safe to log. |

`Vis.verify` throws `PlatformException` only when the flow cannot start:
`not_configured`, `busy` (one already running) or `no_activity`.

### Events

```dart
Vis.events.listen((event) {
  switch (event) {
    case StepCompleted(:final step, :final duration): track(step.name, duration);
    default: break;
  }
});
```

Events carry no images, scores or tokens.

## Privacy and security

- Media is never stored on the device; uploads are normalized JPEG with
  metadata stripped and an H.264 selfie clip.
- Transport is TLS with certificate pinning and per-attempt device-bound
  DPoP keys; secrets, URLs and request bodies are never logged.
- Model scores never reach the app.
- iOS: the native SDK ships a privacy manifest declaring the data it
  collects.

## License

Proprietary; see [LICENSE](LICENSE). Use requires an agreement with vis.uz.
