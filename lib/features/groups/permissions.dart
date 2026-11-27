import 'group.dart';

/// What the Groups and Permissions screens call themselves. A group that loses these can no longer be managed
/// from the app, so an admin may not remove them from the group of their own account (it would lock them out).
/// Same list as the web console.
const List<String> essentialEndpoints = <String>[
  'GET /api/v1/groups',
  'GET /api/v1/groups/:id/permissions',
  'PUT /api/v1/groups/:id/permissions',
  'GET /api/v1/rbac/endpoints',
];

/// The essential endpoints that exist in [endpoints] but are not in [selected]. Empty means the change is safe.
List<String> lockoutRisk(List<EndpointInfo> endpoints, Set<String> selected) {
  final missing = <String>[];
  for (final label in essentialEndpoints) {
    for (final endpoint in endpoints) {
      if (endpoint.label == label && !selected.contains(endpoint.id)) {
        missing.add(label);
        break;
      }
    }
  }
  return missing;
}

/// Endpoints grouped by resource, resources and items sorted.
List<MapEntry<String, List<EndpointInfo>>> groupByResource(List<EndpointInfo> endpoints) {
  final byResource = <String, List<EndpointInfo>>{};
  for (final endpoint in endpoints) {
    byResource.putIfAbsent(endpoint.resource, () => <EndpointInfo>[]).add(endpoint);
  }
  final entries = byResource.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in entries) {
    entry.value.sort((a, b) {
      final byPath = a.path.compareTo(b.path);
      return byPath != 0 ? byPath : a.method.compareTo(b.method);
    });
  }
  return entries;
}
