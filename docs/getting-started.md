# Getting started

## 1. Prerequisites

- Flutter, stable channel (`flutter doctor` shows no problem for the platform you want).
- Android: Android Studio with an emulator, or a phone with USB debugging. iOS: a Mac with Xcode.
- The API from [go-gin-tenant-template](https://github.com/fiankasepmantea/go-gin-tenant-template) running, with a tenant,
  a tenant user and a group that has been granted the endpoints (`tenantctl group grant --all`).

## 2. Create the native projects

```bash
bash tool/bootstrap.sh
```

It runs `flutter create` for Android and iOS without touching our files, allows the `INTERNET` permission for release
builds, allows plain `http://` for debug builds on Android, sets Android `minSdk` to 23 (needed by
`flutter_secure_storage`) and runs `flutter pub get`. Commit the generated `android/` and `ios/` folders.

## 3. Point the app at your API

```bash
cp config/dart_defines.example.json config/dart_defines.json
```

Edit `API_BASE_URL`: `http://10.0.2.2:8080` (Android emulator), `http://localhost:8080` (iOS simulator), the LAN
address of your computer (real phone), or your `https://` URL. Then:

```bash
flutter run --dart-define-from-file=config/dart_defines.json
```

## 4. Check

```bash
flutter analyze
flutter test
```

## 5. Release

Android: create a keystore, put its settings in `android/key.properties` (ignored by git) and follow
<https://docs.flutter.dev/deployment/android>. Set `version:` in `pubspec.yaml` before each release; the update check
compares that version with the one registered in the backend (`/api/v1/app-versions`, see the backend's
`docs/app-versions.md`). iOS: <https://docs.flutter.dev/deployment/ios>.

Change the application id (`com.example.go_gin_tenant_mobile`), the app name and the icon before publishing. To
rebrand the colors change `seed` in `lib/core/ui/theme.dart`.
