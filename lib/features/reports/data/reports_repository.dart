import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_category.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_daily.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_orders.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_pagination.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_product.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_employee_summary.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(dioProvider));
});

class ReportsRepository {
  ReportsRepository(this._dio);
  final Dio _dio;

  /// GET `reports/parameter/orders-type` — the order-type options for the
  /// "Tipo de pedido" multi-select filter.
  Future<List<OrderTypeOption>> getOrderTypes() async {
    final res = await _dio.get('reports/parameter/orders-type');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) =>
              OrderTypeOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/daily` — the "Dashboard diario" data, scoped to the
  /// selected premises and order types (both sent as repeated query params,
  /// e.g. `prem_id=5&prem_id=8`, which the backend collects into an array).
  /// An empty list means "no filter" for that param, so it's omitted from
  /// the query entirely rather than sent as an empty array.
  Future<DailyReportData> getDaily({
    required List<int> premIds,
    required List<String> orderTypes,
  }) async {
    final res = await _dio.get('reports/daily', queryParameters: {
      if (premIds.isNotEmpty) 'prem_id': premIds,
      if (orderTypes.isNotEmpty) 'orde_type': orderTypes,
    });
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      final result = data['result'] as Map;
      final raw = result['fun_reports_daily'] is Map
          ? result['fun_reports_daily'] as Map
          : result;
      return DailyReportData.fromJson(Map<String, dynamic>.from(raw));
    }
    return DailyReportData.empty;
  }

  /// GET `reports/parameter/premises/<userId>` — the branch options for the
  /// "Sucursal" filter on the sales report. A dedicated endpoint from the
  /// generic `premises/essential` one the daily dashboard uses.
  Future<List<PremiseOption>> getPremisesParam(int userId) async {
    final res = await _dio.get('reports/parameter/premises/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => PremiseOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/parameter/orders-state` — the "Estado" filter options.
  /// Unlike the other parameter endpoints, this one takes no parameters.
  Future<List<OrderStateOption>> getOrderStates() async {
    final res = await _dio.get('reports/parameter/orders-state');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => OrderStateOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/parameter/payments/<userId>` — the "Método de pago"
  /// filter options.
  Future<List<PaymentOption>> getPayments(int userId) async {
    final res = await _dio.get('reports/parameter/payments/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => PaymentOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/parameter/reason-cancel/<userId>` — the "Razón de
  /// cancelación" filter options.
  Future<List<ReasonOption>> getReasonCancel(int userId) async {
    final res = await _dio.get('reports/parameter/reason-cancel/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => ReasonOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/sales` — the "Reporte de ventas" data. All eight
  /// `fun_reports_sales` parameters are optional filters sent as (repeated)
  /// query params; an empty selection means "no filter" for that param and
  /// is omitted entirely (backend treats a missing/null array as "match
  /// everything") rather than sent as `null` or `[]`. `dateStart`/`dateEnd`
  /// are the two non-nullable params and always sent, formatted
  /// `yyyy-MM-dd`.
  Future<SalesReportData> getSales({
    required List<int> premIds,
    required int? ordeId,
    required List<String> ordeStates,
    required List<String> ordeTypes,
    required List<int> paymIds,
    required List<int> reasIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
  }) async {
    final res = await _dio.get(
      'reports/sales',
      queryParameters: _reportFilterQuery(
        premIds: premIds,
        ordeId: ordeId,
        ordeStates: ordeStates,
        ordeTypes: ordeTypes,
        paymIds: paymIds,
        reasIds: reasIds,
        emplIds: emplIds,
        dateStart: dateStart,
        dateEnd: dateEnd,
      ),
    );
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      final result = data['result'] as Map;
      final raw = result['fun_reports_sales'] is Map
          ? result['fun_reports_sales'] as Map
          : result;
      return SalesReportData.fromJson(Map<String, dynamic>.from(raw));
    }
    return SalesReportData.empty;
  }

  /// GET `reports/sales-export` — the raw, per-order rows behind both the
  /// sales report's detail table and its "Exportar CSV" button. Takes the
  /// exact same eight filters as [getSales] (same omit-when-empty/null
  /// rules), and the response is a flat list directly under `result`
  /// rather than nested under a function name.
  ///
  /// [allRecords] true fetches every matching row in one shot (used for CSV
  /// export, which must not be paginated) — the backend then omits
  /// `pagination` entirely. [allRecords] false (the on-screen table's case)
  /// paginates at 100 rows/page server-side; [page] selects which page,
  /// ignored when [allRecords] is true.
  Future<PagedRows<SalesCsvRow>> getSalesCsv({
    required List<int> premIds,
    required int? ordeId,
    required List<String> ordeStates,
    required List<String> ordeTypes,
    required List<int> paymIds,
    required List<int> reasIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
    bool allRecords = false,
    int page = 1,
  }) async {
    final query = _reportFilterQuery(
      premIds: premIds,
      ordeId: ordeId,
      ordeStates: ordeStates,
      ordeTypes: ordeTypes,
      paymIds: paymIds,
      reasIds: reasIds,
      emplIds: emplIds,
      dateStart: dateStart,
      dateEnd: dateEnd,
    );
    if (allRecords) {
      query['all_records'] = 'true';
    } else {
      query['page'] = page;
    }
    final res = await _dio.get('reports/sales-export', queryParameters: query);
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      final rows = (data['result'] as List)
          .map((e) => SalesCsvRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final pag = data['pagination'];
      return PagedRows(
        rows: rows,
        pagination: pag is Map ? ReportPagination.fromJson(Map<String, dynamic>.from(pag)) : null,
      );
    }
    return const PagedRows(rows: [], pagination: null);
  }

  /// GET `reports/orders` — the "Reporte de pedidos" data. Same eight
  /// filters/rules as [getSales]. `result` has been observed wrapped both
  /// as a bare map (matching `reports/sales`'s `result.fun_reports_sales`
  /// and `reports/daily`'s `result.fun_reports_daily`) and as a one-element
  /// list (`result[0].fun_reports_orders`) — accept either shape rather
  /// than assuming one, since guessing wrong silently returns
  /// [OrdersReportData.empty] with no error (the KPI cards/charts just
  /// render as all-zero/"Sin datos" instead of failing loudly).
  Future<OrdersReportData> getOrders({
    required List<int> premIds,
    required int? ordeId,
    required List<String> ordeStates,
    required List<String> ordeTypes,
    required List<int> paymIds,
    required List<int> reasIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
  }) async {
    final res = await _dio.get(
      'reports/orders',
      queryParameters: _reportFilterQuery(
        premIds: premIds,
        ordeId: ordeId,
        ordeStates: ordeStates,
        ordeTypes: ordeTypes,
        paymIds: paymIds,
        reasIds: reasIds,
        emplIds: emplIds,
        dateStart: dateStart,
        dateEnd: dateEnd,
      ),
    );
    final data = res.data;
    if (data is Map && data['state'] == 1) {
      final result = data['result'];
      Map? raw;
      if (result is Map && result['fun_reports_orders'] is Map) {
        raw = result['fun_reports_orders'] as Map;
      } else if (result is List &&
          result.isNotEmpty &&
          result.first is Map &&
          (result.first as Map)['fun_reports_orders'] is Map) {
        raw = (result.first as Map)['fun_reports_orders'] as Map;
      } else if (result is Map) {
        raw = result;
      }
      if (raw != null) {
        return OrdersReportData.fromJson(Map<String, dynamic>.from(raw));
      }
    }
    return OrdersReportData.empty;
  }

  /// GET `reports/orders-export` — the per-line-item rows behind both the
  /// orders report's detail table and its "Exportar CSV" button. Same eight
  /// filters/rules as [getSales], and the same [allRecords]/[page]
  /// pagination contract as [getSalesCsv]; the response is a flat list
  /// directly under `result`.
  Future<PagedRows<OrdersCsvRow>> getOrdersCsv({
    required List<int> premIds,
    required int? ordeId,
    required List<String> ordeStates,
    required List<String> ordeTypes,
    required List<int> paymIds,
    required List<int> reasIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
    bool allRecords = false,
    int page = 1,
  }) async {
    final query = _reportFilterQuery(
      premIds: premIds,
      ordeId: ordeId,
      ordeStates: ordeStates,
      ordeTypes: ordeTypes,
      paymIds: paymIds,
      reasIds: reasIds,
      emplIds: emplIds,
      dateStart: dateStart,
      dateEnd: dateEnd,
    );
    if (allRecords) {
      query['all_records'] = 'true';
    } else {
      query['page'] = page;
    }
    final res = await _dio.get('reports/orders-export', queryParameters: query);
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      final rows = (data['result'] as List)
          .map((e) => OrdersCsvRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final pag = data['pagination'];
      return PagedRows(
        rows: rows,
        pagination: pag is Map ? ReportPagination.fromJson(Map<String, dynamic>.from(pag)) : null,
      );
    }
    return const PagedRows(rows: [], pagination: null);
  }

  /// GET `reports/parameter/product/<userId>` — the "Producto" filter options.
  Future<List<ProductParamOption>> getProductParam(int userId) async {
    final res = await _dio.get('reports/parameter/product/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => ProductParamOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/parameter/product-category/<userId>` — the "Categoría"
  /// filter options.
  Future<List<ProductCategoryParamOption>> getProductCategoryParam(int userId) async {
    final res = await _dio.get('reports/parameter/product-category/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => ProductCategoryParamOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/parameter/product-size/<userId>` — the "Tamaño" filter
  /// options.
  Future<List<ProductSizeParamOption>> getProductSizeParam(int userId) async {
    final res = await _dio.get('reports/parameter/product-size/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => ProductSizeParamOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/parameter/product-option/<userId>` — the "Opción" filter
  /// options.
  Future<List<ProductOptionParamOption>> getProductOptionParam(int userId) async {
    final res = await _dio.get('reports/parameter/product-option/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => ProductOptionParamOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `reports/product` — the "Reporte de productos" data. Same premise/
  /// order-type/date filters as [getSales], plus four product-specific
  /// filters (`prod_id`, `prodc_id`, `prods_id`, `prodo_id`) — all follow the
  /// same omit-when-empty rule as the rest of `_reportFilterQuery`.
  Future<ProductReportData> getProduct({
    required List<int> premIds,
    required List<String> ordeTypes,
    required List<int> prodIds,
    required List<int> prodcIds,
    required List<int> prodsIds,
    required List<int> prodoIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
  }) async {
    final res = await _dio.get('reports/product', queryParameters: {
      if (premIds.isNotEmpty) 'prem_id': premIds,
      if (ordeTypes.isNotEmpty) 'orde_type': ordeTypes,
      if (prodIds.isNotEmpty) 'prod_id': prodIds,
      if (prodcIds.isNotEmpty) 'prodc_id': prodcIds,
      if (prodsIds.isNotEmpty) 'prods_id': prodsIds,
      if (prodoIds.isNotEmpty) 'prodo_id': prodoIds,
      if (emplIds.isNotEmpty) 'empl_id': emplIds,
      'date_start': dateStart,
      'date_end': dateEnd,
    });
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      return ProductReportData.fromJson(Map<String, dynamic>.from(data['result'] as Map));
    }
    return ProductReportData.empty;
  }

  /// GET `reports/product-export` — the per-line-item rows behind both the
  /// products report's detail table and its "Exportar CSV" button. Same six
  /// filters as [getProduct] (premise/order-type/producto/categoría/tamaño/
  /// opción, same omit-when-empty rules), and the same [allRecords]/[page]
  /// pagination contract as [getOrdersCsv]/[getSalesCsv]; the response is a
  /// flat list directly under `result`.
  Future<PagedRows<ProductCsvRow>> getProductCsv({
    required List<int> premIds,
    required List<String> ordeTypes,
    required List<int> prodIds,
    required List<int> prodcIds,
    required List<int> prodsIds,
    required List<int> prodoIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
    bool allRecords = false,
    int page = 1,
  }) async {
    final query = <String, dynamic>{
      if (premIds.isNotEmpty) 'prem_id': premIds,
      if (ordeTypes.isNotEmpty) 'orde_type': ordeTypes,
      if (prodIds.isNotEmpty) 'prod_id': prodIds,
      if (prodcIds.isNotEmpty) 'prodc_id': prodcIds,
      if (prodsIds.isNotEmpty) 'prods_id': prodsIds,
      if (prodoIds.isNotEmpty) 'prodo_id': prodoIds,
      if (emplIds.isNotEmpty) 'empl_id': emplIds,
      'date_start': dateStart,
      'date_end': dateEnd,
    };
    if (allRecords) {
      query['all_records'] = 'true';
    } else {
      query['page'] = page;
    }
    final res = await _dio.get('reports/product-export', queryParameters: query);
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      final rows = (data['result'] as List)
          .map((e) => ProductCsvRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final pag = data['pagination'];
      return PagedRows(
        rows: rows,
        pagination: pag is Map ? ReportPagination.fromJson(Map<String, dynamic>.from(pag)) : null,
      );
    }
    return const PagedRows(rows: [], pagination: null);
  }

  /// GET `reports/product-category` — the "Reporte de categorías" data.
  /// Same premise/order-type/date filters as [getProduct], plus the
  /// category-specific `prodc_id` filter (no producto/tamaño/opción — those
  /// don't apply to a category-level rollup).
  Future<CategoryReportData> getProductCategory({
    required List<int> premIds,
    required List<String> ordeTypes,
    required List<int> prodcIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
  }) async {
    final res = await _dio.get('reports/product-category', queryParameters: {
      if (premIds.isNotEmpty) 'prem_id': premIds,
      if (ordeTypes.isNotEmpty) 'orde_type': ordeTypes,
      if (prodcIds.isNotEmpty) 'prodc_id': prodcIds,
      if (emplIds.isNotEmpty) 'empl_id': emplIds,
      'date_start': dateStart,
      'date_end': dateEnd,
    });
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      return CategoryReportData.fromJson(Map<String, dynamic>.from(data['result'] as Map));
    }
    return CategoryReportData.empty;
  }

  /// GET `reports/product-category-export` — the per-category rows behind
  /// both the categories report's detail table and its "Exportar CSV"
  /// button. Same filters as [getProductCategory], and the same
  /// [allRecords]/[page] pagination contract as [getProductCsv].
  Future<PagedRows<CategoryCsvRow>> getProductCategoryCsv({
    required List<int> premIds,
    required List<String> ordeTypes,
    required List<int> prodcIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
    bool allRecords = false,
    int page = 1,
  }) async {
    final query = <String, dynamic>{
      if (premIds.isNotEmpty) 'prem_id': premIds,
      if (ordeTypes.isNotEmpty) 'orde_type': ordeTypes,
      if (prodcIds.isNotEmpty) 'prodc_id': prodcIds,
      if (emplIds.isNotEmpty) 'empl_id': emplIds,
      'date_start': dateStart,
      'date_end': dateEnd,
    };
    if (allRecords) {
      query['all_records'] = 'true';
    } else {
      query['page'] = page;
    }
    final res =
        await _dio.get('reports/product-category-export', queryParameters: query);
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      final rows = (data['result'] as List)
          .map((e) => CategoryCsvRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final pag = data['pagination'];
      return PagedRows(
        rows: rows,
        pagination: pag is Map ? ReportPagination.fromJson(Map<String, dynamic>.from(pag)) : null,
      );
    }
    return const PagedRows(rows: [], pagination: null);
  }

  /// GET `reports/parameter/employee/<userId>` — the "Empleado" filter
  /// options for the resumen de turno report.
  Future<List<EmployeeOption>> getEmployeeParam(int userId) async {
    final res = await _dio.get('reports/parameter/employee/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => EmployeeOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// GET `orders/employee-summary` — the "Resumen de turno" data. Backend
  /// groups the raw rows server-side (`groupEmployeeSummary`) by `prem_name`
  /// + `empl_name` + `dateserver_created` before responding, so `result` is
  /// already one entry per group with a `payments` breakdown rather than one
  /// row per payment method. Unlike every other report, this endpoint IS the
  /// report: there's no separate KPI/chart-shaped endpoint, and the response
  /// is never paginated (no `all_records`/`page` params, no `pagination`
  /// block — always the full matching row set). `date_start`/`date_end` are
  /// the only non-optional filters (formatted `yyyy-MM-dd`), mirroring the
  /// other report endpoints' omit-when-empty rule for the rest. This same
  /// endpoint also takes a `print` query param (used by the POS printer
  /// flow, not this admin UI) that additionally emits a `printEmployeeSummary`
  /// socket event from the same query result — irrelevant here since this
  /// call never sets it.
  Future<List<EmployeeSummaryRow>> getEmployeeSummary({
    required List<int> premIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
  }) async {
    final res = await _dio.get('orders/employee-summary', queryParameters: {
      if (premIds.isNotEmpty) 'prem_id': premIds,
      if (emplIds.isNotEmpty) 'empl_id': emplIds,
      'date_start': dateStart,
      'date_end': dateEnd,
    });
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => EmployeeSummaryRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _reportFilterQuery({
    required List<int> premIds,
    required int? ordeId,
    required List<String> ordeStates,
    required List<String> ordeTypes,
    required List<int> paymIds,
    required List<int> reasIds,
    required List<int> emplIds,
    required String dateStart,
    required String dateEnd,
  }) {
    return {
      if (premIds.isNotEmpty) 'prem_id': premIds,
      'orde_id': ?ordeId,
      if (ordeStates.isNotEmpty) 'orde_state': ordeStates,
      if (ordeTypes.isNotEmpty) 'orde_type': ordeTypes,
      if (paymIds.isNotEmpty) 'paym_id': paymIds,
      if (reasIds.isNotEmpty) 'reas_id': reasIds,
      if (emplIds.isNotEmpty) 'empl_id': emplIds,
      'date_start': dateStart,
      'date_end': dateEnd,
    };
  }
}
