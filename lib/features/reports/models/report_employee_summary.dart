/// One entry of `reports/parameter/employee/:user_id` — a selectable
/// employee for the "Empleado" multi-select filter on the resumen de turno
/// report.
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

/// One row of `orders/employee-summary` (`FUN_GET_EMPLOYEE_SUMMARY`) —
/// like the propinas report it replaces, this endpoint IS the report:
/// there's no separate KPI/chart-shaped endpoint, and the response is never
/// paginated (no `all_records`/`page`, no `pagination` block — it always
/// returns the full matching row set). Only the non-printer fields of the
/// SQL function's result are modeled here (`prem_address`/`prem_state`/
/// `prem_city`/`prem_image_url` and every `prin_*` printer column are
/// unused by this report).
class EmployeeSummaryRow {
  final String premName;
  final String emplName;
  final String ordeState;
  final String paymName;
  final int totalPedidos;
  final String ordeTotal;
  final String totalTips;
  final String dateserverCreated;

  const EmployeeSummaryRow({
    required this.premName,
    required this.emplName,
    required this.ordeState,
    required this.paymName,
    required this.totalPedidos,
    required this.ordeTotal,
    required this.totalTips,
    required this.dateserverCreated,
  });

  factory EmployeeSummaryRow.fromJson(Map<String, dynamic> json) {
    return EmployeeSummaryRow(
      premName: (json['prem_name'] ?? '') as String,
      emplName: (json['empl_name'] ?? '') as String,
      ordeState: (json['orde_state'] ?? '') as String,
      paymName: (json['paym_name'] ?? '') as String,
      totalPedidos: int.tryParse(json['total_pedidos']?.toString() ?? '') ?? 0,
      ordeTotal: (json['orde_total'] ?? '0').toString(),
      totalTips: (json['total_tips'] ?? '0').toString(),
      dateserverCreated: (json['dateserver_created'] ?? '') as String,
    );
  }
}
