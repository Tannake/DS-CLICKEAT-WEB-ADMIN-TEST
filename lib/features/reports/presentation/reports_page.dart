import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/utils/web_download.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/category_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/daily_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/orders_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/product_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/sales_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/category_csv.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/orders_csv.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/product_csv.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/reports_repository.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/sales_csv.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/category_report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/daily_report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/orders_report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/product_report_view.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/report_pdf.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/sales_report_view.dart';

export 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart'
    show ReportType;

/// One of the report screens under the "Reportes" menu section. All of them
/// are wired to live data.
class ReportsPage extends ConsumerStatefulWidget {
  final ReportType type;
  const ReportsPage({super.key, required this.type});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  @override
  void initState() {
    super.initState();
    if (widget.type == ReportType.dashboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(dailyReportControllerProvider.notifier).loadParameters();
      });
    }
    if (widget.type == ReportType.ventas) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(salesReportControllerProvider.notifier).loadParameters();
      });
    }
    if (widget.type == ReportType.pedidos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(ordersReportControllerProvider.notifier).loadParameters();
      });
    }
    if (widget.type == ReportType.productos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(productReportControllerProvider.notifier).loadParameters();
      });
    }
    if (widget.type == ReportType.categorias) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(categoryReportControllerProvider.notifier).loadParameters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case ReportType.dashboard:
        return _buildDashboard(context);
      case ReportType.ventas:
        return _buildVentas(context);
      case ReportType.pedidos:
        return _buildPedidos(context);
      case ReportType.productos:
        return _buildProductos(context);
      case ReportType.categorias:
        return _buildCategorias(context);
    }
  }

  Widget _buildDashboard(BuildContext context) {
    final state = ref.watch(dailyReportControllerProvider);
    final initialLoad = state.loadingParams ||
        (state.hasQueried && state.data == null && state.loadingData);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(
            title: 'Dashboard diario',
            subtitle: 'Así va el negocio hoy',
            onExportPdf: () => _exportDailyReportPdf(),
          ),
          const SizedBox(height: 13),
          _DashboardFiltersRow(state: state),
          const SizedBox(height: 13),
          Expanded(child: _buildDashboardBody(state, initialLoad)),
        ],
      ),
    );
  }

  Future<void> _exportDailyReportPdf() async {
    final state = ref.read(dailyReportControllerProvider);
    if (state.data == null) {
      throw Exception('Primero consulta el reporte.');
    }
    final view = buildDailyReportView(state);
    final bytes = await buildReportPdfBytes(view);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadBytesFile(
      'dashboard-diario-$stamp.pdf',
      bytes,
      mimeType: 'application/pdf',
    );
  }

  Widget _buildDashboardBody(DailyReportState state, bool initialLoad) {
    return _buildLiveReportBody(
      initialLoad: initialLoad,
      hasQueried: state.hasQueried,
      error: state.error,
      hasData: state.data != null,
      loadingData: state.loadingData,
      buildView: () => buildDailyReportView(state),
    );
  }

  // ===========================================================================
  // Reporte de ventas (live)
  // ===========================================================================

  Widget _buildVentas(BuildContext context) {
    final state = ref.watch(salesReportControllerProvider);
    final initialLoad = state.loadingParams ||
        (state.hasQueried && state.data == null && state.loadingData);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(
            title: 'Reporte de ventas',
            subtitle: 'Ventas del periodo seleccionado',
            onExportCsv: () => _exportSalesCsv(),
            onExportPdf: () => _exportSalesReportPdf(),
          ),
          const SizedBox(height: 13),
          _SalesFiltersRow(state: state),
          const SizedBox(height: 13),
          Expanded(child: _buildVentasBody(state, initialLoad)),
        ],
      ),
    );
  }

  /// `reports/sales-export` is a separate endpoint from `reports/sales` (a flat
  /// per-order dump rather than the KPI/chart-shaped payload), so this
  /// fetches fresh with the currently-applied filters instead of reusing
  /// `state.data`. Passes `allRecords: true` — unlike the on-screen detail
  /// table (which pages 100 rows at a time), the export must contain every
  /// matching row in one shot.
  Future<void> _exportSalesCsv() async {
    final state = ref.read(salesReportControllerProvider);
    if (!state.hasQueried) {
      throw Exception('Primero consulta el reporte.');
    }
    final result = await ref.read(reportsRepositoryProvider).getSalesCsv(
          premIds: state.selectedPremIds.toList(),
          ordeId: int.tryParse(state.orderIdText.trim()),
          ordeStates: state.selectedOrderStates.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          paymIds: state.selectedPaymIds.toList(),
          reasIds: state.selectedReasIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
          allRecords: true,
        );
    final csv = salesToCsv(result.rows);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadTextFile('reporte-ventas-$stamp.csv', csv);
  }

  /// Unlike the CSV export, the PDF only mirrors the on-screen KPI cards and
  /// charts — the detail table is dropped (empty `headers`/`rows`) rather
  /// than reused, since a multi-hundred-row dump isn't a good fit for a
  /// printed page; that's what CSV export is for.
  Future<void> _exportSalesReportPdf() async {
    final state = ref.read(salesReportControllerProvider);
    if (state.data == null) {
      throw Exception('Primero consulta el reporte.');
    }
    final view = buildSalesReportView(state).copyWith(headers: const [], rows: const []);
    final bytes = await buildReportPdfBytes(view);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadBytesFile('reporte-ventas-$stamp.pdf', bytes, mimeType: 'application/pdf');
  }

  static String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Widget _buildVentasBody(SalesReportState state, bool initialLoad) {
    return _buildLiveReportBody(
      initialLoad: initialLoad,
      hasQueried: state.hasQueried,
      error: state.error,
      hasData: state.data != null,
      loadingData: state.loadingData,
      buildView: () => buildSalesReportView(state),
      tablePage: state.tablePage,
      tableTotalPages: state.tableTotalPages,
      loadingTable: state.loadingTable,
      onTablePageChange: (page) =>
          ref.read(salesReportControllerProvider.notifier).goToTablePage(page),
    );
  }

  // ===========================================================================
  // Reporte de pedidos (live) — same design as Ventas (charts, order, sizing,
  // colors, detail table, CSV/PDF export).
  // ===========================================================================

  Widget _buildPedidos(BuildContext context) {
    final state = ref.watch(ordersReportControllerProvider);
    final initialLoad = state.loadingParams ||
        (state.hasQueried && state.data == null && state.loadingData);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(
            title: 'Reporte de pedidos',
            subtitle: 'Pedidos del periodo seleccionado',
            onExportCsv: () => _exportOrdersCsv(),
            onExportPdf: () => _exportOrdersReportPdf(),
          ),
          const SizedBox(height: 13),
          _OrdersFiltersRow(state: state),
          const SizedBox(height: 13),
          Expanded(child: _buildPedidosBody(state, initialLoad)),
        ],
      ),
    );
  }

  Widget _buildPedidosBody(OrdersReportState state, bool initialLoad) {
    return _buildLiveReportBody(
      initialLoad: initialLoad,
      hasQueried: state.hasQueried,
      error: state.error,
      hasData: state.data != null,
      loadingData: state.loadingData,
      buildView: () => buildOrdersReportView(state),
      tablePage: state.tablePage,
      tableTotalPages: state.tableTotalPages,
      loadingTable: state.loadingTable,
      onTablePageChange: (page) =>
          ref.read(ordersReportControllerProvider.notifier).goToTablePage(page),
    );
  }

  /// `reports/orders-export` is a separate endpoint from `reports/orders` (a
  /// flat per-line-item dump rather than the KPI/chart-shaped payload), so
  /// this fetches fresh with the currently-applied filters instead of
  /// reusing `state.orderRows` — mirrors [_exportSalesCsv], including
  /// `allRecords: true` so the export isn't limited to one page.
  Future<void> _exportOrdersCsv() async {
    final state = ref.read(ordersReportControllerProvider);
    if (!state.hasQueried) {
      throw Exception('Primero consulta el reporte.');
    }
    final result = await ref.read(reportsRepositoryProvider).getOrdersCsv(
          premIds: state.selectedPremIds.toList(),
          ordeId: int.tryParse(state.orderIdText.trim()),
          ordeStates: state.selectedOrderStates.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          paymIds: state.selectedPaymIds.toList(),
          reasIds: state.selectedReasIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
          allRecords: true,
        );
    final csv = ordersToCsv(result.rows);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadTextFile('reporte-pedidos-$stamp.csv', csv);
  }

  /// Mirrors [_exportSalesReportPdf] — only the KPI cards and charts, no
  /// detail table (empty `headers`/`rows`).
  Future<void> _exportOrdersReportPdf() async {
    final state = ref.read(ordersReportControllerProvider);
    if (state.data == null) {
      throw Exception('Primero consulta el reporte.');
    }
    final view = buildOrdersReportView(state).copyWith(headers: const [], rows: const []);
    final bytes = await buildReportPdfBytes(view);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadBytesFile('reporte-pedidos-$stamp.pdf', bytes, mimeType: 'application/pdf');
  }

  // ===========================================================================
  // Reporte de productos (live) — same design as Ventas/Pedidos (charts,
  // order, sizing, colors, detail table, CSV/PDF export).
  // ===========================================================================

  Widget _buildProductos(BuildContext context) {
    final state = ref.watch(productReportControllerProvider);
    final initialLoad = state.loadingParams ||
        (state.hasQueried && state.data == null && state.loadingData);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(
            title: 'Reporte de productos',
            subtitle: 'Productos del periodo seleccionado',
            onExportCsv: () => _exportProductCsv(),
            onExportPdf: () => _exportProductReportPdf(),
          ),
          const SizedBox(height: 13),
          _ProductFiltersRow(state: state),
          const SizedBox(height: 13),
          Expanded(child: _buildProductosBody(state, initialLoad)),
        ],
      ),
    );
  }

  Widget _buildProductosBody(ProductReportState state, bool initialLoad) {
    return _buildLiveReportBody(
      initialLoad: initialLoad,
      hasQueried: state.hasQueried,
      error: state.error,
      hasData: state.data != null,
      loadingData: state.loadingData,
      buildView: () => buildProductReportView(state),
      tablePage: state.tablePage,
      tableTotalPages: state.tableTotalPages,
      loadingTable: state.loadingTable,
      onTablePageChange: (page) =>
          ref.read(productReportControllerProvider.notifier).goToTablePage(page),
    );
  }

  /// `reports/product-export` is a separate endpoint from `reports/product` (a
  /// flat per-line-item dump rather than the KPI/chart-shaped payload), so
  /// this fetches fresh with the currently-applied filters instead of
  /// reusing `state.productRows` — mirrors [_exportOrdersCsv], including
  /// `allRecords: true` so the export isn't limited to one page.
  Future<void> _exportProductCsv() async {
    final state = ref.read(productReportControllerProvider);
    if (!state.hasQueried) {
      throw Exception('Primero consulta el reporte.');
    }
    final result = await ref.read(reportsRepositoryProvider).getProductCsv(
          premIds: state.selectedPremIds.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          prodIds: state.selectedProdIds.toList(),
          prodcIds: state.selectedProdcIds.toList(),
          prodsIds: state.selectedProdsIds.toList(),
          prodoIds: state.selectedProdoIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
          allRecords: true,
        );
    final csv = productsToCsv(result.rows);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadTextFile('reporte-productos-$stamp.csv', csv);
  }

  /// Mirrors [_exportSalesReportPdf]/[_exportOrdersReportPdf] — only the KPI
  /// cards and charts, no detail table (stripped the same way, even though
  /// [buildProductReportView] now also sets `headers`/`rows`).
  Future<void> _exportProductReportPdf() async {
    final state = ref.read(productReportControllerProvider);
    if (state.data == null) {
      throw Exception('Primero consulta el reporte.');
    }
    final view = buildProductReportView(state).copyWith(headers: const [], rows: const []);
    final bytes = await buildReportPdfBytes(view);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadBytesFile('reporte-productos-$stamp.pdf', bytes, mimeType: 'application/pdf');
  }

  // ===========================================================================
  // Reporte de categorías (live) — same design as Productos, one rollup
  // level up (category instead of product): charts, order, sizing, colors,
  // detail table, CSV/PDF export.
  // ===========================================================================

  Widget _buildCategorias(BuildContext context) {
    final state = ref.watch(categoryReportControllerProvider);
    final initialLoad = state.loadingParams ||
        (state.hasQueried && state.data == null && state.loadingData);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(
            title: 'Reporte de categorías',
            subtitle: 'Categorías del periodo seleccionado',
            onExportCsv: () => _exportCategoryCsv(),
            onExportPdf: () => _exportCategoryReportPdf(),
          ),
          const SizedBox(height: 13),
          _CategoryFiltersRow(state: state),
          const SizedBox(height: 13),
          Expanded(child: _buildCategoriasBody(state, initialLoad)),
        ],
      ),
    );
  }

  Widget _buildCategoriasBody(CategoryReportState state, bool initialLoad) {
    return _buildLiveReportBody(
      initialLoad: initialLoad,
      hasQueried: state.hasQueried,
      error: state.error,
      hasData: state.data != null,
      loadingData: state.loadingData,
      buildView: () => buildCategoryReportView(state),
      tablePage: state.tablePage,
      tableTotalPages: state.tableTotalPages,
      loadingTable: state.loadingTable,
      onTablePageChange: (page) =>
          ref.read(categoryReportControllerProvider.notifier).goToTablePage(page),
    );
  }

  /// `reports/product-category-export` is a separate endpoint from
  /// `reports/product-category` (a flat per-category dump rather than the
  /// KPI/chart-shaped payload), so this fetches fresh with the
  /// currently-applied filters instead of reusing `state.categoryRows` —
  /// mirrors [_exportProductCsv], including `allRecords: true` so the
  /// export isn't limited to one page.
  Future<void> _exportCategoryCsv() async {
    final state = ref.read(categoryReportControllerProvider);
    if (!state.hasQueried) {
      throw Exception('Primero consulta el reporte.');
    }
    final result = await ref.read(reportsRepositoryProvider).getProductCategoryCsv(
          premIds: state.selectedPremIds.toList(),
          ordeTypes: state.selectedOrderTypes.toList(),
          prodcIds: state.selectedProdcIds.toList(),
          dateStart: _fmtDate(state.dateStart),
          dateEnd: _fmtDate(state.dateEnd),
          allRecords: true,
        );
    final csv = categoriesToCsv(result.rows);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadTextFile('reporte-categorias-$stamp.csv', csv);
  }

  /// Mirrors [_exportProductReportPdf] — only the KPI cards and charts, no
  /// detail table.
  Future<void> _exportCategoryReportPdf() async {
    final state = ref.read(categoryReportControllerProvider);
    if (state.data == null) {
      throw Exception('Primero consulta el reporte.');
    }
    final view = buildCategoryReportView(state).copyWith(headers: const [], rows: const []);
    final bytes = await buildReportPdfBytes(view);
    final today = DateTime.now();
    final stamp =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    downloadBytesFile('reporte-categorias-$stamp.pdf', bytes, mimeType: 'application/pdf');
  }

  // ===========================================================================
  // Shared body for any live (non-mock) report: same loading/empty/error
  // states, KPI grid, chart grid, optional buckets row and optional table.
  // ===========================================================================

  Widget _buildLiveReportBody({
    required bool initialLoad,
    required bool hasQueried,
    required String? error,
    required bool hasData,
    required bool loadingData,
    required ReportView Function() buildView,
    int tablePage = 1,
    int tableTotalPages = 0,
    bool loadingTable = false,
    ValueChanged<int>? onTablePageChange,
  }) {
    if (initialLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!hasQueried) {
      return const Center(
        child: Text(
          'Selecciona los filtros y presiona "Consultar" para ver el reporte.',
          style: TextStyle(color: AppColors.ink3, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (error != null && !hasData) {
      return Center(
        child: Text(
          error,
          style: const TextStyle(color: AppColors.red, fontSize: 14),
        ),
      );
    }

    final view = buildView();
    final kpiGrid = _KpiGrid(view.kpis);
    final chartsGrid = _ChartsGrid(view.charts);

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              kpiGrid,
              const SizedBox(height: 13),
              chartsGrid,
              if (view.buckets.isNotEmpty || view.bucketsSideChart != null) ...[
                const SizedBox(height: 12),
                _BucketsRow(buckets: view.buckets, sideChart: view.bucketsSideChart),
              ],
              if (view.headers.isNotEmpty) ...[
                const SizedBox(height: 13),
                _ReportTable(
                  title: view.tableTitle,
                  count: view.tableCount,
                  headers: view.headers,
                  rows: view.rows,
                  page: tablePage,
                  totalPages: tableTotalPages,
                  loadingPage: loadingTable,
                  onPageChange: onTablePageChange,
                ),
              ],
            ],
          ),
        ),
        if (loadingData)
          const Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// Header: title/subtitle, export buttons
// ===========================================================================

class _ReportHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  /// When set, renders an "Exportar PDF" button that runs this — wired for
  /// the daily dashboard and (alongside [onExportCsv]) the sales report.
  final Future<void> Function()? onExportPdf;
  /// When set, renders an "Exportar CSV" button that runs this — currently
  /// wired for the sales and orders reports. Independent of [onExportPdf]:
  /// a report can show one, both, or (if neither is set, matching the
  /// still-mock report screens) a single generic "coming soon" PDF button.
  final Future<void> Function()? onExportCsv;

  const _ReportHeader({
    required this.title,
    required this.subtitle,
    this.onExportPdf,
    this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    final hasHandler = onExportCsv != null || onExportPdf != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink3),
              ),
            ],
          ),
        ),
        if (!hasHandler)
          const _ExportButton(kind: 'PDF', onExport: null)
        else ...[
          if (onExportCsv != null) _ExportButton(kind: 'CSV', onExport: onExportCsv),
          if (onExportCsv != null && onExportPdf != null) const SizedBox(width: 8),
          if (onExportPdf != null) _ExportButton(kind: 'PDF', onExport: onExportPdf),
        ],
      ],
    );
  }
}

