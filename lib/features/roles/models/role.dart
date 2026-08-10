/// A staff role for a premise, from `premises/role/<premId>`
/// (`fun_get_admin_role`). Used both as a manageable list (create/edit a
/// role) and as the role picker when creating/editing an [Employee].
class Role {
  final int roleId;
  final String roleName;
  final bool roleAvailable;

  const Role({
    required this.roleId,
    required this.roleName,
    required this.roleAvailable,
  });

  Role copyWith({String? roleName, bool? roleAvailable}) => Role(
        roleId: roleId,
        roleName: roleName ?? this.roleName,
        roleAvailable: roleAvailable ?? this.roleAvailable,
      );

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      roleId: (json['role_id'] as num?)?.toInt() ?? 0,
      roleName: (json['role_name'] ?? '').toString(),
      roleAvailable: _parseBool(json['role_available'], defaultValue: true),
    );
  }
}

bool _parseBool(dynamic raw, {bool defaultValue = false}) {
  if (raw is bool) return raw;
  if (raw is num) return raw.toInt() == 1;
  if (raw is String) {
    final s = raw.toLowerCase().trim();
    return s == 'true' || s == '1';
  }
  return defaultValue;
}
