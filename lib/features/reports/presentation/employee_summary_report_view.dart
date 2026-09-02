import 'package:ds_clickeat_web_admin/features/reports/controllers/employee_summary_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_employee_summary.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';

/// Maps the live `orders/employee-summary` rows (held in
/// [EmployeeSummaryState]) into the [ReportView] shape shared by every
/// report screen — like the propinas report it replaces, this one carries no
/// KPI cards or charts (`kpis`/`charts` stay empty): the detail table
/// sourced from `orders/employee-summary` IS the whole report.
ReportView buildEmployeeSummaryReportView(EmployeeSummaryState state) {
  final rows = state.rows ?? const [];
  return ReportView(
    title: 'Resumen de turno',
    subtitle: 'Resumen de turno del periodo seleccionado',
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
    tableTitle: 'Detalle de resumen de turno',
    tableCount: '${rows.length} registros en el periodo',
    headers: const [
      ReportTableHeader('Sucursal'),
      ReportTableHeader('Empleado'),
      ReportTableHeader('Completados', alignRight: true),
      ReportTableHeader('Cancelados', alignRight: true),
      ReportTableHeader('Métodos de pago'),
      ReportTableHeader('Total', alignRight: true),
      ReportTableHeader('Propinas', alignRight: true),
      ReportTableHeader('Fecha'),
    ],
    rows: [
      for (final r in rows)
        ReportTableRow([
          ReportCell.plain(r.premName),
          ReportCell.plain(r.emplName, bold: true),
          ReportCell.plain('${r.totalCompletados}', alignRight: true),
          ReportCell.plain('${r.totalCancelados}', alignRight: true),
          ReportCell.plain(_paymentsStr(r.payments)),
          ReportCell.plain(_moneyStr(r.ordeTotal), alignRight: true),
          ReportCell.plain(_moneyStr(r.tipsTotal), bold: true, alignRight: true),
          ReportCell.plain(_shortDate(r.dateserverCreated)),
        ]),
    ],
  );
}

/// Joins a group's payment breakdown into a single display string, e.g.
/// "Efectivo \$100.00, Tarjeta \$50.00" — the table has one cell per group,
/// not one row per payment method, so multiple payments render inline.
String _paymentsStr(List<EmployeeSummaryPayment> payments) {
  if (payments.isEmpty) return '—';
  return payments.map((p) => '${p.paymName} ${_moneyStr(p.paymTotal)}').join(', ');
}

/// Formats an `orders/employee-summary` money field ("903.50") keeping
/// the backend's decimals — rounding to an int here would silently drop
/// cents.
String _moneyStr(String raw) {
  final n = num.tryParse(raw) ?? 0;
  final fixed = n.toStringAsFixed(2);
  final negative = fixed.startsWith('-');
  final unsigned = negative ? fixed.substring(1) : fixed;
  final dot = unsigned.indexOf('.');
  final intPart = _grouped(int.parse(unsigned.substring(0, dot)));
  final decPart = unsigned.substring(dot + 1);
  return '\$${negative ? '-' : ''}$intPart.$decPart';
}

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

/// "2026-08-28T06:00:00.000Z" -> "28 ago".
String _shortDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.day} ${_months[d.month - 1]}';
}