/// A single "Exportar CSV"/"Exportar PDF" button with its own loading state
/// — [_ReportHeader] renders one of these per export kind it's given, so
/// each tracks its export independently of the other.
class _ExportButton extends StatefulWidget {
  final String kind;
  final Future<void> Function()? onExport;
  const _ExportButton({required this.kind, required this.onExport});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _exporting = false;

  Future<void> _handleExport() async {
    final handler = widget.onExport;
    if (handler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exportar ${widget.kind} estará disponible próximamente.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      await handler();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo generar el ${widget.kind}: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _exporting ? null : _handleExport,
      icon: _exporting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.file_download_outlined, size: 16),
      label: Text('Exportar ${widget.kind}'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ===========================================================================
// Dashboard diario filters: multi-select negocios + tipo de pedido
// ===========================================================================

class _DashboardFiltersRow extends ConsumerWidget {
  final DailyReportState state;
  const _DashboardFiltersRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyReportControllerProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MultiSelectFilterChip<int>(
          label: 'Sucursal',
          items: state.premises.map((p) => p.premId).toList(),
          labelOf: (id) => state.premises
              .firstWhere((p) => p.premId == id)
              .premName,
          selected: state.selectedPremIds,
          onApply: notifier.applyPremises,
        ),
        _MultiSelectFilterChip<String>(
          label: 'Tipo de pedido',
          items: state.orderTypes.map((o) => o.ordeType).toList(),
          labelOf: (code) => state.orderTypes
              .firstWhere((o) => o.ordeType == code)
              .ordeName,
          selected: state.selectedOrderTypes,
          onApply: notifier.applyOrderTypes,
        ),
        _ConsultarButton(
          loading: state.loadingData,
          onPressed: state.premises.isEmpty ? null : notifier.search,
        ),
      ],
    );
  }
}

