/// One entry of `reports/parameter/employee/:user_id` — a selectable
/// employee for the "Empleado" multi-select filter on the propinas report.
class EmployeeOption {
  final int emplId;
  final String emplName;

  const EmployeeOption({required this.emplId, required this.emplName});

  factory EmployeeOption.fromJson(Map<String, dynamic> json) {
    return EmployeeOption(
      emplId: (json['empl_id'] as num?)?.toInt() ?? 0,
      emplName: (json['empl_name'] ?? '') as String,
    );
  }
}

/// One row of `reports/tips-export` (`fun_reports_export_tips`) — unlike
/// every other report, this endpoint IS the propinas report: there's no
/// separate KPI/chart-shaped `reports/tips` endpoint, and the response is
/// never paginated (no `all_records`/`page`, no `pagination` block — it
/// always returns the full matching row set). `tablId` and `ordeType` arrive
/// already formatted by the SQL function ("Mesa 4", "Móvil"/"POS"/etc.).
class TipsCsvRow {
  final String premName;
  final String emplName;
  final int ordeId;
  final String tablId;
  final String ordeTotal;
  final num tipsPercentage;
  final String ordeTotalTips;
  final String totalTips;
  final String ordeType;
  final String dateserverCreated;

  const TipsCsvRow({
    required this.premName,
    required this.emplName,
    required this.ordeId,
    required this.tablId,
    required this.ordeTotal,
    required this.tipsPercentage,
    required this.ordeTotalTips,
    required this.totalTips,
    required this.ordeType,
    required this.dateserverCreated,
  });

  factory TipsCsvRow.fromJson(Map<String, dynamic> json) {
    return TipsCsvRow(
      premName: (json['prem_name'] ?? '') as String,
      emplName: (json['empl_name'] ?? '') as String,
      ordeId: (json['orde_id'] as num?)?.toInt() ?? 0,
      tablId: (json['tabl_id'] ?? '').toString(),
      ordeTotal: (json['orde_total'] ?? '0').toString(),
      tipsPercentage: (json['tips_percentage'] as num?) ?? 0,
      ordeTotalTips: (json['orde_total_tips'] ?? '0').toString(),
      totalTips: (json['total_tips'] ?? '0').toString(),
      ordeType: (json['orde_type'] ?? '') as String,
      dateserverCreated: (json['dateserver_created'] ?? '') as String,
    );
  }
}
