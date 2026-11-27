# Architecture

```text
screen (ConsumerWidget)  ->  controller / provider (Riverpod)  ->  repository  ->  ApiClient (Dio)  ->  API
```

## One place for HTTP: `ApiClient`

`lib/core/api/api_client.dart` is the only code that talks HTTP.

- Adds `Authorization: Bearer <access token>` to every call except the public ones (`authenticated: false`).
- Refreshes an access token that is about to expire **before** the call, and once after a `401`, then repeats the call.
- Refresh tokens are single use and rotated by the server (reusing one revokes every session). So concurrent calls
  that need a refresh share **one** refresh request (`_inflightRefresh`).
- If the server refuses the refresh token (a 4xx other than 408 and 429), the tokens are cleared and the session
  callback runs; the router then shows the login screen with a notice. A network error or a 5xx during refresh keeps
  the session, so a bad connection never signs anybody out.
- Every failure is an `ApiException` with the stable `code` of the API. Screens map it to a text with
  `AppStrings.errorText` and to field messages with `AppStrings.fieldError`.

Paths always start with `/` and are relative to `API_BASE_URL/api/v1` (Dio joins the two by plain concatenation).

## Tenants

The tenant code is typed at login and sent as `X-Tenant-Code`. After login the tenant comes from the token, so no
other call sends it. The code is remembered in `SharedPreferences` to prefill the next login.

## Session and routing

`sessionProvider` holds `loading`, `signedOut` or `signedIn`. It starts `loading`, reads the token store once, and is
changed by login, sign out, password change and a refused refresh. `redirectFor` in `lib/app/router.dart` decides where
each state may go and is unit tested. Data providers watch `signedInProvider`, so a new sign in never shows the data
of the previous account.

## Permissions screen

Same rule as the web console: if the group is the one of the signed-in user, a change that removes
`GET /api/v1/groups`, `GET/PUT /api/v1/groups/:id/permissions` or `GET /api/v1/rbac/endpoints` is refused before it is
sent (`lockoutRisk`). When the app cannot find out whether it is the user's own group, it assumes it is.

## Updates

`GET /public/app-versions/check` runs once at start. `force_update` shows a screen that blocks the app and opens the
package or store link. `update_available` without `force_update` shows a note on the Account screen. A failed check never blocks
anything.

## Texts

`lib/core/i18n/strings_id.dart` and `strings_en.dart` hold the texts; `flutter test` checks that both have the same
keys and placeholders and that every key used in `lib/` exists. There is no code generation on purpose.