// ===========================================================================
// Reporte de ventas filters: date range + 5 multi-selects + order-id search
// ===========================================================================

class _SalesFiltersRow extends ConsumerWidget {
  final SalesReportState state;
  const _SalesFiltersRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(salesReportControllerProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DateRangeFilterChip(
          start: state.dateStart,
          end: state.dateEnd,
          onApply: notifier.applyDateRange,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Sucursal',
          items: state.premises.map((p) => p.premId).toList(),
          labelOf: (id) =>
              state.premises.firstWhere((p) => p.premId == id).premName,
          selected: state.selectedPremIds,
          onApply: notifier.applyPremises,
        ),
        _MultiSelectFilterChip<String>(
          label: 'Tipo de pedido',
          items: state.orderTypes.map((o) => o.ordeType).toList(),
          labelOf: (code) =>
              state.orderTypes.firstWhere((o) => o.ordeType == code).ordeName,
          selected: state.selectedOrderTypes,
          onApply: notifier.applyOrderTypes,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Método de pago',
          items: state.payments.map((p) => p.paymId).toList(),
          labelOf: (id) =>
              state.payments.firstWhere((p) => p.paymId == id).paymName,
          selected: state.selectedPaymIds,
          onApply: notifier.applyPaymIds,
        ),
        _MultiSelectFilterChip<String>(
          label: 'Estado',
          items: state.orderStates.map((o) => o.ordeState).toList(),
          labelOf: (code) =>
              state.orderStates.firstWhere((o) => o.ordeState == code).stateName,
          selected: state.selectedOrderStates,
          onApply: notifier.applyOrderStates,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Razón de cancelación',
          items: state.reasons.map((r) => r.reasId).toList(),
          labelOf: (id) =>
              state.reasons.firstWhere((r) => r.reasId == id).reasName,
          selected: state.selectedReasIds,
          onApply: notifier.applyReasIds,
        ),
        _OrderIdSearchBox(
          initialText: state.orderIdText,
          onChanged: notifier.applyOrderIdText,
        ),
        _ConsultarButton(
          loading: state.loadingData,
          onPressed: state.premises.isEmpty
              ? null
              : () {
                  if (state.selectedPremIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona al menos una sucursal para consultar.'),
                      ),
                    );
                    return;
                  }
                  notifier.search();
                },
        ),
      ],
    );
  }
}

