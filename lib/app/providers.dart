import 'dart:io' show Platform;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api/api_client.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/me.dart';
import '../features/groups/group.dart';
import '../features/groups/groups_repository.dart';
import '../features/update/app_version_repository.dart';
import '../features/update/update_info.dart';
import '../features/users/users_repository.dart';
import 'core_providers.dart';
import 'session.dart';

export 'core_providers.dart';
export 'session.dart';

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(sessionProvider.notifier).expire(),
  );
});

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);

final Provider<UsersRepository> usersRepositoryProvider =
    Provider<UsersRepository>((Ref ref) => UsersRepository(ref.watch(apiClientProvider)));

final Provider<GroupsRepository> groupsRepositoryProvider =
    Provider<GroupsRepository>((Ref ref) => GroupsRepository(ref.watch(apiClientProvider)));

final Provider<AppVersionRepository> appVersionRepositoryProvider =
    Provider<AppVersionRepository>((Ref ref) => AppVersionRepository(ref.watch(apiClientProvider)));

/// True while a user is signed in. Data providers watch this so they start over after a sign out and sign in.
final Provider<bool> signedInProvider =
    Provider<bool>((Ref ref) => ref.watch(sessionProvider.select((SessionState s) => s.isSignedIn)));

/// The signed-in user (GET /auth/me).
final FutureProvider<Me> meProvider = FutureProvider<Me>((Ref ref) async {
  // Nothing to ask while nobody is signed in; this placeholder is never shown.
  if (!ref.watch(signedInProvider)) return const Me(userId: '', level: 'tenant');
  return ref.watch(authRepositoryProvider).me();
});

/// The groups of the tenant, for names, pickers and filters. Invalidate it after a change.
final FutureProvider<List<Group>> groupsProvider = FutureProvider<List<Group>>((Ref ref) async {
  if (!ref.watch(signedInProvider)) return const <Group>[];
  return ref.watch(groupsRepositoryProvider).list();
});

/// The language of the app, remembered between launches.
class LocaleController extends Notifier<Locale> {
  static const String key = 'locale';

  @override
  Locale build() {
    final saved = ref.read(sharedPreferencesProvider).getString(key);
    if (saved != null && (saved == 'id' || saved == 'en')) return Locale(saved);
    // First launch: follow the phone when it is English, otherwise Indonesian.
    return PlatformDispatcher.instance.locale.languageCode == 'en' ? const Locale('en') : const Locale('id');
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(sharedPreferencesProvider).setString(key, locale.languageCode);
  }
}

final NotifierProvider<LocaleController, Locale> localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// The installed version, read once.
final FutureProvider<PackageInfo> packageInfoProvider = FutureProvider<PackageInfo>((Ref ref) => PackageInfo.fromPlatform());

/// Asks the backend whether a newer version exists. Any failure means "no update": the check must never block
/// someone from using the app.
final FutureProvider<UpdateInfo?> updateProvider = FutureProvider<UpdateInfo?>((Ref ref) async {
  try {
    final info = await ref.watch(packageInfoProvider.future);
    final platform = Platform.isIOS ? 'ios' : 'android';
    return await ref.watch(appVersionRepositoryProvider).check(platform: platform, version: info.version);
  } catch (_) {
    return null;
  }
});
