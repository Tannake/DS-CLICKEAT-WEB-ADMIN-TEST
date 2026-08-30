import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart';

/// Builds a CSV document from `reports/sales-export` rows, one row per order.
String salesToCsv(List<SalesCsvRow> rows) {
  const headers = [
    'Sucursal',
    'Pedido',
    'Cliente',
    'Mesa',
    'Total',
    'Estado',
    'Tipo',
    'Método de pago',
    'Propina %',
    'Motivo de cancelación',
    'Empleado',
    'Fecha',
  ];

  final csvRows = <List<String>>[headers];

  for (final r in rows) {
    csvRows.add([
      r.premName,
      '${r.ordeId}',
      '${r.custId}',
      r.tablId,
      r.ordeTotal,
      r.ordeState,
      r.ordeType,
      r.paymName,
      '${r.tipsPercentage}',
      r.reasName,
      r.emplName,
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