// ===========================================================================
// Reporte de pedidos filters — identical shape/logic to _SalesFiltersRow
// (same eight params, same rules), just wired to the orders controller.
// ===========================================================================

class _OrdersFiltersRow extends ConsumerWidget {
  final OrdersReportState state;
  const _OrdersFiltersRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ordersReportControllerProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DateRangeFilterChip(
          start: state.dateStart,
          end: state.dateEnd,
          onApply: notifier.applyDateRange,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Sucursal',
          items: state.premises.map((p) => p.premId).toList(),
          labelOf: (id) =>
              state.premises.firstWhere((p) => p.premId == id).premName,
          selected: state.selectedPremIds,
          onApply: notifier.applyPremises,
        ),
        _MultiSelectFilterChip<String>(
          label: 'Tipo de pedido',
          items: state.orderTypes.map((o) => o.ordeType).toList(),
          labelOf: (code) =>
              state.orderTypes.firstWhere((o) => o.ordeType == code).ordeName,
          selected: state.selectedOrderTypes,
          onApply: notifier.applyOrderTypes,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Método de pago',
          items: state.payments.map((p) => p.paymId).toList(),
          labelOf: (id) =>
              state.payments.firstWhere((p) => p.paymId == id).paymName,
          selected: state.selectedPaymIds,
          onApply: notifier.applyPaymIds,
        ),
        _MultiSelectFilterChip<String>(
          label: 'Estado',
          items: state.orderStates.map((o) => o.ordeState).toList(),
          labelOf: (code) =>
              state.orderStates.firstWhere((o) => o.ordeState == code).stateName,
          selected: state.selectedOrderStates,
          onApply: notifier.applyOrderStates,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Razón de cancelación',
          items: state.reasons.map((r) => r.reasId).toList(),
          labelOf: (id) =>
              state.reasons.firstWhere((r) => r.reasId == id).reasName,
          selected: state.selectedReasIds,
          onApply: notifier.applyReasIds,
        ),
        _OrderIdSearchBox(
          initialText: state.orderIdText,
          onChanged: notifier.applyOrderIdText,
        ),
        _ConsultarButton(
          loading: state.loadingData,
          onPressed: state.premises.isEmpty
              ? null
              : () {
                  if (state.selectedPremIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona al menos una sucursal para consultar.'),
                      ),
                    );
                    return;
                  }
                  notifier.search();
                },
        ),
      ],
    );
  }
}

// ===========================================================================
// Reporte de productos filters: date range + sucursal + tipo de pedido +
// producto/categoría/tamaño/opción multi-selects (no método de
// pago/estado/razón de cancelación/order-id — there's no parameter endpoint
// for those on this report).
// ===========================================================================

class _ProductFiltersRow extends ConsumerWidget {
  final ProductReportState state;
  const _ProductFiltersRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(productReportControllerProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DateRangeFilterChip(
          start: state.dateStart,
          end: state.dateEnd,
          onApply: notifier.applyDateRange,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Sucursal',
          items: state.premises.map((p) => p.premId).toList(),
          labelOf: (id) =>
              state.premises.firstWhere((p) => p.premId == id).premName,
          selected: state.selectedPremIds,
          onApply: notifier.applyPremises,
        ),
        _MultiSelectFilterChip<String>(
          label: 'Tipo de pedido',
          items: state.orderTypes.map((o) => o.ordeType).toList(),
          labelOf: (code) =>
              state.orderTypes.firstWhere((o) => o.ordeType == code).ordeName,
          selected: state.selectedOrderTypes,
          onApply: notifier.applyOrderTypes,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Producto',
          items: state.products.map((p) => p.prodId).toList(),
          labelOf: (id) =>
              state.products.firstWhere((p) => p.prodId == id).prodName,
          selected: state.selectedProdIds,
          onApply: notifier.applyProdIds,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Categoría',
          items: state.categories.map((c) => c.prodcId).toList(),
          labelOf: (id) =>
              state.categories.firstWhere((c) => c.prodcId == id).prodcName,
          selected: state.selectedProdcIds,
          onApply: notifier.applyProdcIds,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Tamaño',
          items: state.sizes.map((s) => s.prodsId).toList(),
          labelOf: (id) =>
              state.sizes.firstWhere((s) => s.prodsId == id).prodsName,
          selected: state.selectedProdsIds,
          onApply: notifier.applyProdsIds,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Opción',
          items: state.options.map((o) => o.prodoId).toList(),
          labelOf: (id) =>
              state.options.firstWhere((o) => o.prodoId == id).prodoName,
          selected: state.selectedProdoIds,
          onApply: notifier.applyProdoIds,
        ),
        _ConsultarButton(
          loading: state.loadingData,
          onPressed: state.premises.isEmpty
              ? null
              : () {
                  if (state.selectedPremIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona al menos una sucursal para consultar.'),
                      ),
                    );
                    return;
                  }
                  notifier.search();
                },
        ),
      ],
    );
  }
}

// ===========================================================================
// Reporte de categorías filters: date range + sucursal + tipo de pedido +
// categoría multi-select (no producto/tamaño/opción — those don't apply to
// a category-level rollup).
// ===========================================================================

class _CategoryFiltersRow extends ConsumerWidget {
  final CategoryReportState state;
  const _CategoryFiltersRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(categoryReportControllerProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DateRangeFilterChip(
          start: state.dateStart,
          end: state.dateEnd,
          onApply: notifier.applyDateRange,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Sucursal',
          items: state.premises.map((p) => p.premId).toList(),
          labelOf: (id) =>
              state.premises.firstWhere((p) => p.premId == id).premName,
          selected: state.selectedPremIds,
          onApply: notifier.applyPremises,
        ),
        _MultiSelectFilterChip<String>(
          label: 'Tipo de pedido',
          items: state.orderTypes.map((o) => o.ordeType).toList(),
          labelOf: (code) =>
              state.orderTypes.firstWhere((o) => o.ordeType == code).ordeName,
          selected: state.selectedOrderTypes,
          onApply: notifier.applyOrderTypes,
        ),
        _MultiSelectFilterChip<int>(
          label: 'Categoría',
          items: state.categories.map((c) => c.prodcId).toList(),
          labelOf: (id) =>
              state.categories.firstWhere((c) => c.prodcId == id).prodcName,
          selected: state.selectedProdcIds,
          onApply: notifier.applyProdcIds,
        ),
        _ConsultarButton(
          loading: state.loadingData,
          onPressed: state.premises.isEmpty
              ? null
              : () {
                  if (state.selectedPremIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona al menos una sucursal para consultar.'),
                      ),
                    );
                    return;
                  }
                  notifier.search();
                },
        ),
      ],
    );
  }
}

