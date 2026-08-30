import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/reports_repository.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_daily.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_employee_summary.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_pagination.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart';

class SalesReportState {
  final List<PremiseOption> premises;
  final List<OrderTypeOption> orderTypes;
  final List<PaymentOption> payments;
  final List<OrderStateOption> orderStates;
  final List<ReasonOption> reasons;
  final List<EmployeeOption> employees;

  // Unlike the daily dashboard, an empty selection here means "no filter"
  // (sent to the backend as omitted/null, matching every record) rather
  // than "all selected" — so every set starts empty.
  final Set<int> selectedPremIds;
  final Set<String> selectedOrderTypes;
  final Set<int> selectedPaymIds;
  final Set<String> selectedOrderStates;
  final Set<int> selectedReasIds;
  final Set<int> selectedEmplIds;
  final String orderIdText;
  final DateTime dateStart;
  final DateTime dateEnd;

  final SalesReportData? data;
  // The detail table's current page of rows — fetched from
  // `reports/sales-export` (the same per-order data `reports/sales`'s
  // `orders_summary` used to carry) rather than from [data], since it's
  // also what backs the "Exportar CSV" button (with `allRecords: true`,
  // unpaginated). [tablePage]/[tableTotalPages] drive the on-screen
  // paginator; both are 1-indexed, [tableTotalPages] is 0 when there are no
  // matching rows.
  final List<SalesCsvRow> orderRows;
  final int tablePage;
  final int tableTotalPages;
  final int tableTotalRecords;
  // Separate from [loadingData] so paging the detail table doesn't flash
  // the KPI cards/charts into their loading state — only the table's own
  // section shows a spinner while a page change is in flight.
  final bool loadingTable;
  final bool loadingParams;
  final bool loadingData;
  final bool hasQueried;
  final String? error;

  const SalesReportState({
    this.premises = const [],
    this.orderTypes = const [],
    this.payments = const [],
    this.orderStates = const [],
    this.reasons = const [],
    this.employees = const [],
    this.selectedPremIds = const {},
    this.selectedOrderTypes = const {},
    this.selectedPaymIds = const {},
    this.selectedOrderStates = const {},
    this.selectedReasIds = const {},
    this.selectedEmplIds = const {},
    this.orderIdText = '',
    required this.dateStart,
    required this.dateEnd,
    this.data,
    this.orderRows = const [],
    this.tablePage = 1,
    this.tableTotalPages = 0,
    this.tableTotalRecords = 0,
    this.loadingTable = false,
    this.loadingParams = false,
    this.loadingData = false,
    this.hasQueried = false,
    this.error,
  });

  SalesReportState copyWith({
    List<PremiseOption>? premises,
    List<OrderTypeOption>? orderTypes,
    List<PaymentOption>? payments,
    List<OrderStateOption>? orderStates,
    List<ReasonOption>? reasons,
    List<EmployeeOption>? employees,
    Set<int>? selectedPremIds,
    Set<String>? selectedOrderTypes,
    Set<int>? selectedPaymIds,
    Set<String>? selectedOrderStates,
    Set<int>? selectedReasIds,
    Set<int>? selectedEmplIds,
    String? orderIdText,
    DateTime? dateStart,
    DateTime? dateEnd,
    SalesReportData? data,
    List<SalesCsvRow>? orderRows,
    int? tablePage,
    int? tableTotalPages,
    int? tableTotalRecords,
    bool? loadingTable,
    bool? loadingParams,
    bool? loadingData,
    bool? hasQueried,
    String? error,
  }) {
    return SalesReportState(
      premises: premises ?? this.premises,
      orderTypes: orderTypes ?? this.orderTypes,
      payments: payments ?? this.payments,
      orderStates: orderStates ?? this.orderStates,
      reasons: reasons ?? this.reasons,
      employees: employees ?? this.employees,
      selectedPremIds: selectedPremIds ?? this.selectedPremIds,
      selectedOrderTypes: selectedOrderTypes ?? this.selectedOrderTypes,
      selectedPaymIds: selectedPaymIds ?? this.selectedPaymIds,
      selectedOrderStates: selectedOrderStates ?? this.selectedOrderStates,
      selectedReasIds: selectedReasIds ?? this.selectedReasIds,
      selectedEmplIds: selectedEmplIds ?? this.selectedEmplIds,
      orderIdText: orderIdText ?? this.orderIdText,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      data: data ?? this.data,
      orderRows: orderRows ?? this.orderRows,
      tablePage: tablePage ?? this.tablePage,
      tableTotalPages: tableTotalPages ?? this.tableTotalPages,
      tableTotalRecords: tableTotalRecords ?? this.tableTotalRecords,
      loadingTable: loadingTable ?? this.loadingTable,
      loadingParams: loadingParams ?? this.loadingParams,
      loadingData: loadingData ?? this.loadingData,
      hasQueried: hasQueried ?? this.hasQueried,
      error: error,
    );
  }
}

final salesReportControllerProvider =
    StateNotifierProvider<SalesReportController, SalesReportState>((ref) {
  return SalesReportController(ref);
});

