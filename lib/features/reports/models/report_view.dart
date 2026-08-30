import 'package:flutter/material.dart';

/// The report screens available under the "Reportes" menu section.
enum ReportType { dashboard, ventas, pedidos, productos, categorias, employeeSummary }

class ReportFilter {
  final String label;
  final String value;
  const ReportFilter(this.label, this.value);

  /// Summarizes a multi-select filter's applied value for display (e.g. in a
  /// PDF export's header) the same way the on-screen filter chips do:
  /// "Todos" when every option is selected, "Ninguno" when none, otherwise
  /// the selected item name(s) joined by comma.
  static String summarize<T>({
    required List<T> items,
    required String Function(T) labelOf,
    required Set<T> selected,
  }) {
    if (items.isEmpty) return '—';
    if (selected.length == items.length) return 'Todos';
    if (selected.isEmpty) return 'Ninguno';
    return selected.map(labelOf).join(', ');
  }
}

/// Formats a date range as `dd/MM/yyyy – dd/MM/yyyy` for display in a PDF
/// export's header (mirrors the on-screen "Fechas" filter chip, but with the
/// full year since the PDF is a standalone document).
String reportDateRangeLabel(DateTime start, DateTime end) {
  String fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  return '${fmt(start)} – ${fmt(end)}';
}

class ReportKpi {
  final String label;
  final String value;
  final String sub;
  final Color accent;
  final Color subColor;
  /// Color of the big value text. Defaults to the card's normal ink color
  /// (set by `_KpiCard` when null) — only override for a KPI whose value
  /// itself should read as good/bad news (e.g. "Día con mayor venta" in
  /// green).
  final Color? valueColor;
  final double valueFontSize;
  final int span;

  const ReportKpi({
    required this.label,
    required this.value,
    this.sub = '',
    required this.accent,
    this.subColor = const Color(0xFF8A93A3),
    this.valueColor,
    this.valueFontSize = 24,
    this.span = 1,
  });
}

enum ReportCellKind { plain, badge, dot }

class ReportCell {
  final String text;
  final ReportCellKind kind;
  final bool bold;
  final bool alignRight;
  final Color? badgeBg;
  final Color? badgeFg;
  final Color? dotColor;

  const ReportCell.plain(this.text, {this.bold = false, this.alignRight = false})
      : kind = ReportCellKind.plain,
        badgeBg = null,
        badgeFg = null,
        dotColor = null;

  const ReportCell.badge(this.text, {required Color bg, required Color fg})
      : kind = ReportCellKind.badge,
        badgeBg = bg,
        badgeFg = fg,
        bold = false,
        alignRight = false,
        dotColor = null;

  const ReportCell.dot(this.text, {required Color color})
      : kind = ReportCellKind.dot,
        dotColor = color,
        bold = false,
        alignRight = false,
        badgeBg = null,
        badgeFg = null;
}

class ReportTableHeader {
  final String label;
  final bool alignRight;
  const ReportTableHeader(this.label, {this.alignRight = false});
}

class ReportTableRow {
  final List<ReportCell> cells;
  const ReportTableRow(this.cells);
}

/// Base type for the chart variants a report card can render. [span] is out
/// of a 6-column grid, mirroring the design's `grid-template-columns:
/// repeat(6, 1fr)`.
abstract class ReportChart {
  final String title;
  final int span;
  const ReportChart(this.title, this.span);
}

class BarsChart extends ReportChart {
  final List<String> labels;
  final List<double> values;
  final Color color;
  /// Optional per-bar value text (e.g. "3") shown above each bar. When null,
  /// bars render without a label, matching the original design.
  final List<String>? valueLabels;
  /// Minimum width per bar in logical pixels. When set, the chart reserves
  /// `labels.length * minBarWidth` and scrolls horizontally instead of
  /// squeezing every bar into the card's width — needed once a date-range
  /// filter can return many more bars (e.g. 20+ days) than fit legibly.
  final double? minBarWidth;
  const BarsChart(
    super.title,
    super.span, {
    required this.labels,
    required this.values,
    required this.color,
    this.valueLabels,
    this.minBarWidth,
  });
}

class LineChartSeries {
  final List<double> values;
  final Color color;
  final bool dashed;
  const LineChartSeries(this.values, this.color, {this.dashed = false});
}

class LineChart extends ReportChart {
  final List<String> xLabels;
  final List<double> values;
  final Color color;
  final List<double>? values2;
  final Color? color2;
  final List<ReportLegendEntry>? legendRow;
  /// Minimum width per data point in logical pixels. When set, the chart
  /// reserves `xLabels.length * minPointWidth` and scrolls horizontally
  /// instead of cramming every point into the card's width — same reasoning
  /// as [BarsChart.minBarWidth].
  final double? minPointWidth;
  /// Optional per-point value text (e.g. "$355") for the primary [values]
  /// series, shown above each point on the line — mirrors
  /// [BarsChart.valueLabels].
  final List<String>? valueLabels;
  const LineChart(
    super.title,
    super.span, {
    required this.xLabels,
    required this.values,
    required this.color,
    this.values2,
    this.color2,
    this.legendRow,
    this.minPointWidth,
    this.valueLabels,
  });
}

class ReportLegendEntry {
  final String label;
  final Color color;
  const ReportLegendEntry(this.label, this.color);
}

