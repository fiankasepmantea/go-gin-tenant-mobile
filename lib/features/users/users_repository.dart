import '../../core/api/api_client.dart';
import '../../core/api/parsing.dart';
import 'user.dart';

/// docs/users-api.md in the backend.
class UsersRepository {
  UsersRepository(this._api);

  final ApiClient _api;

  static const int perPage = 20;

  Future<PagedResult<User>> list(UsersFilters filters, {int page = 1, int size = perPage}) async {
    final body = await _api.get(
      '/users',
      query: <String, dynamic>{
        'page': page,
        'per_page': size,
        'sort': '-created_at',
        ...filters.toQuery(),
      },
    );
    return PagedResult<User>.fromEnvelope(body, User.fromJson);
  }

  Future<User> get(String id) async {
    final body = await _api.get('/users/$id');
    return parseBody<User>(() => User.fromJson(asMap(envelopeData(body))));
  }

  Future<void> create({
    required String name,
    required String username,
    required String email,
    required String password,
    required bool isActive,
    String? groupId,
  }) async {
    await _api.post(
      '/users',
      data: <String, dynamic>{
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'is_active': isActive,
        if (groupId != null) 'group_id': groupId,
      },
    );
  }

  /// PATCH /users/:id changes only what is sent. `group_id: ""` removes the user from the group.
  Future<void> update(
    String id, {
    required String name,
    required String email,
    required String? groupId,
    bool? isActive,
  }) async {
    await _api.patch(
      '/users/$id',
      data: <String, dynamic>{
        'name': name,
        'email': email,
        'group_id': groupId ?? '',
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  Future<void> setActive(String id, {required bool active}) async {
    await _api.patch('/users/$id', data: <String, dynamic>{'is_active': active});
  }

  Future<void> delete(String id) async {
    await _api.delete('/users/$id');
  }
}