class SalesReportController extends StateNotifier<SalesReportState> {
  SalesReportController(this._ref)
      : super(SalesReportState(
          dateStart: DateTime.now(),
          dateEnd: DateTime.now(),
        ));
  final Ref _ref;
  int _loadToken = 0;
  int _tableLoadToken = 0;

  /// Loads the six fetched filter parameter sources (premises, order
  /// types, payments, order states, cancellation reasons, employees) but
  /// does NOT fetch the report — the user must press "Consultar" ([search])
  /// first. Safe to call more than once; no-ops once already loaded.
  Future<void> loadParameters() async {
    if (state.premises.isNotEmpty || state.loadingParams) return;
    final session = _ref.read(sessionControllerProvider);
    if (session == null) return;

    state = state.copyWith(loadingParams: true, error: null);
    try {
      final repo = _ref.read(reportsRepositoryProvider);
      final results = await Future.wait([
        repo.getPremisesParam(session.userId),
        repo.getOrderTypes(),
        repo.getPayments(session.userId),
        repo.getOrderStates(),
        repo.getReasonCancel(session.userId),
        repo.getEmployeeParam(session.userId),
      ]);
      state = state.copyWith(
        premises: results[0] as List<PremiseOption>,
        orderTypes: results[1] as List<OrderTypeOption>,
        payments: results[2] as List<PaymentOption>,
        orderStates: results[3] as List<OrderStateOption>,
        reasons: results[4] as List<ReasonOption>,
        employees: results[5] as List<EmployeeOption>,
        loadingParams: false,
      );
    } catch (e) {
      state = state.copyWith(loadingParams: false, error: e.toString());
    }
  }

  // All of these only stage the filter — the report only refreshes when
  // the user presses "Consultar" ([search]).
  void applyPremises(Set<int> ids) => state = state.copyWith(selectedPremIds: ids);
  void applyOrderTypes(Set<String> types) => state = state.copyWith(selectedOrderTypes: types);
  void applyPaymIds(Set<int> ids) => state = state.copyWith(selectedPaymIds: ids);
  void applyOrderStates(Set<String> states) => state = state.copyWith(selectedOrderStates: states);
  void applyReasIds(Set<int> ids) => state = state.copyWith(selectedReasIds: ids);
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
      final repo = _ref.read(reportsRepositoryProvider);
      final ordeId = int.tryParse(state.orderIdText.trim());
      final results = await Future.wait([
        repo.getSales(
          premIds: state.selectedPremIds.toList(),
          ordeId: ordeId,
          ordeStates: state.selectedOrderStates.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          paymIds: state.selectedPaymIds.toList(),
          reasIds: state.selectedReasIds.toList(),
          emplIds: state.selectedEmplIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
        ),
        repo.getSalesCsv(
          premIds: state.selectedPremIds.toList(),
          ordeId: ordeId,
          ordeStates: state.selectedOrderStates.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          paymIds: state.selectedPaymIds.toList(),
          reasIds: state.selectedReasIds.toList(),
          emplIds: state.selectedEmplIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
        ),
      ]);
      if (token != _loadToken) return;
      final page = results[1] as PagedRows<SalesCsvRow>;
      state = state.copyWith(
        data: results[0] as SalesReportData,
        orderRows: page.rows,
        tablePage: page.pagination?.currentPage ?? 1,
        tableTotalPages: page.pagination?.totalPages ?? (page.rows.isEmpty ? 0 : 1),
        tableTotalRecords: page.pagination?.totalRecords ?? page.rows.length,
        loadingData: false,
      );
    } catch (e) {
      if (token != _loadToken) return;
      state = state.copyWith(loadingData: false, error: e.toString());
    }
  }

  /// Fetches a different page of the detail table with the currently
  /// applied filters — does not touch [data]/the KPI cards or charts, only
  /// [SalesReportState.loadingTable] flips while the request is in flight.
  Future<void> goToTablePage(int page) async {
    if (page < 1 || page == state.tablePage) return;
    final token = ++_tableLoadToken;
    state = state.copyWith(loadingTable: true);
    try {
      final result = await _ref.read(reportsRepositoryProvider).getSalesCsv(
            premIds: state.selectedPremIds.toList(),
            ordeId: int.tryParse(state.orderIdText.trim()),
            ordeStates: state.selectedOrderStates.toList(),
            ordeTypes: state.selectedOrderTypes.toList(),
            paymIds: state.selectedPaymIds.toList(),
            reasIds: state.selectedReasIds.toList(),
            emplIds: state.selectedEmplIds.toList(),
            dateStart: _fmtDate(state.dateStart),
            dateEnd: _fmtDate(state.dateEnd),
            page: page,
          );
      if (token != _tableLoadToken) return;
      state = state.copyWith(
        orderRows: result.rows,
        tablePage: result.pagination?.currentPage ?? page,
        tableTotalPages: result.pagination?.totalPages ?? state.tableTotalPages,
        tableTotalRecords: result.pagination?.totalRecords ?? state.tableTotalRecords,
        loadingTable: false,
      );
    } catch (e) {
      if (token != _tableLoadToken) return;
      state = state.copyWith(loadingTable: false, error: e.toString());
    }
  }
}

String _fmtDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
