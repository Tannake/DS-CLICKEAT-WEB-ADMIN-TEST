import 'package:ds_clickeat_web_admin/features/reports/models/report_employee_summary.dart';

/// Builds a CSV document from `orders/employee-summary` groups. Each group
/// carries a variable-length [EmployeeSummaryRow.payments] breakdown, so
/// unlike the other CSV exports it's rendered as a single "Métodos de pago"
/// column (e.g. "Efectivo 100.00, Tarjeta 50.00") rather than one column per
/// payment method.
String employeeSummaryToCsv(List<EmployeeSummaryRow> rows) {
  const headers = [
    'Sucursal',
    'Empleado',
    'Completados',
    'Cancelados',
    'Métodos de pago',
    'Total',
    'Propinas',
    'Fecha',
  ];

  final csvRows = <List<String>>[headers];

  for (final r in rows) {
    csvRows.add([
      r.premName,
      r.emplName,
      '${r.totalCompletados}',
      '${r.totalCancelados}',
      r.payments.map((p) => '${p.paymName} ${p.paymTotal}').join(', '),
      r.ordeTotal,
      r.tipsTotal,
      r.dateserverCreated,
    ]);
  }

  return csvRows.map((r) => r.map(_escape).join(',')).join('\r\n');
}

/// Quotes a CSV field when it contains a comma, quote or newline, escaping
/// embedded quotes by doubling them.
String _escape(String value) {
  if (value.contains(RegExp(r'[",\r\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
