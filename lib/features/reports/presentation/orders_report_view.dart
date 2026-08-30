import 'package:flutter/material.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/orders_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_orders.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/sales_report_view.dart'
    show stateBadge;

/// Maps the live `reports/orders` payload (held in [OrdersReportState]) into
/// the same [ReportView] shape the sales report uses — same chart order,
/// spans and colors (día/canal 75:25, acumulados/método 75:25), just
/// counting orders instead of summing money. The detail table is one row
/// per product/add-on line item (from `reports/orders-export`), not one row
/// per order — a given `orde_id` can span several rows.
ReportView buildOrdersReportView(OrdersReportState state) {
  final data = state.data ?? OrdersReportData.empty;
  final cards = data.cards;

  final ordersDay = [...data.ordersDay]
    ..sort((a, b) => a.dateserverCreated.compareTo(b.dateserverCreated));
  final ordersAccumulated = [...data.ordersAccumulated]
    ..sort((a, b) => a.dateserverCreated.compareTo(b.dateserverCreated));

  final orderTypeNames = {for (final o in state.orderTypes) o.ordeType: o.ordeName};
  final ordersByChannel = [...data.ordersType]
    ..sort((a, b) => b.ordeTotal.compareTo(a.ordeTotal));
  final ordersByPayment = [...data.ordersPayments]
    ..sort((a, b) => b.ordeTotal.compareTo(a.ordeTotal));

  String pctOfTotal(int count) => cards.ordersTotal > 0
      ? '${_pct(count / cards.ordersTotal * 100)} del total'
      : '';

  return ReportView(
    title: 'Reporte de pedidos',
    subtitle: 'Pedidos del periodo seleccionado',
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
        'Método de pago',
        ReportFilter.summarize(
          items: state.payments.map((p) => p.paymId).toList(),
          labelOf: (id) =>
              state.payments.firstWhere((p) => p.paymId == id).paymName,
          selected: state.selectedPaymIds,
        ),
      ),
      ReportFilter(
        'Estado',
        ReportFilter.summarize(
          items: state.orderStates.map((o) => o.ordeState).toList(),
          labelOf: (code) => state.orderStates
              .firstWhere((o) => o.ordeState == code)
              .stateName,
          selected: state.selectedOrderStates,
        ),
      ),
      ReportFilter(
        'Razón de cancelación',
        ReportFilter.summarize(
          items: state.reasons.map((r) => r.reasId).toList(),
          labelOf: (id) =>
              state.reasons.firstWhere((r) => r.reasId == id).reasName,
          selected: state.selectedReasIds,
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
      if (state.orderIdText.trim().isNotEmpty)
        ReportFilter('N° de pedido', state.orderIdText.trim()),
    ],
    kpis: [
      ReportKpi(
        label: 'Pedidos totales',
        value: _num(cards.ordersTotal),
        accent: AppColors.navy,
      ),
      ReportKpi(
        label: 'Pedidos pagados',
        value: _num(cards.ordersPaid),
        sub: pctOfTotal(cards.ordersPaid),
        accent: AppColors.green,
        subColor: AppColors.greenInk,
      ),
      ReportKpi(
        label: 'Pedidos pendientes',
        value: _num(cards.ordersPending),
        sub: pctOfTotal(cards.ordersPending),
        accent: AppColors.amber,
        subColor: AppColors.amberInk,
      ),
      ReportKpi(
        label: 'Pedidos rechazados',
        value: _num(cards.ordersDeclined),
        sub: pctOfTotal(cards.ordersDeclined),
        accent: const Color(0xFFF97316),
        subColor: const Color(0xFFC2410C),
      ),
      ReportKpi(
        label: 'Pedidos cancelados',
        value: _num(cards.ordersCancelled),
        sub: pctOfTotal(cards.ordersCancelled),
        accent: AppColors.red,
        subColor: AppColors.redInk,
      ),
      ReportKpi(
        label: 'Pedidos promedio',
        value: _num(cards.ordersAverage),
        accent: const Color(0xFF2563EB),
      ),
    ],
    charts: [
      // Nivel 1: Pedidos por día (75%) + Pedidos por canal (25%) — spans
      // 3:1, same proportions as the sales report.
      BarsChart(
        'Pedidos por día',
        3,
        labels: [for (final d in ordersDay) _shortDate(d.dateserverCreated)],
        values: [for (final d in ordersDay) d.ordeTotal.toDouble()],
        valueLabels: [for (final d in ordersDay) _num(d.ordeTotal)],
        color: AppColors.gold,
        minBarWidth: ordersDay.length > 20 ? 46 : null,
      ),
      _channelDonut(ordersByChannel, orderTypeNames),
      // Nivel 2: Pedidos acumulados (75%) + Pedidos por método de pago (25%).
      LineChart(
        'Pedidos acumulados',
        3,
        xLabels: [for (final d in ordersAccumulated) _shortDate(d.dateserverCreated)],
        values: [for (final d in ordersAccumulated) d.ordeTotalAccumulated.toDouble()],
        valueLabels: [for (final d in ordersAccumulated) _num(d.ordeTotalAccumulated)],
        color: AppColors.greenInk,
        minPointWidth: ordersAccumulated.length > 20 ? 50 : null,
      ),
      _paymentDonut(ordersByPayment),
    ],
    tableTitle: 'Detalle de pedidos',
    tableCount: '${state.tableTotalRecords} productos en el periodo',
    headers: const [
      ReportTableHeader('Pedido'),
      ReportTableHeader('Mesa'),
      ReportTableHeader('Producto'),
      ReportTableHeader('Cantidad', alignRight: true),
      ReportTableHeader('Precio unitario', alignRight: true),
      ReportTableHeader('Total', alignRight: true),
      ReportTableHeader('Tamaño'),
      ReportTableHeader('Opción'),
      ReportTableHeader('Adicional'),
      ReportTableHeader('Cant. adicional', alignRight: true),
      ReportTableHeader('Precio adicional', alignRight: true),
      ReportTableHeader('Total adicional', alignRight: true),
      ReportTableHeader('Estado'),
      ReportTableHeader('Tipo'),
      ReportTableHeader('Sucursal'),
      ReportTableHeader('Empleado'),
      ReportTableHeader('Fecha', alignRight: true),
    ],
    rows: [
      for (final o in state.orderRows)
        ReportTableRow([
          ReportCell.plain('#${o.ordeId}', bold: true),
          ReportCell.plain(o.tablId),
          ReportCell.plain(o.prodName),
          ReportCell.plain('${o.prodQuantity}', alignRight: true),
          ReportCell.plain(_money(o.prodPriceUnitary), alignRight: true),
          ReportCell.plain(_money(o.prodPriceTotal), bold: true, alignRight: true),
          ReportCell.plain(o.prodsName.isEmpty ? '—' : o.prodsName),
          ReportCell.plain(o.prodoName.isEmpty ? '—' : o.prodoName),
          ReportCell.plain(o.prodaName.isEmpty ? '—' : o.prodaName),
          ReportCell.plain(o.prodaName.isEmpty ? '—' : '${o.prodaQuantity}', alignRight: true),
          ReportCell.plain(o.prodaName.isEmpty ? '—' : _money(o.prodaPrice), alignRight: true),
          ReportCell.plain(o.prodaName.isEmpty ? '—' : _money(o.prodaTotal), alignRight: true),
          stateBadge(o.ordeState),
          ReportCell.dot(o.ordeType, color: channelColor(o.ordeType)),
          ReportCell.plain(o.premName),
          ReportCell.plain(o.emplName.isEmpty ? '—' : o.emplName),
          ReportCell.plain(_shortDate(o.dateserverCreated), alignRight: true),
        ]),
    ],
  );
}

