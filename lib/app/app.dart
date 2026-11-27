import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/app_strings.dart';
import '../core/ui/theme.dart';
import '../features/update/update_gate.dart';
import 'providers.dart';
import 'router.dart';

class TenantConsoleApp extends ConsumerWidget {
  const TenantConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.s.t('app.name'),
      routerConfig: router,
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppStrings.delegate,
        // Material, Widgets and Cupertino delegates in one list.
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      builder: (BuildContext context, Widget? child) => UpdateGate(child: child),
    );
  }
}
