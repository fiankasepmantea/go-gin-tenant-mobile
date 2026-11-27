# go-gin-tenant-mobile

Flutter app for [go-gin-tenant-template](https://github.com/fiankasepmantea/go-gin-tenant-template), the Go multi-tenant
API. It is the mobile sibling of [go-gin-tenant-web](https://github.com/fiankasepmantea/go-gin-tenant-web): the same
screens and rules, for Android and iOS. Indonesian and English are built in.

What it does: sign in with a tenant code, username and password; forgot and reset password; **users** (list with
filters and paging, add, edit, activate, deactivate, delete); **groups** (add, edit, delete) and their **permissions**
(with the same lockout guard as the web console); **account** (language, change password, sign out); and an
**update check** that can require a newer version of the app.

Stack: Flutter (stable), Riverpod, go_router, Dio, flutter_secure_storage. No code generation.

## Run it

Needs Flutter (stable channel) and the API running (backend: `make run`, default `http://localhost:8080`).

```bash
bash tool/bootstrap.sh                                  # once: creates android/ and ios/, applies native changes, pub get
cp config/dart_defines.example.json config/dart_defines.json   # ignored by git; set API_BASE_URL
flutter run --dart-define-from-file=config/dart_defines.json
```

`API_BASE_URL` is the origin of the API without a path or trailing slash. The default `http://10.0.2.2:8080` is your
computer as seen from the Android emulator. On a real phone use the LAN address of your computer or an https URL; on
the iOS simulator use `http://localhost:8080`. Debug builds on Android allow plain `http://`; release builds need https.

Sign in with the tenant code, username and password of a tenant user (backend `docs/getting-started.md`). The user's
group must be granted the endpoints the screens call (a group created with `--all` has them).

| Command | Does |
|---|---|
| `flutter analyze` | static analysis |
| `flutter test` | unit and widget tests |
| `flutter build apk --dart-define-from-file=config/dart_defines.json` | release APK (needs signing, see `docs/getting-started.md`) |

## Layout

```text
lib/app/        providers, session, router, MaterialApp
lib/core/       api client, tokens, config, i18n, shared widgets
lib/features/   auth, users, groups, account, update  (screens, repositories, models)
test/           api client, i18n parity, session and router, users controller, login form
```

More: [docs/architecture.md](docs/architecture.md), [docs/getting-started.md](docs/getting-started.md)
([Bahasa Indonesia](docs/getting-started.id.md)), and the rules for contributors in [CLAUDE.md](CLAUDE.md).
