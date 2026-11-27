import 'package:go_gin_tenant_mobile/core/api/parsing.dart';
import 'package:go_gin_tenant_mobile/features/auth/auth_repository.dart';
import 'package:go_gin_tenant_mobile/features/auth/me.dart';
import 'package:go_gin_tenant_mobile/features/users/user.dart';
import 'package:go_gin_tenant_mobile/features/users/users_repository.dart';

User fakeUser(String id, {bool active = true, String? groupId}) => User(
      id: id,
      username: 'user-$id',
      email: '$id@example.com',
      name: 'User $id',
      groupId: groupId,
      isActive: active,
      level: 'tenant',
    );

PagedResult<User> fakePage(List<User> users, {required int page, required int pages, int? total}) => PagedResult<User>(
      items: users,
      totalData: total ?? users.length,
      currentPage: page,
      totalPages: pages,
    );

/// A users repository whose answers the test decides.
class FakeUsersRepository implements UsersRepository {
  Future<PagedResult<User>> Function(UsersFilters filters, int page)? onList;
  final List<String> deleted = <String>[];
  final List<MapEntry<String, bool>> activated = <MapEntry<String, bool>>[];

  @override
  Future<PagedResult<User>> list(UsersFilters filters, {int page = 1, int size = UsersRepository.perPage}) {
    return onList!(filters, page);
  }

  @override
  Future<void> setActive(String id, {required bool active}) async => activated.add(MapEntry<String, bool>(id, active));

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// An auth repository that records the login and does nothing else.
class FakeAuthRepository implements AuthRepository {
  final List<Map<String, String>> logins = <Map<String, String>>[];

  @override
  Future<void> login({required String tenantCode, required String username, required String password}) async {
    logins.add(<String, String>{'tenant': tenantCode, 'username': username, 'password': password});
  }

  @override
  Future<Me> me() async => const Me(userId: 'me', level: 'tenant');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
