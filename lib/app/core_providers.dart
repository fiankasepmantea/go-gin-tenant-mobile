import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/secure_token_store.dart';
import '../core/api/tokens.dart';
import '../core/config/app_config.dart';

/// Build-time configuration. Tests override it.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>((Ref ref) => AppConfig.fromEnvironment());

/// Where the tokens live. Tests override it with an in-memory store.
final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>((Ref ref) => SecureTokenStore());

/// Light settings (tenant code, language). `main()` and tests override it with a loaded instance.
final Provider<SharedPreferences> sharedPreferencesProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden.'),
);
