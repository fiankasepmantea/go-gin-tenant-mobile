/// A user of the signed-in tenant (GET /users).
class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.groupId,
    required this.isActive,
    required this.level,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'] as String,
      username: json['username'] as String,
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      groupId: json['group_id'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      level: (json['level'] as String?) ?? 'tenant',
    );
  }

  final String id;
  final String username;
  final String email;
  final String name;
  final String? groupId;
  final bool isActive;
  final String level;

  /// What to show as the headline of a row.
  String get displayName => name.isEmpty ? username : name;
}

/// The filters of the user list. The API only supports exact filters, so `username` is an exact match.
class UsersFilters {
  const UsersFilters({this.username = '', this.groupId, this.isActive});

  final String username;
  final String? groupId;
  final bool? isActive;

  bool get isEmpty => username.isEmpty && groupId == null && isActive == null;

  Map<String, dynamic> toQuery() {
    return <String, dynamic>{
      if (isActive != null) 'is_active': isActive.toString(),
      if (groupId != null) 'group_id': groupId,
      if (username.isNotEmpty) 'username': username,
    };
  }
}
