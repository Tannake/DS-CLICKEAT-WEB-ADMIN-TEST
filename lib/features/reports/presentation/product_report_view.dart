import 'package:flutter/material.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/product_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_product.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/orders_report_view.dart'
    show channelColor;

/// Maps the live `reports/product` payload (held in [ProductReportState])
/// into the [ReportView] shape shared by every report screen: the KPI cards
/// and four charts, plus a detail table sourced from `reports/product-export`
/// (mirrors `orders_report_view.dart`'s use of `reports/orders-export`).
/// Same span-3/span-1 (75:25) bar+donut layout rule as the sales/orders
/// reports: nivel 1 is cantidad vendida (`product_sold` bar +
/// `product_sold_type` donut), nivel 2 is monto vendido (`product_sales` bar
/// + `product_sales_type` donut).
ReportView buildProductReportView(ProductReportState state) {
  final data = state.data ?? ProductReportData.empty;
  final cards = data.cards;

  final productSold = [...data.productSold]
    ..sort((a, b) => b.prodQuantity.compareTo(a.prodQuantity));
  final productSales = [...data.productSales]
    ..sort((a, b) => b.prodTotal.compareTo(a.prodTotal));

  final orderTypeNames = {for (final o in state.orderTypes) o.ordeType: o.ordeName};

  return ReportView(
    title: 'Reporte de productos',
    subtitle: 'Productos del periodo seleccionado',
    filters: [
      ReportFilter('Fechas', reportDateRangeLabel(state.dateStart, state.dateEnd)),
      ReportFilter(
        'Sucursal',
        ReportFilter.summarize(
          items: state.premises.map((p) => p.premId).toList(),
          labelOf: (id) =>
              state.premises.firstWhere((p) => p.premId == id).premName,
          selected: state.selectedPremIds,
        ),
      ),
      ReportFilter(
        'Tipo de pedido',
        ReportFilter.summarize(
          items: state.orderTypes.map((o) => o.ordeType).toList(),
          labelOf: (code) =>
              state.orderTypes.firstWhere((o) => o.ordeType == code).ordeName,
          selected: state.selectedOrderTypes,
        ),
      ),
      ReportFilter(
        'Producto',
        ReportFilter.summarize(
          items: state.products.map((p) => p.prodId).toList(),
          labelOf: (id) =>
              state.products.firstWhere((p) => p.prodId == id).prodName,
          selected: state.selectedProdIds,
        ),
      ),
      ReportFilter(
        'Categoría',
        ReportFilter.summarize(
          items: state.categories.map((c) => c.prodcId).toList(),
          labelOf: (id) =>
              state.categories.firstWhere((c) => c.prodcId == id).prodcName,
          selected: state.selectedProdcIds,
        ),
      ),
      ReportFilter(
        'Tamaño',
        ReportFilter.summarize(
          items: state.sizes.map((s) => s.prodsId).toList(),
          labelOf: (id) =>
              state.sizes.firstWhere((s) => s.prodsId == id).prodsName,
          selected: state.selectedProdsIds,
        ),
      ),
      ReportFilter(
        'Opción',
        ReportFilter.summarize(
          items: state.options.map((o) => o.prodoId).toList(),
          labelOf: (id) =>
              state.options.firstWhere((o) => o.prodoId == id).prodoName,
          selected: state.selectedProdoIds,
        ),
      ),
      ReportFilter(
        'Empleado',
        ReportFilter.summarize(
          items: state.employees.map((e) => e.emplId).toList(),
          labelOf: (id) =>
              state.employees.firstWhere((e) => e.emplId == id).emplName,
          selected: state.selectedEmplIds,
        ),
      ),
    ],
    kpis: [
      ReportKpi(
        label: 'Productos vendidos',
        value: _num(cards.productSold),
        accent: AppColors.navy,
      ),
      ReportKpi(
        label: 'Ventas totales',
        value: _money(cards.productSales),
        accent: AppColors.green,
        subColor: AppColors.greenInk,
      ),
      ReportKpi(
        label: 'Producto más vendido',
        value: cards.productSoldHightestName ?? '—',
        sub: cards.productSoldHightestTotal != null
            ? '${_num(cards.productSoldHightestTotal!)} unidades'
            : '',
        accent: const Color(0xFF2563EB),
        valueFontSize: 16,
      ),
      ReportKpi(
        label: 'Producto con más ventas',
        value: cards.productSalesHightestName ?? '—',
        sub: cards.productSalesHightestTotal != null
            ? _money(cards.productSalesHightestTotal!)
            : '',
        accent: AppColors.gold,
        valueFontSize: 16,
      ),
      ReportKpi(
        label: 'Producto menos vendido',
        value: cards.productSoldLowerName ?? '—',
        sub: cards.productSoldLowerTotal != null
            ? '${_num(cards.productSoldLowerTotal!)} unidades'
            : '',
        accent: AppColors.amber,
        subColor: AppColors.amberInk,
        valueFontSize: 16,
      ),
      ReportKpi(
        label: 'Producto con menos ventas',
        value: cards.productSalesLowerName ?? '—',
        sub: cards.productSalesLowerTotal != null
            ? _money(cards.productSalesLowerTotal!)
            : '',
        accent: AppColors.red,
        subColor: AppColors.redInk,
        valueFontSize: 16,
      ),
    ],
    charts: [
      // Nivel 1: Cantidad de productos vendidos (75%) + Ventas por canal/cantidad (25%).
      BarsChart(
        'Cantidad de productos vendidos',
        3,
        labels: [for (final p in productSold) p.prodName],
        values: [for (final p in productSold) p.prodQuantity.toDouble()],
        valueLabels: [for (final p in productSold) _num(p.prodQuantity)],
        color: AppColors.gold,
        minBarWidth: productSold.length > 20 ? 46 : null,
      ),
      _typeQuantityDonut(data.productSoldType, orderTypeNames),
      // Nivel 2: Venta total de productos (75%) + Ventas por canal/monto (25%).
      BarsChart(
        'Venta total de productos',
        3,
        labels: [for (final p in productSales) p.prodName],
        values: [for (final p in productSales) p.prodTotal.toDouble()],
        valueLabels: [for (final p in productSales) _money(p.prodTotal)],
        color: AppColors.greenInk,
        minBarWidth: productSales.length > 20 ? 46 : null,
      ),
      _typeAmountDonut(data.productSalesType, orderTypeNames),
    ],
    tableTitle: 'Detalle de productos',
    tableCount: '${state.tableTotalRecords} productos en el periodo',
    headers: const [
      ReportTableHeader('Producto'),
      ReportTableHeader('Categoría'),
      ReportTableHeader('Tamaño'),
      ReportTableHeader('Opción'),
      ReportTableHeader('Cantidad', alignRight: true),
      ReportTableHeader('Total', alignRight: true),
      ReportTableHeader('Sucursal'),
      ReportTableHeader('Empleado'),
    ],
    rows: [
      for (final p in state.productRows)
        ReportTableRow([
          ReportCell.plain(p.prodName, bold: true),
          ReportCell.plain(p.prodcName.isEmpty ? '—' : p.prodcName),
          ReportCell.plain(p.prodsName.isEmpty ? '—' : p.prodsName),
          ReportCell.plain(p.prodoName.isEmpty ? '—' : p.prodoName),
          ReportCell.plain('${p.prodQuantity}', alignRight: true),
          ReportCell.plain(_moneyStr(p.prodTotal), bold: true, alignRight: true),
          ReportCell.plain(p.premName),
          ReportCell.plain(p.emplName.isEmpty ? '—' : p.emplName),
        ]),
    ],
  );
}

