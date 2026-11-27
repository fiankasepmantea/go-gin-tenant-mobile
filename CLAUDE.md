# Rules for AI assistants and contributors

Backend: https://github.com/fiankasepmantea/go-gin-tenant-template (its `docs/http-api.md` and `/openapi.json` are the API contract).
Web console: https://github.com/fiankasepmantea/go-gin-tenant-web (same screens, same rules; `src/i18n/messages.ts` has the texts).

## Required

- Everything in this repository is written in English: code, comments, documentation, commit messages, pull request
  descriptions. The only exceptions are the UI texts in `lib/core/i18n/strings_id.dart` and `strings_en.dart`, and the
  Indonesian translations of documents, which sit next to the English file (`*.id.md`). Add every UI text to both
  dictionaries; `flutter test` fails when the keys differ.
- Branch on `ApiException.code` (the `error.code` of the API), never on the message text.
- All HTTP goes through `lib/core/api/api_client.dart`. Screens and controllers never use Dio directly.
- Tokens live only in `SecureTokenStore` (Android Keystore, iOS Keychain). Never in `SharedPreferences`, logs or
  screens.
- Paths passed to `ApiClient` start with `/` and are relative to `/api/v1`.
- Run `flutter analyze` and `flutter test` before finishing.

## Forbidden

- Reading, creating or committing real configuration (`config/dart_defines.json`, keystores, `key.properties`). Only
  `*.example` files, without secrets.
- Adding a dependency without a reason in the pull request description.
- Calling a user-facing text by a hard-coded string. Use `context.s.t('key')`.
- Copying third-party designs, wordmarks, images or licensed fonts.
