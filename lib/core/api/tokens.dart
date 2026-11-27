import 'api_exception.dart';

/// The pair of tokens the API hands out at login and refresh.
class Tokens {
  const Tokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;

  /// Parses `{"access_token", "refresh_token", "expires_in"}` (the OAuth 2 shape of /auth/login and /auth/refresh).
  factory Tokens.fromResponse(Object? body, DateTime now) {
    if (body is! Map<String, dynamic>) throw const ApiException.unexpected();
    final access = body['access_token'];
    final refresh = body['refresh_token'];
    final expiresIn = body['expires_in'];
    if (access is! String || refresh is! String || access.isEmpty || refresh.isEmpty) {
      throw const ApiException.unexpected();
    }
    final seconds = expiresIn is num ? expiresIn.toInt() : 0;
    return Tokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: now.add(Duration(seconds: seconds)),
    );
  }

  /// True when the access token is still good for at least [skew].
  bool accessUsable(DateTime now, {Duration skew = const Duration(seconds: 30)}) {
    return accessExpiresAt.subtract(skew).isAfter(now);
  }
}

/// Where the tokens live between app starts. The real one is the platform keystore (see secure_token_store.dart).
abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> write(Tokens tokens);
  Future<void> clear();
}
