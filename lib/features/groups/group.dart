/// A group of the signed-in tenant (GET /groups).
class Group {
  const Group({required this.id, required this.name, required this.description});

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['group_id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
    );
  }

  final String id;
  final String name;
  final String description;
}

/// One grantable endpoint (GET /rbac/endpoints).
class EndpointInfo {
  const EndpointInfo({required this.id, required this.method, required this.path});

  factory EndpointInfo.fromJson(Map<String, dynamic> json) {
    return EndpointInfo(
      id: json['endpoint_id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
    );
  }

  final String id;
  final String method;
  final String path;

  /// `GET /api/v1/users/:id`
  String get label => '$method $path';

  /// `/api/v1/users/:id` belongs to the resource `users`.
  String get resource {
    final rest = path.replaceFirst(RegExp(r'^/api/v\d+/'), '');
    final first = rest.split('/').first;
    return first.isEmpty ? '/' : first;
  }
}
