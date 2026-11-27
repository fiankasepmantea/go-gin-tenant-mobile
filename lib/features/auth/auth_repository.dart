import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/parsing.dart';
import '../../core/api/tokens.dart';
import 'me.dart';

/// Login, logout and the password flows (docs/authentication.md in the backend).
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  /// POST /auth/login. The tenant travels in the `X-Tenant-Code` header; after login it comes from the token.
  Future<void> login({
    required String tenantCode,
    required String username,
    required String password,
  }) async {
    final body = await _api.post(
      '/auth/login',
      authenticated: false,
      headers: <String, String>{'X-Tenant-Code': tenantCode},
      data: <String, dynamic>{'username': username, 'password': password},
    );
    final tokens = parseBody<Tokens>(() => Tokens.fromResponse(body, DateTime.now()));
    await _tokens.write(tokens);
  }

  /// POST /auth/logout is idempotent. A failure (offline) must not keep the user signed in on this device.
  Future<void> logout() async {
    final tokens = await _tokens.read();
    if (tokens != null) {
      try {
        await _api.post(
          '/auth/logout',
          authenticated: false,
          data: <String, dynamic>{'refresh_token': tokens.refreshToken},
        );
      } on ApiException {
        // The refresh token expires on the server by itself.
      }
    }
    await _tokens.clear();
  }

  /// POST /auth/password/forgot answers 202 whether or not the account exists.
  Future<void> forgotPassword({required String tenantCode, required String identifier}) async {
    await _api.post(
      '/auth/password/forgot',
      authenticated: false,
      data: <String, dynamic>{'tenant_code': tenantCode, 'identifier': identifier},
    );
  }

  /// POST /auth/password/reset with the token from the e-mail.
  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _api.post(
      '/auth/password/reset',
      authenticated: false,
      data: <String, dynamic>{'token': token, 'new_password': newPassword},
    );
  }

  /// POST /auth/password/change. The server ends every session of the user, including this one, so the stored
  /// tokens are dropped and the user signs in again.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.post(
      '/auth/password/change',
      data: <String, dynamic>{'current_password': currentPassword, 'new_password': newPassword},
    );
    await _tokens.clear();
  }

  /// GET /auth/me
  Future<Me> me() async {
    final body = await _api.get('/auth/me');
    return parseBody<Me>(() => Me.fromJson(asMap(body)));
  }
}
