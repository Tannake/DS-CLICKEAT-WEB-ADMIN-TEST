import 'package:ds_clickeat_web_admin/features/reports/models/report_orders.dart';

/// Builds a CSV document from `reports/orders-export` rows, one row per
/// product (or product+add-on) line item.
String ordersToCsv(List<OrdersCsvRow> rows) {
  const headers = [
    'Sucursal',
    'Pedido',
    'Mesa',
    'Estado',
    'Tipo',
    'Fecha',
    'Producto',
    'Cantidad',
    'Precio unitario',
    'Total producto',
    'Tamaño',
    'Opción',
    'Adicional',
    'Cantidad adicional',
    'Precio adicional',
    'Total adicional',
    'Empleado',
  ];

  final csvRows = <List<String>>[headers];

  for (final r in rows) {
    csvRows.add([
      r.premName,
      '${r.ordeId}',
      r.tablId,
      r.ordeState,
      r.ordeType,
      r.dateserverCreated,
      r.prodName,
      '${r.prodQuantity}',
      r.prodPriceUnitary,
      r.prodPriceTotal,
      r.prodsName,
      r.prodoName,
      r.prodaName,
      '${r.prodaQuantity}',
      r.prodaPrice,
      r.prodaTotal,
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
