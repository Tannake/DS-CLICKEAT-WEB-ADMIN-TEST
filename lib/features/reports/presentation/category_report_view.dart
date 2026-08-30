import 'package:flutter/material.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/category_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_category.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_product.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/orders_report_view.dart'
    show channelColor;

/// Maps the live `reports/product-category` payload (held in
/// [CategoryReportState]) into the [ReportView] shape shared by every report
/// screen — mirrors `product_report_view.dart`'s `buildProductReportView`
/// one level up the rollup (category instead of product): same KPI/chart/
/// table layout, plus a detail table sourced from
/// `reports/product-category-export`. Same span-3/span-1 (75:25) bar+donut
/// layout rule as the other reports: nivel 1 is cantidad vendida
/// (`product_sold` bar + `product_sold_type` donut), nivel 2 is monto
/// vendido (`product_sales` bar + `product_sales_type` donut).
ReportView buildCategoryReportView(CategoryReportState state) {
  final data = state.data ?? CategoryReportData.empty;
  final cards = data.cards;

  final categorySold = [...data.productSold]
    ..sort((a, b) => b.prodQuantity.compareTo(a.prodQuantity));
  final categorySales = [...data.productSales]
    ..sort((a, b) => b.prodTotal.compareTo(a.prodTotal));

  final orderTypeNames = {for (final o in state.orderTypes) o.ordeType: o.ordeName};

  return ReportView(
    title: 'Reporte de categorías',
    subtitle: 'Categorías del periodo seleccionado',
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
        'Categoría',
        ReportFilter.summarize(
          items: state.categories.map((c) => c.prodcId).toList(),
          labelOf: (id) =>
              state.categories.firstWhere((c) => c.prodcId == id).prodcName,
          selected: state.selectedProdcIds,
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
        label: 'Categorías vendidas',
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
        label: 'Categoría más vendida',
        value: cards.productSoldHightestName ?? '—',
        sub: cards.productSoldHightestTotal != null
            ? '${_num(cards.productSoldHightestTotal!)} unidades'
            : '',
        accent: const Color(0xFF2563EB),
        valueFontSize: 16,
      ),
      ReportKpi(
        label: 'Categoría con más ventas',
        value: cards.productSalesHightestName ?? '—',
        sub: cards.productSalesHightestTotal != null
            ? _money(cards.productSalesHightestTotal!)
            : '',
        accent: AppColors.gold,
        valueFontSize: 16,
      ),
      ReportKpi(
        label: 'Categoría menos vendida',
        value: cards.productSoldLowerName ?? '—',
        sub: cards.productSoldLowerTotal != null
            ? '${_num(cards.productSoldLowerTotal!)} unidades'
            : '',
        accent: AppColors.amber,
        subColor: AppColors.amberInk,
        valueFontSize: 16,
      ),
      ReportKpi(
        label: 'Categoría con menos ventas',
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
      // Nivel 1: Cantidad de categorías vendidas (75%) + Ventas por canal/cantidad (25%).
      BarsChart(
        'Cantidad de categorías vendidas',
        3,
        labels: [for (final c in categorySold) c.prodcName],
        values: [for (final c in categorySold) c.prodQuantity.toDouble()],
        valueLabels: [for (final c in categorySold) _num(c.prodQuantity)],
        color: AppColors.gold,
        minBarWidth: categorySold.length > 20 ? 46 : null,
      ),
      _typeQuantityDonut(data.productSoldType, orderTypeNames),
      // Nivel 2: Venta total de categorías (75%) + Ventas por canal/monto (25%).
      BarsChart(
        'Venta total de categorías',
        3,
        labels: [for (final c in categorySales) c.prodcName],
        values: [for (final c in categorySales) c.prodTotal.toDouble()],
        valueLabels: [for (final c in categorySales) _money(c.prodTotal)],
        color: AppColors.greenInk,
        minBarWidth: categorySales.length > 20 ? 46 : null,
      ),
      _typeAmountDonut(data.productSalesType, orderTypeNames),
    ],
    tableTitle: 'Detalle de categorías',
    tableCount: '${state.tableTotalRecords} categorías en el periodo',
    headers: const [
      ReportTableHeader('Categoría'),
      ReportTableHeader('Cantidad', alignRight: true),
      ReportTableHeader('Productos vendidos', alignRight: true),
      ReportTableHeader('Total', alignRight: true),
      ReportTableHeader('Sucursal'),
      ReportTableHeader('Empleado'),
    ],
    rows: [
      for (final c in state.categoryRows)
        ReportTableRow([
          ReportCell.plain(c.prodcName, bold: true),
          ReportCell.plain('${c.prodQuantity}', alignRight: true),
          ReportCell.plain('${c.prodSold}', alignRight: true),
          ReportCell.plain(_moneyStr(c.prodTotal), bold: true, alignRight: true),
          ReportCell.plain(c.premName),
          ReportCell.plain(c.emplName.isEmpty ? '—' : c.emplName),
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

/// Formats a `reports/product-category-export` money field ("903.00") the
/// same way the products report's `_moneyStr` does — the detail table is
/// the only place on this screen with per-line money values as strings.
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
