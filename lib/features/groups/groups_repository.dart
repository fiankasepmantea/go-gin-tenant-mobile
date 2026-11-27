import '../../core/api/api_client.dart';
import '../../core/api/parsing.dart';
import 'group.dart';

/// Groups and their permissions (docs/rbac.md in the backend).
class GroupsRepository {
  GroupsRepository(this._api);

  final ApiClient _api;

  /// The first 100 groups by name (the API caps a page at 100), enough for any real tenant.
  Future<List<Group>> list() async {
    final body = await _api.get(
      '/groups',
      query: <String, dynamic>{'per_page': 100, 'sort': 'name'},
    );
    return PagedResult<Group>.fromEnvelope(body, Group.fromJson).items;
  }

  Future<void> create({required String name, required String description}) async {
    await _api.post('/groups', data: <String, dynamic>{'name': name, 'description': description});
  }

  Future<void> update(String id, {required String name, required String description}) async {
    await _api.patch('/groups/$id', data: <String, dynamic>{'name': name, 'description': description});
  }

  Future<void> delete(String id) async {
    await _api.delete('/groups/$id');
  }

  /// How many users are in the group. A group that still has users cannot be deleted (409 from the API).
  Future<int> countUsers(String groupId) async {
    final body = await _api.get(
      '/users',
      query: <String, dynamic>{'group_id': groupId, 'per_page': 1},
    );
    return PagedResult<Object>.fromEnvelope(body, (Map<String, dynamic> json) => json).totalData;
  }

  /// GET /rbac/endpoints: everything that can be granted.
  Future<List<EndpointInfo>> endpoints() async {
    final body = await _api.get('/rbac/endpoints');
    return parseBody<List<EndpointInfo>>(
      () => <EndpointInfo>[
        for (final item in asList(envelopeData(body))) EndpointInfo.fromJson(asMap(item)),
      ],
    );
  }

  /// GET /groups/:id/permissions: the ids of the endpoints the group has now.
  Future<Set<String>> permissions(String groupId) async {
    final body = await _api.get('/groups/$groupId/permissions');
    return parseBody<Set<String>>(() {
      final data = asMap(envelopeData(body));
      return <String>{for (final id in asList(data['endpoint_ids'])) id as String};
    });
  }

  /// PUT /groups/:id/permissions replaces the whole set.
  Future<void> savePermissions(String groupId, Set<String> endpointIds) async {
    await _api.put(
      '/groups/$groupId/permissions',
      data: <String, dynamic>{'endpoint_ids': endpointIds.toList()},
    );
  }
}
