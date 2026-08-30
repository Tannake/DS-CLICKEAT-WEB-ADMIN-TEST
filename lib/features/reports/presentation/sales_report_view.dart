import 'package:flutter/material.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/sales_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';

/// Maps the live `reports/sales` payload (held in [SalesReportState]) into
/// the same [ReportView] shape the dashboard/mock report screens use.
/// Mirrors the design's `buildVentas()`, adapted to what the real payload
/// actually carries: there's no previous-period comparison and no per-day
/// order-count series, so "Ticket promedio" has no delta and the design's
/// dual-line "Órdenes vs venta" chart is replaced with a real "Ventas por
/// método de pago" breakdown (from `sales_payments`, a proper SQL-side
/// aggregate — mirrors `sales_type`).
ReportView buildSalesReportView(SalesReportState state) {
  final data = state.data ?? SalesReportData.empty;
  final cards = data.cards;

  final salesDay = [...data.salesDay]
    ..sort((a, b) => a.dateserverCreated.compareTo(b.dateserverCreated));
  final salesAccumulated = [...data.salesAccumulated]
    ..sort((a, b) => a.dateserverCreated.compareTo(b.dateserverCreated));

  final periodDays = state.dateEnd.difference(state.dateStart).inDays + 1;

  final orderTypeNames = {for (final o in state.orderTypes) o.ordeType: o.ordeName};
  final salesByChannel = [...data.salesType]
    ..sort((a, b) => b.ordeTotal.compareTo(a.ordeTotal));
  final salesByPayment = [...data.salesPayments]
    ..sort((a, b) => b.ordeTotal.compareTo(a.ordeTotal));

  return ReportView(
    title: 'Reporte de ventas',
    subtitle: 'Ventas del periodo seleccionado',
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
        label: 'Venta total',
        value: _money(cards.salesTotal ?? 0),
        accent: AppColors.green,
      ),
      ReportKpi(
        label: 'Órdenes totales',
        value: _num(cards.ordersTotal),
        accent: AppColors.navy,
      ),
      ReportKpi(
        label: 'Ticket promedio',
        value: _money(cards.averageTicket ?? 0),
        accent: const Color(0xFF2563EB),
      ),
      ReportKpi(
        label: 'Venta promedio',
        value: _money((cards.salesTotal ?? 0) / (periodDays > 0 ? periodDays : 1)),
        accent: const Color(0xFF0EA5E9),
      ),
      ReportKpi(
        label: 'Día con mayor venta',
        value: _shortDateWeekday(data.cardsHighest.dateserverCreatedMax),
        sub: _money(data.cardsHighest.ordeTotalMax ?? 0),
        accent: AppColors.gold,
        subColor: AppColors.greenInk,
      ),
      ReportKpi(
        label: 'Día con menor venta',
        value: _shortDateWeekday(data.cardsLower.dateserverCreatedMin),
        sub: _money(data.cardsLower.ordeTotalMin ?? 0),
        accent: AppColors.red,
        subColor: AppColors.redInk,
      ),
    ],
    charts: [
      // Nivel 1: Ventas por día (75%) + Ventas por canal (25%) — spans 3:1
      // pack into one row of the 6-column grid.
      BarsChart(
        'Ventas por día',
        3,
        labels: [for (final d in salesDay) _shortDate(d.dateserverCreated)],
        values: [for (final d in salesDay) d.ordeTotal.toDouble()],
        valueLabels: [for (final d in salesDay) _money(d.ordeTotal)],
        color: AppColors.gold,
        // Only force a min-width (and horizontal scroll) past a threshold
        // that would otherwise crowd the card — below it, the chart fills
        // the card's full width like before. Unconditionally forcing a
        // fixed px-per-bar width regardless of count made short ranges
        // (e.g. 2 days) render as a tiny sliver instead of filling the
        // card, since there's no way to measure the card's actual width
        // here (see the IntrinsicHeight/LayoutBuilder note in
        // reports_page.dart's _BarsChartView).
        minBarWidth: salesDay.length > 20 ? 46 : null,
      ),
      _channelDonut(salesByChannel, orderTypeNames),
      // Nivel 2: Ventas acumuladas (75%) + Ventas por método de pago (25%).
      LineChart(
        'Ventas acumuladas',
        3,
        xLabels: [for (final d in salesAccumulated) _shortDate(d.dateserverCreated)],
        values: [for (final d in salesAccumulated) d.ordeTotalAccumulated.toDouble()],
        valueLabels: [for (final d in salesAccumulated) _money(d.ordeTotalAccumulated)],
        color: AppColors.greenInk,
        minPointWidth: salesAccumulated.length > 20 ? 50 : null,
      ),
      _paymentDonut(salesByPayment),
    ],
    tableTitle: 'Detalle de ventas',
    tableCount: '${state.tableTotalRecords} pedidos en el periodo',
    headers: const [
      ReportTableHeader('Pedido'),
      ReportTableHeader('Mesa'),
      ReportTableHeader('Total', alignRight: true),
      ReportTableHeader('Método de pago'),
      ReportTableHeader('Tipo'),
      ReportTableHeader('Estado'),
      ReportTableHeader('Sucursal'),
      ReportTableHeader('Empleado'),
      ReportTableHeader('Fecha', alignRight: true),
    ],
    rows: [
      for (final o in state.orderRows)
        ReportTableRow([
          ReportCell.plain('#${o.ordeId}', bold: true),
          ReportCell.plain(o.tablId),
          ReportCell.plain(_money(num.tryParse(o.ordeTotal) ?? 0),
              bold: true, alignRight: true),
          ReportCell.dot(o.paymName, color: paymentColor(o.paymName)),
          ReportCell.dot(o.ordeType, color: channelColor(o.ordeType)),
          stateBadge(o.ordeState),
          ReportCell.plain(o.premName),
          ReportCell.plain(o.emplName.isEmpty ? '—' : o.emplName),
          ReportCell.plain(_shortDateTime(o.dateserverCreated), alignRight: true),
        ]),
    ],
  );
}

