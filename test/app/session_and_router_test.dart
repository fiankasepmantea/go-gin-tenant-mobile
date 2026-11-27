import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_gin_tenant_mobile/app/providers.dart';
import 'package:go_gin_tenant_mobile/app/router.dart';
import 'package:go_gin_tenant_mobile/core/api/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/memory_token_store.dart';

Future<ProviderContainer> _container({Tokens? tokens, Map<String, Object> prefs = const <String, Object>{}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(preferences),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore(tokens)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(sessionProvider, (SessionState? a, SessionState b) {});
  await pumpEventQueue();
  return container;
}

void main() {
  group('session', () {
    test('without stored tokens the user is signed out, with the remembered tenant', () async {
      final container = await _container(prefs: <String, Object>{'tenant_code': 'acme'});
      final state = container.read(sessionProvider);
      expect(state.status, SessionStatus.signedOut);
      expect(state.tenant, 'acme');
    });

    test('with stored tokens the user is signed in', () async {
      final container = await _container(
        tokens: Tokens(accessToken: 'a', refreshToken: 'r', accessExpiresAt: DateTime.now()),
      );
      expect(container.read(sessionProvider).status, SessionStatus.signedIn);
    });

    test('expire signs out with a notice and keeps the tenant; it does nothing when signed out', () async {
      final container = await _container(
        tokens: Tokens(accessToken: 'a', refreshToken: 'r', accessExpiresAt: DateTime.now()),
        prefs: <String, Object>{'tenant_code': 'acme'},
      );
      final session = container.read(sessionProvider.notifier);
      session.expire();
      var state = container.read(sessionProvider);
      expect(state.status, SessionStatus.signedOut);
      expect(state.notice, SessionNotice.expired);
      expect(state.tenant, 'acme');

      session.clearNotice();
      session.expire();
      state = container.read(sessionProvider);
      expect(state.notice, SessionNotice.none);
    });

    test('signedIn remembers the tenant', () async {
      final container = await _container();
      await container.read(sessionProvider.notifier).signedIn('globex');
      expect(container.read(sessionProvider).status, SessionStatus.signedIn);
      expect(container.read(sharedPreferencesProvider).getString('tenant_code'), 'globex');
    });
  });

  group('redirect', () {
    test('while loading everything goes to the splash screen', () {
      expect(redirectFor(SessionStatus.loading, '/users'), '/splash');
      expect(redirectFor(SessionStatus.loading, '/splash'), isNull);
    });

    test('signed out users can only see the public screens', () {
      expect(redirectFor(SessionStatus.signedOut, '/users'), '/login');
      expect(redirectFor(SessionStatus.signedOut, '/splash'), '/login');
      expect(redirectFor(SessionStatus.signedOut, '/login'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/forgot-password'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/reset-password?token=abc'), isNull);
    });

    test('signed in users are taken off the public screens', () {
      expect(redirectFor(SessionStatus.signedIn, '/login'), '/users');
      expect(redirectFor(SessionStatus.signedIn, '/splash'), '/users');
      expect(redirectFor(SessionStatus.signedIn, '/reset-password?token=abc'), '/users');
      expect(redirectFor(SessionStatus.signedIn, '/groups'), isNull);
      expect(redirectFor(SessionStatus.signedIn, '/users/edit/1'), isNull);
    });
  });
}
