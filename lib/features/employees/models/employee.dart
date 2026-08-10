/// A staff member for a premise, from `premises/employee/<premId>`
/// (`fun_get_admin_employee`). `roleName` is denormalized from the joined
/// `ROLE` row so the table doesn't need a separate roles lookup to render.
class Employee {
  final int emplId;
  final String emplName;
  final String emplEmail;
  final bool emplAvailable;
  final int roleId;
  final String roleName;

  const Employee({
    required this.emplId,
    required this.emplName,
    required this.emplEmail,
    required this.emplAvailable,
    required this.roleId,
    required this.roleName,
  });

  Employee copyWith({
    String? emplName,
    String? emplEmail,
    bool? emplAvailable,
    int? roleId,
    String? roleName,
  }) => Employee(
        emplId: emplId,
        emplName: emplName ?? this.emplName,
        emplEmail: emplEmail ?? this.emplEmail,
        emplAvailable: emplAvailable ?? this.emplAvailable,
        roleId: roleId ?? this.roleId,
        roleName: roleName ?? this.roleName,
      );

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      emplId: (json['empl_id'] as num?)?.toInt() ?? 0,
      emplName: (json['empl_name'] ?? '').toString(),
      emplEmail: (json['empl_email'] ?? '').toString(),
      emplAvailable: _parseBool(json['empl_available'], defaultValue: true),
      roleId: (json['role_id'] as num?)?.toInt() ?? 0,
      roleName: (json['role_name'] ?? '').toString(),
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
