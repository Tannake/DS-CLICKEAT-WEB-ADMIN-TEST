import 'package:ds_clickeat_web_admin/features/reports/controllers/tips_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/orders_report_view.dart'
    show channelColor;

/// Maps the live `reports/tips-export` rows (held in [TipsReportState]) into
/// the [ReportView] shape shared by every report screen — unlike the other
/// reports, this one carries no KPI cards or charts (`kpis`/`charts` stay
/// empty): the detail table sourced from `reports/tips-export` IS the whole
/// report.
ReportView buildTipsReportView(TipsReportState state) {
  final rows = state.rows ?? const [];
  return ReportView(
    title: 'Reporte de propinas',
    subtitle: 'Propinas del periodo seleccionado',
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
        'Empleado',
        ReportFilter.summarize(
          items: state.employees.map((e) => e.emplId).toList(),
          labelOf: (id) =>
              state.employees.firstWhere((e) => e.emplId == id).emplName,
          selected: state.selectedEmplIds,
        ),
      ),
    ],
    kpis: const [],
    charts: const [],
    tableTitle: 'Detalle de propinas',
    tableCount: '${rows.length} pedidos en el periodo',
    headers: const [
      ReportTableHeader('Pedido'),
      ReportTableHeader('Empleado'),
      ReportTableHeader('Mesa'),
      ReportTableHeader('Total', alignRight: true),
      ReportTableHeader('% Propina', alignRight: true),
      ReportTableHeader('Total con propina', alignRight: true),
      ReportTableHeader('Propina', alignRight: true),
      ReportTableHeader('Tipo'),
      ReportTableHeader('Sucursal'),
      ReportTableHeader('Fecha'),
    ],
    rows: [
      for (final r in rows)
        ReportTableRow([
          ReportCell.plain('#${r.ordeId}', bold: true),
          ReportCell.plain(r.emplName),
          ReportCell.plain(r.tablId),
          ReportCell.plain(_moneyStr(r.ordeTotal), alignRight: true),
          ReportCell.plain('${r.tipsPercentage}%', alignRight: true),
          ReportCell.plain(_moneyStr(r.ordeTotalTips), bold: true, alignRight: true),
          ReportCell.plain(_moneyStr(r.totalTips), alignRight: true),
          ReportCell.dot(r.ordeType, color: channelColor(r.ordeType)),
          ReportCell.plain(r.premName),
          ReportCell.plain(r.dateserverCreated),
        ]),
    ],
  );
}

/// Formats a `reports/tips-export` money field ("903.00") the same way the
/// other reports' detail tables do.
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
