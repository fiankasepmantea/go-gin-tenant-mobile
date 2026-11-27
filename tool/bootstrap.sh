#!/usr/bin/env bash
# One-time setup: creates the android/ and ios/ folders around the Dart code and applies the few native changes
# the app needs. Safe to run again. Needs Flutter (stable) in PATH and python3.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not in PATH. Install it from https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

if [ ! -d android ] || [ ! -d ios ]; then
  # `flutter create` must not replace our files. Keep copies and put them back.
  backup="$(mktemp -d)"
  for f in lib/main.dart pubspec.yaml analysis_options.yaml README.md .gitignore; do
    if [ -f "$f" ]; then
      mkdir -p "$backup/$(dirname "$f")"
      cp "$f" "$backup/$f"
    fi
  done
  flutter create . --platforms android,ios --project-name go_gin_tenant_mobile --org com.example
  for f in lib/main.dart pubspec.yaml analysis_options.yaml README.md .gitignore; do
    if [ -f "$backup/$f" ]; then
      cp "$backup/$f" "$f"
    fi
  done
  rm -rf "$backup"
fi

# The sample test of `flutter create` refers to a widget that does not exist in this app.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

python3 - <<'PY'
import re
from pathlib import Path

# 1. Release builds need the INTERNET permission (flutter create only adds it to debug and profile).
manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
if "android.permission.INTERNET" not in text:
    text = re.sub(
        r"(<manifest[^>]*>)",
        r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>',
        text,
        count=1,
    )
    manifest.write_text(text)

# 2. Debug builds may talk to a plain http:// API on your machine. Release builds stay https only.
debug = Path("android/app/src/debug/AndroidManifest.xml")
if debug.exists():
    text = debug.read_text()
    if "usesCleartextTraffic" not in text:
        text = text.replace(
            "</manifest>",
            '    <application android:usesCleartextTraffic="true"/>\n</manifest>',
        )
        debug.write_text(text)

# 3. flutter_secure_storage needs Android 6 (API 23) or newer.
for name in ("android/app/build.gradle", "android/app/build.gradle.kts"):
    gradle = Path(name)
    if gradle.exists():
        text = gradle.read_text()
        if "flutter.minSdkVersion" in text:
            gradle.write_text(text.replace("flutter.minSdkVersion", "23"))
PY

flutter pub get
echo
echo "Done. Next: flutter analyze && flutter test"
echo "Run the app: flutter run --dart-define-from-file=config/dart_defines.json (copy config/dart_defines.example.json first)"
