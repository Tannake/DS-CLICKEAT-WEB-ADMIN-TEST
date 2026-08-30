import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/reports_repository.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_category.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_daily.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_employee_summary.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_pagination.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_product.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart';

/// Same filter-staging/`search()`-on-demand shape and detail-table/CSV
/// plumbing as [ProductReportState]/[ProductReportController]
/// (`reports/product-category-export`, mirroring `reports/product-export`),
/// minus producto/tamaño/opción — only sucursal, tipo de pedido and
/// categoría apply at this rollup level.
class CategoryReportState {
  final List<PremiseOption> premises;
  final List<OrderTypeOption> orderTypes;
  final List<ProductCategoryParamOption> categories;
  final List<EmployeeOption> employees;

  // Empty selection means "no filter" (sent to the backend as
  // omitted/null, matching every record) — every set starts empty.
  final Set<int> selectedPremIds;
  final Set<String> selectedOrderTypes;
  final Set<int> selectedProdcIds;
  final Set<int> selectedEmplIds;
  final DateTime dateStart;
  final DateTime dateEnd;

  final CategoryReportData? data;
  // The detail table's current page of rows — fetched from
  // `reports/product-category-export`, also what backs the "Exportar CSV"
  // button (with `allRecords: true`, unpaginated). [tablePage]/
  // [tableTotalPages] drive the on-screen paginator; both are 1-indexed,
  // [tableTotalPages] is 0 when there are no matching rows.
  final List<CategoryCsvRow> categoryRows;
  final int tablePage;
  final int tableTotalPages;
  final int tableTotalRecords;
  // Separate from [loadingData] so paging the detail table doesn't flash
  // the KPI cards/charts into their loading state.
  final bool loadingTable;
  final bool loadingParams;
  final bool loadingData;
  final bool hasQueried;
  final String? error;

  const CategoryReportState({
    this.premises = const [],
    this.orderTypes = const [],
    this.categories = const [],
    this.employees = const [],
    this.selectedPremIds = const {},
    this.selectedOrderTypes = const {},
    this.selectedProdcIds = const {},
    this.selectedEmplIds = const {},
    required this.dateStart,
    required this.dateEnd,
    this.data,
    this.categoryRows = const [],
    this.tablePage = 1,
    this.tableTotalPages = 0,
    this.tableTotalRecords = 0,
    this.loadingTable = false,
    this.loadingParams = false,
    this.loadingData = false,
    this.hasQueried = false,
    this.error,
  });

  CategoryReportState copyWith({
    List<PremiseOption>? premises,
    List<OrderTypeOption>? orderTypes,
    List<ProductCategoryParamOption>? categories,
    List<EmployeeOption>? employees,
    Set<int>? selectedPremIds,
    Set<String>? selectedOrderTypes,
    Set<int>? selectedProdcIds,
    Set<int>? selectedEmplIds,
    DateTime? dateStart,
    DateTime? dateEnd,
    CategoryReportData? data,
    List<CategoryCsvRow>? categoryRows,
    int? tablePage,
    int? tableTotalPages,
    int? tableTotalRecords,
    bool? loadingTable,
    bool? loadingParams,
    bool? loadingData,
    bool? hasQueried,
    String? error,
  }) {
    return CategoryReportState(
      premises: premises ?? this.premises,
      orderTypes: orderTypes ?? this.orderTypes,
      categories: categories ?? this.categories,
      employees: employees ?? this.employees,
      selectedPremIds: selectedPremIds ?? this.selectedPremIds,
      selectedOrderTypes: selectedOrderTypes ?? this.selectedOrderTypes,
      selectedProdcIds: selectedProdcIds ?? this.selectedProdcIds,
      selectedEmplIds: selectedEmplIds ?? this.selectedEmplIds,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      data: data ?? this.data,
      categoryRows: categoryRows ?? this.categoryRows,
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

final categoryReportControllerProvider =
    StateNotifierProvider<CategoryReportController, CategoryReportState>((ref) {
  return CategoryReportController(ref);
});

class CategoryReportController extends StateNotifier<CategoryReportState> {
  CategoryReportController(this._ref)
      : super(CategoryReportState(
          dateStart: DateTime.now(),
          dateEnd: DateTime.now(),
        ));
  final Ref _ref;
  int _loadToken = 0;
  int _tableLoadToken = 0;

  /// Loads the four fetched filter parameter sources (premises, order
  /// types, categories, employees) but does NOT fetch the report — the user
  /// must press "Consultar" ([search]) first. Safe to call more than once;
  /// no-ops once already loaded.
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
        repo.getProductCategoryParam(session.userId),
        repo.getEmployeeParam(session.userId),
      ]);
      state = state.copyWith(
        premises: results[0] as List<PremiseOption>,
        orderTypes: results[1] as List<OrderTypeOption>,
        categories: results[2] as List<ProductCategoryParamOption>,
        employees: results[3] as List<EmployeeOption>,
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
  void applyProdcIds(Set<int> ids) => state = state.copyWith(selectedProdcIds: ids);
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
      final repo = _ref.read(reportsRepositoryProvider);
      final results = await Future.wait([
        repo.getProductCategory(
          premIds: state.selectedPremIds.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          prodcIds: state.selectedProdcIds.toList(),
          emplIds: state.selectedEmplIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
        ),
        repo.getProductCategoryCsv(
          premIds: state.selectedPremIds.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          prodcIds: state.selectedProdcIds.toList(),
          emplIds: state.selectedEmplIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
        ),
      ]);
      if (token != _loadToken) return;
      final page = results[1] as PagedRows<CategoryCsvRow>;
      state = state.copyWith(
        data: results[0] as CategoryReportData,
        categoryRows: page.rows,
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
  /// [CategoryReportState.loadingTable] flips while the request is in
  /// flight.
  Future<void> goToTablePage(int page) async {
    if (page < 1 || page == state.tablePage) return;
    final token = ++_tableLoadToken;
    state = state.copyWith(loadingTable: true);
    try {
      final result = await _ref.read(reportsRepositoryProvider).getProductCategoryCsv(
            premIds: state.selectedPremIds.toList(),
            ordeTypes: state.selectedOrderTypes.toList(),
            prodcIds: state.selectedProdcIds.toList(),
            emplIds: state.selectedEmplIds.toList(),
            dateStart: _fmtDate(state.dateStart),
            dateEnd: _fmtDate(state.dateEnd),
            page: page,
          );
      if (token != _tableLoadToken) return;
      state = state.copyWith(
        categoryRows: result.rows,
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