/// The "Fechas" filter chip — opens the platform date-range picker and
/// stages the selection immediately (there's no separate "Aplicar" step
/// like the checklist popups, since confirming the native dialog already
/// is the confirmation). Still only takes effect once "Consultar" runs.
const _monthAbbrevs = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
String _shortDateLabel(DateTime d) => '${d.day} ${_monthAbbrevs[d.month - 1]}';

/// The "Fechas" filter chip — a compact dropdown-sized popup (mirroring
/// [_MultiSelectFilterChip]'s checklist popup) rather than the platform's
/// `showDateRangePicker`, which renders as a near-fullscreen dialog on
/// web/desktop and dwarfed every other control in the filters row.
class _DateRangeFilterChip extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final void Function(DateTime start, DateTime end) onApply;

  const _DateRangeFilterChip({
    required this.start,
    required this.end,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      offset: const Offset(0, 6),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 250),
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _DateRangePopupBody(
            initialStart: start,
            initialEnd: end,
            onApply: (s, e) {
              Navigator.pop(context);
              onApply(s, e);
            },
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fechas', style: TextStyle(fontSize: 11, color: AppColors.ink3)),
            const SizedBox(width: 6),
            Text(
              '${_shortDateLabel(start)} – ${_shortDateLabel(end)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 13, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _DateRangePopupBody extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final void Function(DateTime start, DateTime end) onApply;

  const _DateRangePopupBody({
    required this.initialStart,
    required this.initialEnd,
    required this.onApply,
  });

  @override
  State<_DateRangePopupBody> createState() => _DateRangePopupBodyState();
}

/// `showDatePicker`'s default Material 3 dialog derives its secondary/
/// tertiary accents from the ambient `ColorScheme`, which — even though the
/// app seeds it from navy (see `buildTheme()` in `core/theme/app_theme.dart`)
/// — can still land on a lavender/purple tone for those derived colors.
/// Force every accent the dialog actually uses to navy/white explicitly so
/// no purple leaks through.
Widget _whiteDatePickerTheme(BuildContext context, Widget? child) {
  return Theme(
    data: Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: Colors.white,
        secondary: AppColors.navy,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.navy,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    ),
    child: child!,
  );
}

class _DateRangePopupBodyState extends State<_DateRangePopupBody> {
  late DateTime _start = widget.initialStart;
  late DateTime _end = widget.initialEnd;

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 2),
      lastDate: _end,
      builder: _whiteDatePickerTheme,
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: now,
      builder: _whiteDatePickerTheme,
    );
    if (picked != null) setState(() => _end = picked);
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.ink3)),
                  Text(
                    _shortDateLabel(value),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dateField('Desde', _start, _pickStart),
          const SizedBox(height: 8),
          _dateField('Hasta', _end, _pickEnd),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onApply(_start, _end),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Aplicar', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Buscar número de pedido" box — a staged filter like the other chips
/// (only takes effect on "Consultar"), so it just reports text changes
/// rather than filtering a local list like the mock screens' search field.
class _OrderIdSearchBox extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  const _OrderIdSearchBox({required this.initialText, required this.onChanged});

  @override
  State<_OrderIdSearchBox> createState() => _OrderIdSearchBoxState();
}

class _OrderIdSearchBoxState extends State<_OrderIdSearchBox> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 33,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar por número de pedido…',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.ink3),
          prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.ink3),
          prefixIconConstraints: const BoxConstraints(minWidth: 30),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.navy, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// The "Consultar" button that runs a report query on demand — reports never
