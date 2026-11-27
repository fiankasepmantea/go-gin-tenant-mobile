import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_gin_tenant_mobile/app/providers.dart';
import 'package:go_gin_tenant_mobile/core/i18n/app_strings.dart';
import 'package:go_gin_tenant_mobile/features/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/memory_token_store.dart';

Future<FakeAuthRepository> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(preferences),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('empty fields are refused before any request', (WidgetTester tester) async {
    final auth = await _pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('required'), findsNWidgets(3));
    expect(auth.logins, isEmpty);
  });

  testWidgets('a tenant code with spaces inside is refused', (WidgetTester tester) async {
    final auth = await _pump(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Tenant code'), 'my tenant');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text(stringsEnInvalidTenant), findsOneWidget);
    expect(auth.logins, isEmpty);
  });

  testWidgets('signs in with the tenant code trimmed and in lowercase', (WidgetTester tester) async {
    final auth = await _pump(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Tenant code'), '  ACME ');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.logins, hasLength(1));
    expect(auth.logins.single['tenant'], 'acme');
    expect(auth.logins.single['username'], 'admin');
  });
}

const String stringsEnInvalidTenant = 'Invalid tenant code. Use lowercase letters, digits and hyphens.';