// ===== donut builders ========================================================

DonutChart _channelDonut(
  List<SalesTypeAmount> ordersByChannel,
  Map<String, String> orderTypeNames,
) {
  final total = ordersByChannel.fold<num>(0, (s, x) => s + x.ordeTotal);
  return DonutChart(
    'Pedidos por canal',
    1,
    size: 150,
    segments: [
      for (final s in ordersByChannel)
        DonutSegment(
          orderTypeNames[s.ordeType] ?? s.ordeType,
          s.ordeTotal.toDouble(),
          channelColor(orderTypeNames[s.ordeType] ?? s.ordeType),
          _num(s.ordeTotal),
          valText2: total > 0 ? _pct(s.ordeTotal / total * 100) : null,
        ),
    ],
    center: _num(total),
    centerSub: 'pedidos',
  );
}

DonutChart _paymentDonut(List<SalesPaymentAmount> ordersByPayment) {
  final total = ordersByPayment.fold<num>(0, (s, e) => s + e.ordeTotal);
  return DonutChart(
    'Pedidos por método de pago',
    1,
    size: 150,
    segments: [
      for (final e in ordersByPayment)
        DonutSegment(
          e.paymName.isEmpty ? 'Sin especificar' : e.paymName,
          e.ordeTotal.toDouble(),
          e.paymName.isEmpty ? const Color(0xFF9CA3AF) : paymentColor(e.paymName),
          _num(e.ordeTotal),
          valText2: total > 0 ? _pct(e.ordeTotal / total * 100) : null,
        ),
    ],
    center: _num(total),
    centerSub: 'pedidos',
  );
}

// ===== formatting helpers ====================================================

/// Whole percent above 10% ("87%"), one decimal below ("0.9%") — matches
/// `sales_report_view.dart`'s `_pct`.
String _pct(double p) => p >= 10 ? '${p.round()}%' : '${p.toStringAsFixed(1)}%';

String _num(num n) => _grouped(n.round());

/// Formats a `reports/orders-export` money field ("139.00") the same way the
/// sales report's `_money` does — the detail table is the only place on
/// this screen with per-line money values, everything else is a count.
String _money(String raw) => '\$${_grouped((num.tryParse(raw) ?? 0).round())}';

String _grouped(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "2026-07-08" -> "8 jul".
String _shortDate(String yyyyMMdd) {
  final d = DateTime.tryParse(yyyyMMdd);
  if (d == null) return yyyyMMdd;
  return '${d.day} ${_months[d.month - 1]}';
}

// ===== shared palettes (order type / payment) — same values as
// sales_report_view.dart, duplicated locally since Dart privacy is
// per-file. ===================================================

const Map<String, Color> _channelColors = {
  'POS': Color(0xFF000000),
  'Móvil': Color(0xFFF5B82E),
  'PickUp': Color(0xFF2563EB),
  'Uber': Color(0xFF22C55E),
  'UberEts': Color(0xFF22C55E),
  'DiDi': Color(0xFFF97316),
  'Didi': Color(0xFFF97316),
  'Rappi': Color(0xFFEF4444),
};

Color channelColor(String label) => _channelColors[label] ?? const Color(0xFF6B7280);

const Map<String, Color> _paymentColors = {
  'Efectivo': Color(0xFF16A34A),
  'Terminal': Color(0xFF2563EB),
  'Mixto': Color(0xFF7C3AED),
};

Color paymentColor(String label) => _paymentColors[label] ?? const Color(0xFF6B7280);