class DonutSegment {
  final String label;
  final double value;
  final Color color;
  final String valText;
  /// Optional second trailing column (e.g. "87%") shown after [valText] in
  /// the legend row, mirroring designs that show both an absolute value and
  /// its share of the total.
  final String? valText2;
  const DonutSegment(this.label, this.value, this.color, this.valText, {this.valText2});
}

class DonutChart extends ReportChart {
  final List<DonutSegment> segments;
  final String center;
  final String centerSub;
  /// Ring diameter in logical pixels — bump this up for a donut given a lot
  /// of card width (e.g. a 75%-width card) so it doesn't look lost next to
  /// its legend.
  final double size;
  const DonutChart(
    super.title,
    super.span, {
    required this.segments,
    required this.center,
    required this.centerSub,
    this.size = 134,
  });
}

class HBarItem {
  final String label;
  final double value;
  final Color color;
  final String valText;
  const HBarItem(this.label, this.value, this.color, this.valText);
}

class HBarsChart extends ReportChart {
  final List<HBarItem> items;
  /// When set, the chart renders at a fixed height matching this many rows
  /// instead of auto-sizing to [items], scrolling internally for the rest —
  /// used so a row of bar charts with varying item counts (e.g. "Cantidad
  /// por categoría" vs. the always-10 "Top 10 productos") stays the same
  /// height. Null (the default) preserves the old auto-height behavior.
  final int? visibleRows;
  const HBarsChart(super.title, super.span, {required this.items, this.visibleRows});
}

class StackSeries {
  final Color color;
  final List<double> data;
  const StackSeries(this.color, this.data);
}

/// One row of a [ProductListChart] — a ranked product name with an optional
/// trailing value (e.g. units sold). [valueText] is empty for buckets that
/// carry no quantity, such as "sin venta".
class ProductListItem {
  final String name;
  final String valueText;
  const ProductListItem(this.name, {this.valueText = ''});
}

/// A ranked list of products (venta mayor/menor, sin venta), mirroring the
/// design's `ProductList` component: alternating-row list with the value
/// right-aligned in [color]. Rendered with a bounded, scrollable height so a
/// bucket with many items (e.g. dozens of "sin venta" products) doesn't blow
/// out the surrounding chart-grid row.
class ProductListChart extends ReportChart {
  final List<ProductListItem> items;
  final Color color;
  /// Fixed number of rows the card is tall enough to show before scrolling
  /// internally — keeps venta-mayor/venta-menor/sin-venta the same height
  /// regardless of how many products fall in each bucket.
  final int visibleRows;
  /// Optional header pill (e.g. "Alta rotación" in green), mirroring the
  /// design's `CardTitle right={<Pill .../>}`.
  final String? badgeText;
  final Color? badgeColor;
  /// Optional small description under the title, mirroring the design's
  /// `CardTitle sub="…"` (e.g. "Vendidos > 10").
  final String? subtitle;
  const ProductListChart(
    super.title,
    super.span, {
    required this.items,
    required this.color,
    this.visibleRows = 10,
    this.badgeText,
    this.badgeColor,
    this.subtitle,
  });
}

class StackChart extends ReportChart {
  final List<String> labels;
  final List<StackSeries> series;
  final List<ReportLegendEntry>? legendRow;
  const StackChart(
    super.title,
    super.span, {
    required this.labels,
    required this.series,
    this.legendRow,
  });
}

/// Full content of one report screen, mirroring the design's `renderVals()`.
class ReportView {
  final String title;
  final String subtitle;
  final List<ReportFilter> filters;
  final bool hasSearch;
  final String searchPlaceholder;
  final List<ReportKpi> kpis;
  final List<ReportChart> charts;
  final String tableTitle;
  final String tableCount;
  final List<ReportTableHeader> headers;
  final List<ReportTableRow> rows;
  final bool chartsBeforeTable;
  /// Optional dedicated row rendered below [charts], outside the normal
  /// 6-column bin-packing: [buckets] (venta mayor/menor/sin venta) share
  /// 68% of the row width evenly and [bucketsSideChart] (órdenes por hora)
  /// takes the remaining 32%, via each chart's own `span` used as a flex
  /// weight (68/68/68/96 sums to a clean 300). Empty by default — only the
  /// daily dashboard sets these.
  final List<ProductListChart> buckets;
  final ReportChart? bucketsSideChart;

  const ReportView({
    required this.title,
    required this.subtitle,
    required this.filters,
    this.hasSearch = false,
    this.searchPlaceholder = '',
    required this.kpis,
    required this.charts,
    required this.tableTitle,
    required this.tableCount,
    required this.headers,
    required this.rows,
    this.chartsBeforeTable = true,
    this.buckets = const [],
    this.bucketsSideChart,
  });

  /// Used by PDF export to strip the detail table (pass empty `headers`)
  /// while keeping the same KPI/chart data — `buildReportPdfBytes` only
  /// renders a table section when `headers` is non-empty.
  ReportView copyWith({
    List<ReportTableHeader>? headers,
    List<ReportTableRow>? rows,
  }) {
    return ReportView(
      title: title,
      subtitle: subtitle,
      filters: filters,
      hasSearch: hasSearch,
      searchPlaceholder: searchPlaceholder,
      kpis: kpis,
      charts: charts,
      tableTitle: tableTitle,
      tableCount: tableCount,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      chartsBeforeTable: chartsBeforeTable,
      buckets: buckets,
      bucketsSideChart: bucketsSideChart,
    );
  }
}