// ===== donut builders ========================================================

DonutChart _channelDonut(
  List<SalesTypeAmount> salesByChannel,
  Map<String, String> orderTypeNames,
) {
  final total = salesByChannel.fold<num>(0, (s, x) => s + x.ordeTotal);
  return DonutChart(
    'Ventas por canal',
    1,
    size: 150,
    segments: [
      for (final s in salesByChannel)
        DonutSegment(
          orderTypeNames[s.ordeType] ?? s.ordeType,
          s.ordeTotal.toDouble(),
          channelColor(orderTypeNames[s.ordeType] ?? s.ordeType),
          _money(s.ordeTotal),
          valText2: total > 0 ? _pct(s.ordeTotal / total * 100) : null,
        ),
    ],
    center: _money(total),
    centerSub: 'venta total',
  );
}

DonutChart _paymentDonut(List<SalesPaymentAmount> salesByPayment) {
  final total = salesByPayment.fold<num>(0, (s, e) => s + e.ordeTotal);
  return DonutChart(
    'Ventas por método de pago',
    1,
    size: 150,
    segments: [
      for (final e in salesByPayment)
        DonutSegment(
          e.paymName,
          e.ordeTotal.toDouble(),
          paymentColor(e.paymName),
          _money(e.ordeTotal),
          valText2: total > 0 ? _pct(e.ordeTotal / total * 100) : null,
        ),
    ],
    center: _money(total),
    centerSub: 'venta total',
  );
}

// ===== formatting helpers ====================================================

/// Whole percent above 10% ("87%"), one decimal below ("0.9%") — matches
/// how small shares read clearer with a decimal than rounding to "1%"/"0%".
String _pct(double p) => p >= 10 ? '${p.round()}%' : '${p.toStringAsFixed(1)}%';

String _money(num n) => '\$${_grouped(n.round())}';
String _num(num n) => _grouped(n.round());

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
const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// "2026-07-08" -> "8 jul".
String _shortDate(String yyyyMMdd) {
  final d = DateTime.tryParse(yyyyMMdd);
  if (d == null) return yyyyMMdd;
  return '${d.day} ${_months[d.month - 1]}';
}

/// "2026-07-08" -> "Mié 8 jul".
String _shortDateWeekday(String? yyyyMMdd) {
  if (yyyyMMdd == null) return '—';
  final d = DateTime.tryParse(yyyyMMdd);
  if (d == null) return yyyyMMdd;
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// "2026-07-09 22:49:01" -> "9 jul 22:49".
String _shortDateTime(String dateserver) {
  final parts = dateserver.split(' ');
  final datePart = _shortDate(parts.isNotEmpty ? parts[0] : dateserver);
  final timePart = parts.length > 1 && parts[1].length >= 5 ? parts[1].substring(0, 5) : '';
  return timePart.isEmpty ? datePart : '$datePart $timePart';
}

// ===== shared palettes (order type / payment / order state) ================

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

const Map<String, (Color, Color)> _stateColors = {
  'Pagado': (Color(0xFFDCFCE7), Color(0xFF15803D)),
  'Pendiente': (Color(0xFFFEF3C7), Color(0xFFB45309)),
  'Confirmado': (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
  'Entregado': (Color(0xFFE8EAEE), Color(0xFF374151)),
  'Cancelado': (Color(0xFFFEE2E2), Color(0xFFB91C1C)),
  'En preparación': (Color(0xFFEDE9FE), Color(0xFF6D28D9)),
};

ReportCell stateBadge(String state) {
  final (bg, fg) = _stateColors[state] ?? (const Color(0xFFE8EAEE), const Color(0xFF374151));
  return ReportCell.badge(state.isEmpty ? '—' : state, bg: bg, fg: fg);
}
