import 'package:ds_clickeat_web_admin/features/reports/models/report_tips.dart';

/// Builds a CSV document from `reports/tips-export` rows, one row per order.
String tipsToCsv(List<TipsCsvRow> rows) {
  const headers = [
    'Sucursal',
    'Empleado',
    'Pedido',
    'Mesa',
    'Total',
    '% Propina',
    'Total con propina',
    'Tipo',
    'Fecha',
  ];

  final csvRows = <List<String>>[headers];

  for (final r in rows) {
    csvRows.add([
      r.premName,
      r.emplName,
      '${r.ordeId}',
      r.tablId,
      r.ordeTotal,
      '${r.tipsPercentage}',
      r.ordeTotalTips,
      r.ordeType,
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
