import 'package:ds_clickeat_web_admin/features/reports/models/report_product.dart';

/// Builds a CSV document from `reports/product-export` rows, one row per
/// product (or product+size/option combination).
String productsToCsv(List<ProductCsvRow> rows) {
  const headers = [
    'Sucursal',
    'Producto',
    'Categoría',
    'Tamaño',
    'Opción',
    'Cantidad',
    'Total',
    'Empleado',
  ];

  final csvRows = <List<String>>[headers];

  for (final r in rows) {
    csvRows.add([
      r.premName,
      r.prodName,
      r.prodcName,
      r.prodsName,
      r.prodoName,
      '${r.prodQuantity}',
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
