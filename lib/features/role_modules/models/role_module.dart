/// A screen/feature that can be granted to a role, from
/// `premises/system-module` — a global catalog, not premise-scoped (the
/// endpoint takes no `<premId>`).
class SystemModule {
  final int sysmId;
  final String sysmName;
  final bool sysmAvailable;
  final String sysmType;
  final String? sysmCategory;

  const SystemModule({
    required this.sysmId,
    required this.sysmName,
    required this.sysmAvailable,
    required this.sysmType,
    this.sysmCategory,
  });

  factory SystemModule.fromJson(Map<String, dynamic> json) {
    return SystemModule(
      sysmId: (json['sysm_id'] as num?)?.toInt() ?? 0,
      sysmName: (json['sysm_name'] ?? '').toString(),
      sysmAvailable: _parseBool(json['sysm_available'], defaultValue: true),
      sysmType: (json['sysm_type'] ?? '').toString(),
      sysmCategory: json['sysm_category']?.toString(),
    );
  }
}

/// One row of `premises/role-module/<premId>` — a single role<->module
/// assignment (the SP returns one flat, `DISTINCT` row per combination).
/// `role_name`/`sysm_name` come back denormalized but aren't kept here: the
/// UI joins against the already-loaded [Role]/[SystemModule] lists by id.
class RoleModuleAssignment {
  final int roleId;
  final int sysmId;

  const RoleModuleAssignment({required this.roleId, required this.sysmId});

  factory RoleModuleAssignment.fromJson(Map<String, dynamic> json) {
    return RoleModuleAssignment(
      roleId: (json['role_id'] as num?)?.toInt() ?? 0,
      sysmId: (json['sysm_id'] as num?)?.toInt() ?? 0,
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
