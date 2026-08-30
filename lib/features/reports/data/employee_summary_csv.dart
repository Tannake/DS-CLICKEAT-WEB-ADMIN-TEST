import 'package:ds_clickeat_web_admin/features/reports/models/report_employee_summary.dart';

/// Builds a CSV document from `orders/employee-summary` rows.
String employeeSummaryToCsv(List<EmployeeSummaryRow> rows) {
  const headers = [
    'Sucursal',
    'Empleado',
    'Estado del pedido',
    'Método de pago',
    'Pedidos',
    'Total',
    'Propinas',
    'Fecha',
  ];

  final csvRows = <List<String>>[headers];

  for (final r in rows) {
    csvRows.add([
      r.premName,
      r.emplName,
      r.ordeState,
      r.paymName,
      '${r.totalPedidos}',
      r.ordeTotal,
      r.totalTips,
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
