# sunrise_alarm

A new Flutter project.

## Build and publish (Android)

1. Bump version in `pubspec.yaml` (e.g., 1.0.0+1)

2. Create a signing key (once) and save `key.properties` in the Android folder (do NOT commit it):

- key.properties
  - storeFile=/absolute/path/to/keystore.jks
  - storePassword=...
  - keyAlias=...
  - keyPassword=...

3. Build a release bundle (AAB):

- `flutter build appbundle`

4. Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

5. On first publish, complete: App details, screenshots, privacy policy URL, Data safety, Content rating. Declare permissions used (Location, Notifications, Exact alarm, Wake lock, Boot completed).

## App name and icon

- Android label is set to "Sunrise Alarm" in `android/app/src/main/AndroidManifest.xml`.
- Configure launcher icons using flutter_launcher_icons if needed.

## iOS build (requires macOS)

- Set Bundle Identifier and signing in Xcode, then Archive and distribute to App Store Connect.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
