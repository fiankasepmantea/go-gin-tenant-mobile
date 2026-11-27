import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/app_strings.dart';
import '../features/account/account_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/groups/group_form_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/groups/permissions_screen.dart';
import '../features/users/user_form_screen.dart';
import '../features/users/users_screen.dart';
import 'providers.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const Set<String> _publicPaths = <String>{'/login', '/forgot-password', '/reset-password'};

/// Where a user should be, given the session. Null means "stay". Kept out of the router so it can be tested.
String? redirectFor(SessionStatus status, String location) {
  final path = Uri.parse(location).path;
  switch (status) {
    case SessionStatus.loading:
      return path == '/splash' ? null : '/splash';
    case SessionStatus.signedOut:
      return _publicPaths.contains(path) ? null : '/login';
    case SessionStatus.signedIn:
      if (path == '/splash' || _publicPaths.contains(path) || path == '/') return '/users';
      return null;
  }
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  // go_router re-runs `redirect` when this notifies.
  final refresh = ValueNotifier<SessionStatus>(ref.read(sessionProvider).status);
  ref.listen<SessionState>(sessionProvider, (SessionState? previous, SessionState next) {
    refresh.value = next.status;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      return redirectFor(ref.read(sessionProvider).status, state.uri.toString());
    },
    routes: <RouteBase>[
      GoRoute(path: '/splash', builder: (BuildContext context, GoRouterState state) => const _Splash()),
      GoRoute(path: '/login', builder: (BuildContext context, GoRouterState state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, GoRouterState state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (BuildContext context, GoRouterState state) =>
            ResetPasswordScreen(initialToken: state.uri.queryParameters['token']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
            HomeShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/users',
                builder: (BuildContext context, GoRouterState state) => const UsersScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) => const UserFormScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        UserFormScreen(userId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/groups',
                builder: (BuildContext context, GoRouterState state) => const GroupsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) => const GroupFormScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        GroupFormScreen(groupId: state.pathParameters['id']),
                  ),
                  GoRoute(
                    path: ':id/permissions',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        PermissionsScreen(groupId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/account', builder: (BuildContext context, GoRouterState state) => const AccountScreen()),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// The bottom navigation around the three main areas.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: <NavigationDestination>[
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: s.t('nav.users')),
          NavigationDestination(icon: const Icon(Icons.group_outlined), selectedIcon: const Icon(Icons.group), label: s.t('nav.groups')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: s.t('nav.account')),
        ],
      ),
    );
  }
}
