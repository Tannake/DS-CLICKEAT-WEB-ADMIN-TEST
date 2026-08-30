import 'package:ds_clickeat_web_admin/features/reports/models/report_category.dart';

/// Builds a CSV document from `reports/product-category-export` rows, one
/// row per category.
String categoriesToCsv(List<CategoryCsvRow> rows) {
  const headers = [
    'Sucursal',
    'Categoría',
    'Cantidad',
    'Productos vendidos',
    'Total',
    'Empleado',
  ];

  final csvRows = <List<String>>[headers];

  for (final r in rows) {
    csvRows.add([
      r.premName,
      r.prodcName,
      '${r.prodQuantity}',
      '${r.prodSold}',
      r.prodTotal,
      r.emplName,
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
