import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_gin_tenant_mobile/app/providers.dart';
import 'package:go_gin_tenant_mobile/core/api/api_exception.dart';
import 'package:go_gin_tenant_mobile/core/api/parsing.dart';
import 'package:go_gin_tenant_mobile/features/users/user.dart';
import 'package:go_gin_tenant_mobile/features/users/users_controller.dart';

import '../support/fakes.dart';

ProviderContainer _container(FakeUsersRepository repo) {
  final container = ProviderContainer(
    overrides: <Override>[
      usersRepositoryProvider.overrideWithValue(repo),
      signedInProvider.overrideWithValue(true),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('loads the first page when it is read', () async {
    final repo = FakeUsersRepository()
      ..onList = (UsersFilters f, int page) async => fakePage(<User>[fakeUser('1'), fakeUser('2')], page: 1, pages: 1);
    final container = _container(repo);
    container.listen(usersControllerProvider, (UsersState? a, UsersState b) {});

    expect(container.read(usersControllerProvider).loading, isTrue);
    await pumpEventQueue();
    final state = container.read(usersControllerProvider);
    expect(state.loading, isFalse);
    expect(state.items.map((User u) => u.id), <String>['1', '2']);
    expect(state.hasMore, isFalse);
  });

  test('loadMore appends the next page and skips rows that are already there', () async {
    final repo = FakeUsersRepository()
      ..onList = (UsersFilters f, int page) async {
        if (page == 1) return fakePage(<User>[fakeUser('1'), fakeUser('2')], page: 1, pages: 2, total: 4);
        return fakePage(<User>[fakeUser('2'), fakeUser('3')], page: 2, pages: 2, total: 4);
      };
    final container = _container(repo);
    container.listen(usersControllerProvider, (UsersState? a, UsersState b) {});
    await pumpEventQueue();

    await container.read(usersControllerProvider.notifier).loadMore();
    final state = container.read(usersControllerProvider);
    expect(state.items.map((User u) => u.id), <String>['1', '2', '3']);
    expect(state.hasMore, isFalse);
  });

  test('a slow answer for old filters does not overwrite the newer list', () async {
    final slow = Completer<PagedResult<User>>();
    final repo = FakeUsersRepository()
      ..onList = (UsersFilters f, int page) {
        if (f.username == 'old') return slow.future;
        return Future<PagedResult<User>>.value(fakePage(<User>[fakeUser('new')], page: 1, pages: 1));
      };
    final container = _container(repo);
    container.listen(usersControllerProvider, (UsersState? a, UsersState b) {});
    await pumpEventQueue();

    final controller = container.read(usersControllerProvider.notifier);
    final first = controller.setFilters(const UsersFilters(username: 'old'));
    final second = controller.setFilters(const UsersFilters(username: 'new'));
    await second;
    slow.complete(fakePage(<User>[fakeUser('old')], page: 1, pages: 1));
    await first;

    expect(container.read(usersControllerProvider).items.map((User u) => u.id), <String>['new']);
  });

  test('a failed first page is kept as an error until refresh works', () async {
    var fail = true;
    final repo = FakeUsersRepository()
      ..onList = (UsersFilters f, int page) async {
        if (fail) throw const ApiException.network();
        return fakePage(<User>[fakeUser('1')], page: 1, pages: 1);
      };
    final container = _container(repo);
    container.listen(usersControllerProvider, (UsersState? a, UsersState b) {});
    await pumpEventQueue();
    expect(container.read(usersControllerProvider).error, isA<ApiException>());

    fail = false;
    await container.read(usersControllerProvider.notifier).refresh();
    final state = container.read(usersControllerProvider);
    expect(state.error, isNull);
    expect(state.items, hasLength(1));
  });

  test('setActive changes the row, remove deletes it', () async {
    final repo = FakeUsersRepository()
      ..onList = (UsersFilters f, int page) async => fakePage(<User>[fakeUser('1'), fakeUser('2')], page: 1, pages: 1);
    final container = _container(repo);
    container.listen(usersControllerProvider, (UsersState? a, UsersState b) {});
    await pumpEventQueue();
    final controller = container.read(usersControllerProvider.notifier);

    await controller.setActive(fakeUser('1'), active: false);
    expect(container.read(usersControllerProvider).items.first.isActive, isFalse);
    expect(repo.activated.single.key, '1');

    await controller.remove(fakeUser('2'));
    final state = container.read(usersControllerProvider);
    expect(state.items.map((User u) => u.id), <String>['1']);
    expect(state.total, 1);
    expect(repo.deleted, <String>['2']);
  });
}
