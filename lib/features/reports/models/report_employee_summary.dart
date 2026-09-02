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

/// One entry of an [EmployeeSummaryRow.payments] breakdown — a payment
/// method's share of that group's total.
class EmployeeSummaryPayment {
  final String paymName;
  final String paymTotal;

  const EmployeeSummaryPayment({required this.paymName, required this.paymTotal});

  factory EmployeeSummaryPayment.fromJson(Map<String, dynamic> json) {
    return EmployeeSummaryPayment(
      paymName: (json['paym_name'] ?? '') as String,
      paymTotal: (json['paym_total'] ?? '0').toString(),
    );
  }
}

/// One group of `orders/employee-summary` (`groupEmployeeSummary`, grouped
/// server-side by `prem_name` + `empl_name` + `dateserver_created`) — like
/// the propinas report it replaces, this endpoint IS the report: there's no
/// separate KPI/chart-shaped endpoint, and the response is never paginated
/// (no `all_records`/`page`, no `pagination` block — it always returns the
/// full matching row set). Distinct payment methods within a group no longer
/// arrive as duplicate rows (as the old per-`orde_state`/`paym_name` shape
/// did) — they're collected into [payments].
class EmployeeSummaryRow {
  final String premName;
  final String emplName;
  final String dateserverCreated;
  final String ordeTotal;
  final String tipsTotal;
  final int totalCompletados;
  final int totalCancelados;
  final List<EmployeeSummaryPayment> payments;

  const EmployeeSummaryRow({
    required this.premName,
    required this.emplName,
    required this.dateserverCreated,
    required this.ordeTotal,
    required this.tipsTotal,
    required this.totalCompletados,
    required this.totalCancelados,
    required this.payments,
  });

  factory EmployeeSummaryRow.fromJson(Map<String, dynamic> json) {
    return EmployeeSummaryRow(
      premName: (json['prem_name'] ?? '') as String,
      emplName: (json['empl_name'] ?? '') as String,
      dateserverCreated: (json['dateserver_created'] ?? '') as String,
      ordeTotal: (json['orde_total'] ?? '0').toString(),
      tipsTotal: (json['tips_total'] ?? '0').toString(),
      totalCompletados:
          int.tryParse(json['total_completados']?.toString() ?? '') ?? 0,
      totalCancelados:
          int.tryParse(json['total_cancelados']?.toString() ?? '') ?? 0,
      payments: json['payments'] is List
          ? (json['payments'] as List)
              .map((e) =>
                  EmployeeSummaryPayment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}
