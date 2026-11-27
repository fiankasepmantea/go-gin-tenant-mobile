import 'package:flutter_test/flutter_test.dart';
import 'package:go_gin_tenant_mobile/features/groups/group.dart';
import 'package:go_gin_tenant_mobile/features/groups/permissions.dart';

EndpointInfo _ep(String id, String method, String path) => EndpointInfo(id: id, method: method, path: path);

void main() {
  final endpoints = <EndpointInfo>[
    _ep('1', 'GET', '/api/v1/groups'),
    _ep('2', 'GET', '/api/v1/groups/:id/permissions'),
    _ep('3', 'PUT', '/api/v1/groups/:id/permissions'),
    _ep('4', 'GET', '/api/v1/rbac/endpoints'),
    _ep('5', 'GET', '/api/v1/users'),
  ];

  test('keeping every essential endpoint is safe', () {
    expect(lockoutRisk(endpoints, <String>{'1', '2', '3', '4'}), isEmpty);
  });

  test('lists the essential endpoints that would be removed', () {
    expect(lockoutRisk(endpoints, <String>{'1', '5'}), <String>[
      'GET /api/v1/groups/:id/permissions',
      'PUT /api/v1/groups/:id/permissions',
      'GET /api/v1/rbac/endpoints',
    ]);
  });

  test('an essential endpoint that does not exist is not demanded', () {
    expect(lockoutRisk(<EndpointInfo>[_ep('5', 'GET', '/api/v1/users')], <String>{}), isEmpty);
  });

  test('groups by resource and sorts', () {
    final sections = groupByResource(endpoints);
    expect(sections.map((MapEntry<String, List<EndpointInfo>> e) => e.key), <String>['groups', 'rbac', 'users']);
    expect(sections.first.value.first.path, '/api/v1/groups');
  });

  test('resource of an endpoint', () {
    expect(_ep('x', 'GET', '/api/v1/users/:id').resource, 'users');
  });
}
