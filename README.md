# SAAFE Flutter demo

Android and iOS app integrating the published `saafe_aa_sdk: ^1.0.6` package. The lockfile currently resolves **1.0.6**. It opens the real protected consent flow; there is no fake success mode.

## Run

Requires Flutter 3.44.6 / Dart 3.12.2 or compatible newer versions, Android SDK (minimum Android API 24 with this Flutter version), and macOS with Xcode/CocoaPods for iOS (minimum iOS 15).

```sh
flutter pub get
flutter devices
flutter run -d <android-or-ios-device-id>
```

In the app:

1. Enter a registered client ID and select `stage`, `sandbox` or `prod`.
2. Paste a fresh, complete HTTPS consent redirect URL returned by your FI-U backend.
3. Choose full page or bottom sheet, then tap **Open consent flow**.
4. Complete or cancel the hosted flow. The demo displays the callback outcome or an error code and permits retry.

The SDK initializes when you tap the button, before opening the protected flow. Logging is disabled. The supplied consent URL is passed unchanged apart from trimming surrounding whitespace. Theme query parameters must already be present in the backend-generated URL.

Optional defaults can be supplied at launch (use a different client ID for each platform registration as applicable):

```sh
flutter run -d <device-id> \
  --dart-define=SAAFE_CLIENT_ID=<registered-client-id> \
  --dart-define=SAAFE_ENVIRONMENT=sandbox
```

`SAAFE_REDIRECT_URL` is also supported for local testing, but URLs can expire and build-time values are embedded in the app binary. Prefer pasting a fresh URL into the form. No credentials or real consent URLs are included in this repository.

## Register the app

Register these generated application identities with the SAAFE backend, along with signing identity requirements under your backend policy:

| Platform | App identity |
| --- | --- |
| Android application ID | `com.canarabank.mobility` |
| iOS bundle ID | `com.canarabank.mobility` |

For Android certificate information, run `./gradlew signingReport` from `android/`. For a physical iOS device, open `ios/Runner.xcworkspace`, choose your development team under Signing & Capabilities, and use the bundle/team registration issued for that app. Debug Android builds use the local debug keystore. Release signing must be configured before distribution.

The SDK contacts its own environment backend to authorize the host app before opening the WebView. A made-up client ID or an unregistered package/bundle can fail with access denied. Device trust policies may also deny a simulator, emulator, rooted or jailbroken device. Do not bypass trust checks to test consent.

The mobile app receives the consent URL from your backend; FI-U credentials and consent creation belong on that backend. After completion, verify the final consent state there before accessing financial data. The callback is a UI event, not backend authorization.

## Implementation

- `lib/main.dart`: configuration form, URL validation, SDK initialization, protected redirect, and callback handling.
- Terminal callbacks update the demo state. The SDK closes its own screen, so the demo does not call `Navigator.pop` in callbacks.
- Callback summaries accept JSON strings and maps, and display only selected status/error fields. URLs, consent handles, and feedback are excluded. Some SDK completion paths return only a URL, so a completion message can appear without status details.
- Inputs and results remain in memory and reset when the app restarts. No callback payloads are printed.
- Android declares Internet permission and disables cleartext traffic. iOS uses HTTPS without broad ATS exceptions.
- iOS uses CocoaPods. Its deployment target and pod targets are set to iOS 15 for the installed Xcode. Debug simulator builds select arm64 for Apple Silicon to avoid an Xcode 27/Flutter multi-architecture `lipo` verification failure. On an Intel Mac, change the simulator `ARCHS` value in `ios/Flutter/Debug.xcconfig` to `x86_64`.

SDK documentation: [published 1.0.6 package](https://pub.dev/packages/saafe_aa_sdk/versions/1.0.6).

## Validate and build

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
# Signed device build after configuring your Apple team:
flutter build ios --release
```

Tests cover HTTPS validation, callback summaries, empty form validation after scrolling, trust denial recovery, and completion/cancel/error UI handling. Widget tests inject a launcher and simulate SDK events; they do not establish a live backend trust grant. A full live consent test requires a valid registration, a fresh consent URL, and an accepted device.

## Local verification

- `flutter analyze --no-pub`: passed.
- `flutter test --no-pub`: 7 tests passed.
- Android debug APK and iOS debug simulator app: built successfully.
- Android emulator and iOS simulator: installed and launched; configuration screens visually checked.
- Screenshots: `docs/screenshots/android.png` and `docs/screenshots/ios.png`.

The published Android plugin emits a Flutter warning about its use of the Kotlin Gradle Plugin. The current build succeeds; a future Flutter upgrade may require a newer SAAFE plugin with built-in Kotlin support.
