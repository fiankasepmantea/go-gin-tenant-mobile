/// Who the access token belongs to (GET /auth/me, which answers without an envelope).
class Me {
  const Me({required this.userId, required this.level, this.tenantId});

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      userId: json['user_id'] as String,
      level: (json['level'] as String?) ?? 'tenant',
      tenantId: json['tenant_id'] as String?,
    );
  }

  final String userId;
  final String level;
  final String? tenantId;
}