// ===== donut builders ========================================================

DonutChart _typeQuantityDonut(
  List<ProductTypeQuantity> productSoldType,
  Map<String, String> orderTypeNames,
) {
  final sorted = [...productSoldType]..sort((a, b) => b.prodQuantity.compareTo(a.prodQuantity));
  final total = sorted.fold<num>(0, (s, x) => s + x.prodQuantity);
  return DonutChart(
    'Cantidad vendida por canal',
    1,
    size: 150,
    segments: [
      for (final s in sorted)
        DonutSegment(
          orderTypeNames[s.ordeType] ?? s.ordeType,
          s.prodQuantity.toDouble(),
          channelColor(orderTypeNames[s.ordeType] ?? s.ordeType),
          _num(s.prodQuantity),
          valText2: total > 0 ? _pct(s.prodQuantity / total * 100) : null,
        ),
    ],
    center: _num(total),
    centerSub: 'unidades',
  );
}

DonutChart _typeAmountDonut(
  List<ProductTypeAmount> productSalesType,
  Map<String, String> orderTypeNames,
) {
  final sorted = [...productSalesType]..sort((a, b) => b.prodTotal.compareTo(a.prodTotal));
  final total = sorted.fold<num>(0, (s, x) => s + x.prodTotal);
  return DonutChart(
    'Ventas por canal',
    1,
    size: 150,
    segments: [
      for (final s in sorted)
        DonutSegment(
          orderTypeNames[s.ordeType] ?? s.ordeType,
          s.prodTotal.toDouble(),
          channelColor(orderTypeNames[s.ordeType] ?? s.ordeType),
          _money(s.prodTotal),
          valText2: total > 0 ? _pct(s.prodTotal / total * 100) : null,
        ),
    ],
    center: _money(total),
    centerSub: 'ventas',
  );
}

// ===== formatting helpers ====================================================

/// Whole percent above 10% ("87%"), one decimal below ("0.9%") — matches
/// `sales_report_view.dart`'s `_pct`.
String _pct(double p) => p >= 10 ? '${p.round()}%' : '${p.toStringAsFixed(1)}%';

String _num(num n) => _grouped(n.round());

String _money(num n) => '\$${_grouped(n.round())}';

/// Formats a `reports/product-export` money field ("149.00") the same way
/// the orders report's `_money(String raw)` does — the detail table is the
/// only place on this screen with per-line money values as strings.
String _moneyStr(String raw) => '\$${_grouped((num.tryParse(raw) ?? 0).round())}';

String _grouped(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}