/// auto-load, so the user always picks their filters and presses this first.
class _ConsultarButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  const _ConsultarButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.search, size: 16),
      label: const Text('Consultar'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A filter chip that opens a checklist popup for choosing zero or more of
/// [items]. Selection is staged locally in the popup and only applied (via
/// [onApply]) when the user taps "Aplicar", so a stray tap doesn't trigger a
/// network request per item.
class _MultiSelectFilterChip<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final String Function(T) labelOf;
  final Set<T> selected;
  final ValueChanged<Set<T>> onApply;

  const _MultiSelectFilterChip({
    required this.label,
    required this.items,
    required this.labelOf,
    required this.selected,
    required this.onApply,
  });

  String get _summary {
    if (items.isEmpty) return '…';
    if (selected.length == items.length) return 'Todos';
    if (selected.isEmpty) return 'Ninguno';
    if (selected.length == 1) return labelOf(selected.first);
    return '${selected.length} seleccionados';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      enabled: items.isNotEmpty,
      offset: const Offset(0, 6),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 280),
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _MultiSelectPopupBody<T>(
            items: items,
            labelOf: labelOf,
            initialSelected: selected,
            onApply: (result) {
              Navigator.pop(context);
              onApply(result);
            },
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
            const SizedBox(width: 6),
            Text(
              _summary,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 13, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectPopupBody<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelOf;
  final Set<T> initialSelected;
  final ValueChanged<Set<T>> onApply;

  const _MultiSelectPopupBody({
    required this.items,
    required this.labelOf,
    required this.initialSelected,
    required this.onApply,
  });

  @override
  State<_MultiSelectPopupBody<T>> createState() =>
      _MultiSelectPopupBodyState<T>();
}

class _MultiSelectPopupBodyState<T> extends State<_MultiSelectPopupBody<T>> {
  late Set<T> _local = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              TextButton(
                onPressed: () =>
                    setState(() => _local = widget.items.toSet()),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Todos', style: TextStyle(fontSize: 11.5)),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() => _local = {}),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Ninguno', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in widget.items)
                  InkWell(
                    onTap: () => setState(() {
                      if (_local.contains(item)) {
                        _local.remove(item);
                      } else {
                        _local.add(item);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _local.contains(item),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeColor: AppColors.navy,
                            onChanged: (_) => setState(() {
                              if (_local.contains(item)) {
                                _local.remove(item);
                              } else {
                                _local.add(item);
                              }
                            }),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.labelOf(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onApply(_local),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text('Aplicar', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// KPI grid
// ===========================================================================

class _KpiGrid extends StatelessWidget {
  final List<ReportKpi> kpis;
  const _KpiGrid(this.kpis);

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    const minCardWidth = 150.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Cap at kpis.length so cards span the full row on wide screens
        // (no trailing empty space) while still auto-reducing to fewer
        // columns — wrapping onto more rows — on narrow screens.
        final columns = math.min(
          math.max(1, kpis.length),
          math.max(1, ((width + gap) / (minCardWidth + gap)).floor()),
        );
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final k in kpis)
              SizedBox(
                width: k.span >= 2 ? cardWidth * 2 + gap : cardWidth,
                child: _KpiCard(
                  k,
                  cardWidth: k.span >= 2 ? cardWidth * 2 + gap : cardWidth,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final ReportKpi kpi;
  final double cardWidth;
  const _KpiCard(this.kpi, {required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    // Deltas ("▲ 12% vs ayer") render as a tinted pill; other sub-labels
    // ("14 días", "31 nuevos") stay as plain text, matching the design.
    final isDelta = kpi.sub.startsWith('▲') || kpi.sub.startsWith('▼');
    // Scale text down on narrow cards (e.g. 6 KPIs sharing a row at
    // ~1280px viewport width) so the label stays legible instead of a long
    // value ("Sáb 18 jul", a product name…) squeezing it down to a sliver —
    // combined with the flex split below, which guarantees the label a
    // minimum share of the row regardless of the value's length.
    final scale = (cardWidth / 190).clamp(0.62, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      // A left accent bar full-height of the card used to be done with
      // IntrinsicHeight + Row(crossAxisAlignment: stretch), but that runs a
      // separate intrinsic-height dry pass before the real layout pass; with
      // a 3-digit delta ("▼ 100% vs ayer", shown when today has 0 orders
      // against a non-empty previous day) the two passes disagreed by a
      // fraction of a pixel and threw a bottom-overflow. A Stack sizes off a
      // single non-positioned child instead, so there's only one
      // measurement of the content's height for the accent bar to match.
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18 * scale, 13, 14 * scale, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // flex: 3 guarantees the label a minimum share of the row
                // even when the value (flex: 2 below) is long — previously
                // the value took its full intrinsic width unconditionally,
                // which could squeeze the label down to a single letter.
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A fixed 2-line-tall box (not maxLines: 1) so a long
                      // label ("Día con mayor venta") wraps instead of
                      // truncating with an ellipsis, while every card still
                      // reserves the same height whether its own label
                      // wraps or not.
                      SizedBox(
                        height: 36 * scale,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            kpi.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w700, color: AppColors.ink3),
                          ),
                        ),
                      ),
                      // Always reserve the sub-line's height (even with
                      // empty text) — cards that have no `sub` (e.g. "Ticket
                      // promedio") used to skip this block entirely and end
                      // up visibly shorter than their siblings.
                      SizedBox(height: 7 * scale),
                      if (isDelta)
                        _Pill(text: kpi.sub, color: kpi.subColor)
                      else
                        Text(
                          kpi.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5 * scale, fontWeight: FontWeight.w700, color: kpi.subColor),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  flex: 2,
                  child: Text(
                    kpi.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: kpi.valueFontSize * scale,
                      fontWeight: FontWeight.w800,
                      color: kpi.valueColor ?? AppColors.ink,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 0, top: 0, bottom: 0, width: 4, child: Container(color: kpi.accent)),
        ],
      ),
    );
  }
}

/// A small rounded, tinted-background label — used for KPI deltas ("▲ 12%
/// vs ayer") and chart-card badges ("Alta rotación", "Atención").
class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ===========================================================================
// Charts grid: bin-packs charts into rows of 6 grid columns
// ===========================================================================

class _ChartsGrid extends StatelessWidget {
  final List<ReportChart> charts;
  const _ChartsGrid(this.charts);

  @override
  Widget build(BuildContext context) {
    final rows = <List<ReportChart>>[];
    var current = <ReportChart>[];
    var sum = 0;
    for (final c in charts) {
      if (sum + c.span > 6 && current.isNotEmpty) {
        rows.add(current);
        current = [];
        sum = 0;
      }
      current.add(c);
      sum += c.span;
    }
    if (current.isNotEmpty) rows.add(current);

    // A LayoutBuilder can't sit *inside* the IntrinsicHeight rows below (it
    // doesn't support intrinsic-dimension queries and throws), so the
    // available width is measured once here, at the top, and each card's
    // actual pixel width is precomputed and threaded down as a plain value
    // instead — needed so _DonutChartView knows whether its legend has room
    // beside the ring or must stack below it.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < rows[i].length; j++) ...[
                      Expanded(
                        flex: rows[i][j].span,
                        child: _ChartCard(
                          rows[i][j],
                          cardWidth: constraints.maxWidth.isFinite
                              ? (constraints.maxWidth - gap * (rows[i].length - 1)) *
                                  rows[i][j].span /
                                  rows[i].fold(0, (s, c) => s + c.span)
                              : null,
                        ),
                      ),
                      if (j != rows[i].length - 1) const SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
              if (i != rows.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  final ReportChart chart;
  /// The card's actual pixel width, precomputed by [_ChartsGrid] (or null
  /// when the caller — [_BucketsRow] — doesn't need it, since it never
  /// renders a [DonutChart]). Passed through to [_DonutChartView] so it can
  /// decide its layout without a LayoutBuilder of its own.
  final double? cardWidth;
  const _ChartCard(this.chart, {this.cardWidth});

  @override
  Widget build(BuildContext context) {
    final plc = chart is ProductListChart ? chart as ProductListChart : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chart.title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                    ),
                    if (plc?.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        plc!.subtitle!,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.ink3),
                      ),
                    ],
                  ],
                ),
              ),
              if (plc?.badgeText != null)
                _Pill(text: plc!.badgeText!, color: plc.badgeColor ?? AppColors.navy),
            ],
          ),
          const SizedBox(height: 10),
          Builder(builder: (context) {
            final c = chart;
            if (c is BarsChart) return _BarsChartView(c);
            if (c is LineChart) return _LineChartView(c);
            if (c is DonutChart) {
              // Card padding is 16px on each side (see the Container above).
              return _DonutChartView(c,
                  availableWidth: cardWidth != null ? cardWidth! - 32 : null);
            }
            if (c is HBarsChart) return _HBarsChartView(c);
            if (c is ProductListChart) return _ProductListChartView(c);
            if (c is StackChart) return _StackChartView(c);
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

// ===========================================================================
// Buckets row: venta mayor / venta menor / sin venta (68% combined, equal
// thirds) + órdenes por hora (32%) — a dedicated row outside the 6-column
// chart-grid bin-packing so the split can be an exact 68/32 rather than a
// span fraction of 6. Each chart's `span` is reused as its flex weight here
// (68/68/68/96 sums to 300, i.e. exactly 68% and 32%).
// ===========================================================================

class _BucketsRow extends StatelessWidget {
  final List<ProductListChart> buckets;
  final ReportChart? sideChart;
  const _BucketsRow({required this.buckets, required this.sideChart});

  @override
  Widget build(BuildContext context) {
    final children = <ReportChart>[...buckets, ?sideChart];
    if (children.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(flex: children[i].span, child: _ChartCard(children[i])),
            if (i != children.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared: horizontal scroll for wide charts (bars/line) — a plain
// SingleChildScrollView(scrollDirection: horizontal) only pans via
// click-drag; a vertical mouse wheel reports its motion as
// `scrollDelta.dy`, which a horizontal ScrollView ignores by default, so on
// desktop/web the extra items past the visible width were unreachable
// without knowing to click-drag. This translates a plain wheel scroll into
// horizontal movement and shows a draggable thumb so the extra content is
// discoverable.
// ===========================================================================

/// Reserved height below a horizontally-scrollable chart's content so
/// [_HorizontalWheelScroll]'s scrollbar thumb has empty space to sit in
/// instead of overlapping the bottom-most row (x-axis labels).
const _scrollbarGap = 14.0;

class _HorizontalWheelScroll extends StatefulWidget {
  final Widget child;
  const _HorizontalWheelScroll({required this.child});

  @override
  State<_HorizontalWheelScroll> createState() => _HorizontalWheelScrollState();
}

class _HorizontalWheelScrollState extends State<_HorizontalWheelScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;
    final target =
        (_controller.offset + delta).clamp(0.0, _controller.position.maxScrollExtent);
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        ),
      ),
    );
  }
}

// ===========================================================================
// Bars
// ===========================================================================

class _BarsChartView extends StatelessWidget {
  final BarsChart chart;
  const _BarsChartView(this.chart);

  Widget _bar(int i, double max, double? width) {
    final column = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (chart.valueLabels != null) ...[
          Text(
            chart.valueLabels![i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Container(
          height: max <= 0 ? 3 : math.max(3, chart.values[i] / max * 150),
          decoration: BoxDecoration(
            color: chart.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          chart.labels[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
    return width != null ? SizedBox(width: width, child: column) : Expanded(child: column);
  }

  @override
  Widget build(BuildContext context) {
    final max = chart.values.fold(0.0, (m, v) => v > m ? v : m);
    final height = chart.valueLabels != null ? 184.0 : 168.0;
    final minBarWidth = chart.minBarWidth;

    // Guards the scroll-content-width formula below from ever seeing an
    // empty list — `labels.length * w + (labels.length - 1) * spacing`
    // evaluates to a *negative* width when length is 0 (0 - spacing),
    // which throws "BoxConstraints has a negative minimum width" (e.g. a
    // filter combination, like Estado = Cancelado, that legitimately
    // returns zero days).
    if (chart.labels.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Sin datos', style: TextStyle(fontSize: 12, color: AppColors.ink3)),
        ),
      );
    }

    if (minBarWidth == null) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < chart.labels.length; i++) ...[
              _bar(i, max, null),
              if (i != chart.labels.length - 1) const SizedBox(width: 3),
            ],
          ],
        ),
      );
    }

    // A fixed min width per bar plus horizontal scroll keeps bars legible
    // once a date range returns many more of them than fit the card.
    // Deliberately not measured via LayoutBuilder: `_ChartsGrid` wraps each
    // row of chart cards in `IntrinsicHeight` to match their heights, and
    // `IntrinsicHeight` cannot compute an intrinsic height through a
    // `LayoutBuilder` descendant (it throws at layout time) — so the
    // content width here is sized purely from the item count instead of
    // the card's available width.
    final contentWidth = chart.labels.length * minBarWidth + (chart.labels.length - 1) * 3;
    return SizedBox(
      height: height + _scrollbarGap,
      child: _HorizontalWheelScroll(
        child: Padding(
          padding: const EdgeInsets.only(bottom: _scrollbarGap),
          child: SizedBox(
            width: contentWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < chart.labels.length; i++) ...[
                  _bar(i, max, minBarWidth),
                  if (i != chart.labels.length - 1) const SizedBox(width: 3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Stacked bars
// ===========================================================================

class _StackChartView extends StatelessWidget {
  final StackChart chart;
  const _StackChartView(this.chart);

  @override
  Widget build(BuildContext context) {
    final totals = [
      for (var i = 0; i < chart.labels.length; i++)
        chart.series.fold(0.0, (s, series) => s + series.data[i]),
    ];
    final max = totals.fold(0.0, (m, v) => v > m ? v : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 168,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < chart.labels.length; i++) ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final series in chart.series.reversed)
                              Container(
                                height: max <= 0 ? 1 : math.max(1, series.data[i] / max * 150),
                                color: series.color,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chart.labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                if (i != chart.labels.length - 1) const SizedBox(width: 3),
              ],
            ],
          ),
        ),
        if (chart.legendRow != null) ...[
          const SizedBox(height: 9),
          _LegendRow(chart.legendRow!),
        ],
      ],
    );
  }
}

// ===========================================================================
// Line
// ===========================================================================

class _LineChartView extends StatelessWidget {
  final LineChart chart;
  const _LineChartView(this.chart);

  Widget _chartAndLabels(double width, {double bottomGap = 0}) {
    final valueLabels = chart.valueLabels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (valueLabels != null) ...[
          SizedBox(
            width: width,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final v in valueLabels)
                  Flexible(
                    child: Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: chart.color),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: 138,
          width: width,
          child: CustomPaint(painter: _LinePainter(chart)),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final x in chart.xLabels)
                Flexible(
                  child: Text(
                    x,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF9CA3AF)),
                  ),
                ),
            ],
          ),
        ),
        if (bottomGap > 0) SizedBox(height: bottomGap),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (chart.xLabels.isEmpty) {
      return const SizedBox(
        height: 138,
        child: Center(
          child: Text('Sin datos', style: TextStyle(fontSize: 12, color: AppColors.ink3)),
        ),
      );
    }

    final minPointWidth = chart.minPointWidth;
    // Deliberately not measured via LayoutBuilder — see the comment in
    // _BarsChartView.build about IntrinsicHeight rejecting a LayoutBuilder
    // descendant.
    final body = minPointWidth == null
        ? _chartAndLabels(double.infinity)
        : _HorizontalWheelScroll(
            child: _chartAndLabels(
              chart.xLabels.length * minPointWidth,
              bottomGap: _scrollbarGap,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        if (chart.legendRow != null) ...[
          const SizedBox(height: 9),
          _LegendRow(chart.legendRow!),
        ],
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final LineChart chart;
  _LinePainter(this.chart);

  Path _pathFor(List<double> data, double max, Size size) {
    final path = Path();
    final n = data.length;
    for (var i = 0; i < n; i++) {
      final x = n <= 1 ? 0.0 : (i / (n - 1)) * size.width;
      final y = size.height - (max <= 0 ? 0 : data[i] / max * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final max = [
      ...chart.values,
      ...?chart.values2,
    ].fold(0.0, (m, v) => v > m ? v : m);

    final line = _pathFor(chart.values, max, size);

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = chart.color.withValues(alpha: 0.13));
    canvas.drawPath(
      line,
      Paint()
        ..color = chart.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    final values2 = chart.values2;
    if (values2 != null) {
      final line2 = _pathFor(values2, max, size);
      final dashed = Paint()
        ..color = chart.color2 ?? chart.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      _drawDashedPath(canvas, line2, dashed);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 6.0;
    const dashGap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.chart != chart;
}

class _LegendRow extends StatelessWidget {
  final List<ReportLegendEntry> entries;
  const _LegendRow(this.entries);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: e.color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text(e.label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
      ],
    );
  }
}

// ===========================================================================
// Donut
// ===========================================================================

class _DonutChartView extends StatelessWidget {
  final DonutChart chart;
  /// The card's actual content width, precomputed by [_ChartsGrid]/
  /// [_ChartCard] (a LayoutBuilder here would throw — this widget sits
  /// inside an IntrinsicHeight subtree, which doesn't support intrinsic-
  /// dimension queries against a LayoutBuilder). Null falls back to the
  /// side-by-side layout unconditionally.
  final double? availableWidth;
  const _DonutChartView(this.chart, {this.availableWidth});

  // The legend's fixed-width bits (dot + spacing + the two value columns)
  // need at least this much room before the label even gets a look-in —
  // below it, the Row overflows no matter how far the label's Expanded
  // shrinks, since only the label is flexible.
  static const _minLegendWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final fontScale = (chart.size / 134).clamp(1.0, 1.4);
    final ring = SizedBox(
      width: chart.size,
      height: chart.size,
      child: CustomPaint(
        painter: _DonutPainter(chart.segments),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chart.center,
                style: TextStyle(fontSize: 16 * fontScale, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              Text(
                chart.centerSub,
                style: TextStyle(fontSize: 9 * fontScale, color: const Color(0xFF8A93A3)),
              ),
            ],
          ),
        ),
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in chart.segments)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151)),
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: Text(
                    s.valText,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
                if (s.valText2 != null)
                  SizedBox(
                    width: 44,
                    child: Text(
                      s.valText2!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8A93A3)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    // A Row keeps the legend beside the ring so long as there's enough
    // width for it; below that threshold (narrow single-span chart cards)
    // stack the legend under the ring instead of overflowing sideways.
    final width = availableWidth;
    if (width != null && width < chart.size + 18 + _minLegendWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: ring),
          const SizedBox(height: 12),
          legend,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ring,
        const SizedBox(width: 18),
        Expanded(child: legend),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold(0.0, (s, x) => s + x.value);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(size.width * 0.09);
    var startAngle = -math.pi / 2;
    final strokeWidth = size.width * 0.17;
    for (final s in segments) {
      final sweep = s.value / total * 2 * math.pi;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.segments != segments;
}

// ===========================================================================
// Horizontal bars
// ===========================================================================

class _HBarsChartView extends StatelessWidget {
  final HBarsChart chart;
  const _HBarsChartView(this.chart);

  // Each row is boxed to exactly this height (rather than left to size
  // itself from padding + text metrics) so [chart.visibleRows] * _rowHeight
  // always fits exactly that many rows — a content-driven height here used
  // to run a couple of pixels taller than assumed, showing 9 rows of "10"
  // instead of 10.
  static const _rowHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final max = chart.items.fold(0.0, (m, v) => v.value > m ? v.value : m);
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in chart.items)
          SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: LinearProgressIndicator(
                      value: max <= 0 ? 0 : (item.value / max).clamp(0.02, 1.0),
                      minHeight: 13,
                      backgroundColor: const Color(0xFFF1F3F7),
                      valueColor: AlwaysStoppedAnimation(item.color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(
                    item.valText,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final visibleRows = chart.visibleRows;
    if (visibleRows == null) return list;
    return SizedBox(
      height: visibleRows * _rowHeight,
      child: SingleChildScrollView(child: list),
    );
  }
}

// ===========================================================================
// Product list (venta mayor / menor / sin venta buckets)
// ===========================================================================

class _ProductListChartView extends StatelessWidget {
  final ProductListChart chart;
  const _ProductListChartView(this.chart);

  // Each row is boxed to exactly this height (same reasoning as
  // _HBarsChartView._rowHeight) so [chart.visibleRows] * _rowHeight always
  // fits exactly that many rows, regardless of the text's actual metrics.
  static const _rowHeight = 26.0;

  @override
  Widget build(BuildContext context) {
    final height = chart.visibleRows * _rowHeight;
    if (chart.items.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Sin datos', style: TextStyle(fontSize: 12, color: AppColors.ink3)),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chart.items.length; i++)
              SizedBox(
                height: _rowHeight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: i.isEven ? const Color(0xFFF7F8FA) : Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chart.items[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.ink),
                        ),
                      ),
                      if (chart.items[i].valueText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          chart.items[i].valueText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: chart.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Table
// ===========================================================================

class _ReportTable extends StatelessWidget {
  final String title;
  final String count;
  final List<ReportTableHeader> headers;
  final List<ReportTableRow> rows;
  /// Server-side pagination for this table's rows (100/page) — set only by
  /// the sales/orders detail tables. [totalPages] <= 1 renders no
  /// paginator at all (nothing to page through). [onPageChange] must be
  /// non-null whenever [totalPages] is set.
  final int page;
  final int totalPages;
  final bool loadingPage;
  final ValueChanged<int>? onPageChange;

  const _ReportTable({
    required this.title,
    required this.count,
    required this.headers,
    required this.rows,
    this.page = 1,
    this.totalPages = 0,
    this.loadingPage = false,
    this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                Text(count, style: const TextStyle(fontSize: 11.5, color: AppColors.ink3)),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 44,
                  horizontalMargin: 14,
                  columnSpacing: 22,
                  headingRowColor:
                      const WidgetStatePropertyAll(Color(0xFFFAFBFC)),
                  columns: [
                    for (final h in headers)
                      DataColumn(
                        label: Expanded(
                          child: Align(
                            alignment: h.alignRight ? Alignment.centerRight : Alignment.centerLeft,
                            child: Text(
                              h.label.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8A93A3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow(
                        cells: [
                          for (final c in r.cells)
                            DataCell(Align(
                              alignment: c.alignRight ? Alignment.centerRight : Alignment.centerLeft,
                              child: _TableCellView(c),
                            )),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Sin resultados', style: TextStyle(fontSize: 13, color: AppColors.ink3)),
              ),
            ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _TablePagination(
                page: page,
                totalPages: totalPages,
                loading: loadingPage,
                onChange: onPageChange!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Prev/next pager for a server-paginated [_ReportTable] — no direct
/// page-number buttons since `total_pages` can run into the dozens for a
/// wide date range; "Página X de Y" plus two arrows is enough to step
/// through without over-building the control.
class _TablePagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final bool loading;
  final ValueChanged<int> onChange;

  const _TablePagination({
    required this.page,
    required this.totalPages,
    required this.loading,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageStepButton(
          icon: Icons.chevron_left,
          onPressed: (!loading && page > 1) ? () => onChange(page - 1) : null,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Página $page de $totalPages',
                    style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        _PageStepButton(
          icon: Icons.chevron_right,
          onPressed: (!loading && page < totalPages) ? () => onChange(page + 1) : null,
        ),
      ],
    );
  }
}

class _PageStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _PageStepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
          color: enabled ? Colors.white : const Color(0xFFF5F6F8),
        ),
        child: Icon(icon, size: 16, color: enabled ? AppColors.ink : AppColors.ink3),
      ),
    );
  }
}

class _TableCellView extends StatelessWidget {
  final ReportCell cell;
  const _TableCellView(this.cell);

  @override
  Widget build(BuildContext context) {
    switch (cell.kind) {
      case ReportCellKind.badge:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: cell.badgeBg, borderRadius: BorderRadius.circular(99)),
          child: Text(
            cell.text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cell.badgeFg),
          ),
        );
      case ReportCellKind.dot:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: cell.dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(cell.text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
          ],
        );
      case ReportCellKind.plain:
        return Text(
          cell.text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: cell.bold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF374151),
          ),
        );
    }
  }
}
