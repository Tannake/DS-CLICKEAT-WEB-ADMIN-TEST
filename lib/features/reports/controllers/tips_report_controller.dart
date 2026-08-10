import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/reports_repository.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart' show PremiseOption;
import 'package:ds_clickeat_web_admin/features/reports/models/report_tips.dart';

/// Simpler filter-staging/`search()`-on-demand shape than the other reports'
/// controllers: `reports/tips-export` IS the report (no separate
/// KPI/chart-shaped endpoint and no server pagination), so there's no
/// `data`/detail-table split and no `goToTablePage` — [rows] is loaded once
/// per [search] and rendered in full.
class TipsReportState {
  final List<PremiseOption> premises;
  final List<EmployeeOption> employees;

  // Empty selection means "no filter" (sent to the backend as
  // omitted/null, matching every record) — every set starts empty.
  final Set<int> selectedPremIds;
  final Set<int> selectedEmplIds;
  final String orderIdText;
  final DateTime dateStart;
  final DateTime dateEnd;

  // Null until the first successful [loadData] (even one returning zero
  // rows) — mirrors the other controllers' nullable `data` field, so a
  // legitimately-empty result doesn't re-trigger the full-page "initial
  // load" spinner (see `_buildLiveReportBody`'s `initialLoad` in
  // reports_page.dart) on a later search.
  final List<TipsCsvRow>? rows;
  final bool loadingParams;
  final bool loadingData;
  final bool hasQueried;
  final String? error;

  const TipsReportState({
    this.premises = const [],
    this.employees = const [],
    this.selectedPremIds = const {},
    this.selectedEmplIds = const {},
    this.orderIdText = '',
    required this.dateStart,
    required this.dateEnd,
    this.rows,
    this.loadingParams = false,
    this.loadingData = false,
    this.hasQueried = false,
    this.error,
  });

  TipsReportState copyWith({
    List<PremiseOption>? premises,
    List<EmployeeOption>? employees,
    Set<int>? selectedPremIds,
    Set<int>? selectedEmplIds,
    String? orderIdText,
    DateTime? dateStart,
    DateTime? dateEnd,
    List<TipsCsvRow>? rows,
    bool? loadingParams,
    bool? loadingData,
    bool? hasQueried,
    String? error,
  }) {
    return TipsReportState(
      premises: premises ?? this.premises,
      employees: employees ?? this.employees,
      selectedPremIds: selectedPremIds ?? this.selectedPremIds,
      selectedEmplIds: selectedEmplIds ?? this.selectedEmplIds,
      orderIdText: orderIdText ?? this.orderIdText,
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

final tipsReportControllerProvider =
    StateNotifierProvider<TipsReportController, TipsReportState>((ref) {
  return TipsReportController(ref);
});

class TipsReportController extends StateNotifier<TipsReportState> {
  TipsReportController(this._ref)
      : super(TipsReportState(
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
  void applyOrderIdText(String text) => state = state.copyWith(orderIdText: text);
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
      final rows = await _ref.read(reportsRepositoryProvider).getTipsExport(
            premIds: state.selectedPremIds.toList(),
            emplIds: state.selectedEmplIds.toList(),
            ordeId: int.tryParse(state.orderIdText.trim()),
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
