import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/reports_repository.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart' show PremiseOption;
import 'package:ds_clickeat_web_admin/features/reports/models/report_employee_summary.dart';

/// Simpler filter-staging/`search()`-on-demand shape than the other reports'
/// controllers: `orders/employee-summary` IS the report (no separate
/// KPI/chart-shaped endpoint and no server pagination), so there's no
/// `data`/detail-table split and no `goToTablePage` — [rows] is loaded once
/// per [search] and rendered in full.
class EmployeeSummaryState {
  final List<PremiseOption> premises;
  final List<EmployeeOption> employees;

  // Empty selection means "no filter" (sent to the backend as
  // omitted/null, matching every record) — every set starts empty.
  final Set<int> selectedPremIds;
  final Set<int> selectedEmplIds;
  final DateTime dateStart;
  final DateTime dateEnd;

  // Null until the first successful [loadData] (even one returning zero
  // rows) — mirrors the other controllers' nullable `data` field, so a
  // legitimately-empty result doesn't re-trigger the full-page "initial
  // load" spinner (see `_buildLiveReportBody`'s `initialLoad` in
  // reports_page.dart) on a later search.
  final List<EmployeeSummaryRow>? rows;
  final bool loadingParams;
  final bool loadingData;
  final bool hasQueried;
  final String? error;

  const EmployeeSummaryState({
    this.premises = const [],
    this.employees = const [],
    this.selectedPremIds = const {},
    this.selectedEmplIds = const {},
    required this.dateStart,
    required this.dateEnd,
    this.rows,
    this.loadingParams = false,
    this.loadingData = false,
    this.hasQueried = false,
    this.error,
  });

  EmployeeSummaryState copyWith({
    List<PremiseOption>? premises,
    List<EmployeeOption>? employees,
    Set<int>? selectedPremIds,
    Set<int>? selectedEmplIds,
    DateTime? dateStart,
    DateTime? dateEnd,
    List<EmployeeSummaryRow>? rows,
    bool? loadingParams,
    bool? loadingData,
    bool? hasQueried,
    String? error,
  }) {
    return EmployeeSummaryState(
      premises: premises ?? this.premises,
      employees: employees ?? this.employees,
      selectedPremIds: selectedPremIds ?? this.selectedPremIds,
      selectedEmplIds: selectedEmplIds ?? this.selectedEmplIds,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      rows: rows ?? this.rows,
      loadingParams: loadingParams ?? this.loadingParams,
      loadingData: loadingData ?? this.loadingData,
      hasQueried: hasQueried ?? this.hasQueried,
      error: error,
    );
  }
}

final employeeSummaryControllerProvider =
    StateNotifierProvider<EmployeeSummaryController, EmployeeSummaryState>((ref) {
  return EmployeeSummaryController(ref);
});

class EmployeeSummaryController extends StateNotifier<EmployeeSummaryState> {
  EmployeeSummaryController(this._ref)
      : super(EmployeeSummaryState(
          dateStart: DateTime.now(),
          dateEnd: DateTime.now(),
        ));
  final Ref _ref;
  int _loadToken = 0;

  /// Loads the two fetched filter parameter sources (premises, employees)
  /// but does NOT fetch the report — the user must press "Consultar"
  /// ([search]) first. Safe to call more than once; no-ops once already
  /// loaded.
  Future<void> loadParameters() async {
    if (state.premises.isNotEmpty || state.loadingParams) return;
    final session = _ref.read(sessionControllerProvider);
    if (session == null) return;

    state = state.copyWith(loadingParams: true, error: null);
    try {
      final repo = _ref.read(reportsRepositoryProvider);
      final results = await Future.wait([
        repo.getPremisesParam(session.userId),
        repo.getEmployeeParam(session.userId),
      ]);
      state = state.copyWith(
        premises: results[0] as List<PremiseOption>,
        employees: results[1] as List<EmployeeOption>,
        loadingParams: false,
      );
    } catch (e) {
      state = state.copyWith(loadingParams: false, error: e.toString());
    }
  }

  // All of these only stage the filter — the report only refreshes when
  // the user presses "Consultar" ([search]).
  void applyPremises(Set<int> ids) => state = state.copyWith(selectedPremIds: ids);
  void applyEmplIds(Set<int> ids) => state = state.copyWith(selectedEmplIds: ids);
  void applyDateRange(DateTime start, DateTime end) =>
      state = state.copyWith(dateStart: start, dateEnd: end);

  /// Runs the report query with the currently staged filters.
  Future<void> search() async {
    state = state.copyWith(hasQueried: true);
    await loadData();
  }

  Future<void> loadData() async {
    final token = ++_loadToken;
    state = state.copyWith(loadingData: true, error: null);
    try {
      final rows = await _ref.read(reportsRepositoryProvider).getEmployeeSummary(
            premIds: state.selectedPremIds.toList(),
            emplIds: state.selectedEmplIds.toList(),
            dateStart: _fmtDate(state.dateStart),
            dateEnd: _fmtDate(state.dateEnd),
          );
      if (token != _loadToken) return;
      state = state.copyWith(rows: rows, loadingData: false);
    } catch (e) {
      if (token != _loadToken) return;
      state = state.copyWith(loadingData: false, error: e.toString());
    }
  }
}

String _fmtDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
