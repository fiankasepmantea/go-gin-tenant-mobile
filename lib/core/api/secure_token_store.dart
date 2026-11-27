import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tokens.dart';

/// Tokens in the Android Keystore (EncryptedSharedPreferences) and the iOS Keychain.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _access = 'tc_access_token';
  static const String _refresh = 'tc_refresh_token';
  static const String _expires = 'tc_access_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<Tokens?> read() async {
    try {
      final refresh = await _storage.read(key: _refresh);
      if (refresh == null || refresh.isEmpty) return null;
      final access = await _storage.read(key: _access) ?? '';
      final expires = int.tryParse(await _storage.read(key: _expires) ?? '') ?? 0;
      return Tokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: DateTime.fromMillisecondsSinceEpoch(expires),
      );
    } catch (_) {
      // A damaged keystore (for example after a restore from backup) must not trap the user: sign in again.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(Tokens tokens) async {
    await _storage.write(key: _access, value: tokens.accessToken);
    await _storage.write(key: _refresh, value: tokens.refreshToken);
    await _storage.write(
      key: _expires,
      value: tokens.accessExpiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _access);
      await _storage.delete(key: _refresh);
      await _storage.delete(key: _expires);
    } catch (_) {
      // Nothing more can be done; the tokens are ignored when the refresh token is missing.
    }
  }
}
