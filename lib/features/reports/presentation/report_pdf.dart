import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';

/// Renders a [ReportView] (the same shape the on-screen report widgets
/// consume) into a PDF that mirrors the on-screen card/chart/table layout of
/// `reports_page.dart`, rather than flattening everything into plain tables.
Future<Uint8List> buildReportPdfBytes(ReportView view) async {
  final doc = pw.Document();
  final generatedAt = DateTime.now();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
      header: (context) =>
          context.pageNumber == 1 ? _buildHeader(view, generatedAt) : pw.SizedBox.shrink(),
      build: (context) => [
        if (view.kpis.isNotEmpty) ...[_KpiRows(view.kpis), pw.SizedBox(height: 12)],
        if (view.charts.isNotEmpty) ...[_ChartRows(view.charts), pw.SizedBox(height: 12)],
        if (view.buckets.isNotEmpty || view.bucketsSideChart != null) ...[
          _BucketsPdfRow(buckets: view.buckets, sideChart: view.bucketsSideChart),
          pw.SizedBox(height: 12),
        ],
        if (view.headers.isNotEmpty) ..._buildTableSection(view),
      ],
    ),
  );

  return doc.save();
}

// ===== design tokens (mirrors lib/core/theme/app_theme.dart AppColors) =====

const _navy = PdfColor.fromInt(0xFF16203B);
const _line = PdfColor.fromInt(0xFFE8ECF1);
const _ink = PdfColor.fromInt(0xFF16203B);
const _ink3 = PdfColor.fromInt(0xFF8A94A6);
const _cellText = PdfColor.fromInt(0xFF374151);
const _headerBg = PdfColor.fromInt(0xFFFAFBFC);

PdfColor _pc(Color c) => PdfColor.fromInt(c.toARGB32());

/// `PdfGraphics.setFillColor` ignores the alpha channel entirely (it only
/// emits the `rg` RGB operator), so a translucent [PdfColor] paints as fully
/// opaque — indistinguishable from same-color text on top of it. Blend
/// against white by hand instead to get a real light opaque tint.
PdfColor _tint(PdfColor c, double alpha) {
  double blend(double channel) => 1 - alpha * (1 - channel);
  return PdfColor(blend(c.red), blend(c.green), blend(c.blue));
}

String _fmtDateTime(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// The base14 PDF fonts have no glyph for ▲/▼ or the en/em dash (renders as
/// a fallback box/notdef shape, e.g. in a "Fechas" range like "18/07/2026 –
/// 18/07/2026") — swap them for ASCII the base font can actually draw.
String _pdfSafe(String s) => s
    .replaceAll('▲', '+')
    .replaceAll('▼', '-')
    .replaceAll('–', '-')
    .replaceAll('—', '-');

// ===========================================================================
// Header
// ===========================================================================

pw.Widget _buildHeader(ReportView view, DateTime generatedAt) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  view.title,
                  style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: _navy),
                ),
                pw.SizedBox(height: 2),
                pw.Text(view.subtitle, style: const pw.TextStyle(fontSize: 10, color: _ink3)),
              ],
            ),
          ),
          pw.Text(
            'Generado: ${_fmtDateTime(generatedAt)}',
            style: const pw.TextStyle(fontSize: 8, color: _ink3),
          ),
        ],
      ),
      if (view.filters.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final f in view.filters)
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${f.label}: ',
                      style: const pw.TextStyle(fontSize: 8, color: _ink3),
                    ),
                    pw.TextSpan(
                      text: _pdfSafe(f.value),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
      pw.SizedBox(height: 9),
      pw.Divider(color: _line, thickness: 0.8),
      pw.SizedBox(height: 10),
    ],
  );
}

// ===========================================================================
// KPI cards — rows of up to 5, each a bordered card with a left accent bar
// (mirrors _KpiCard in reports_page.dart)
// ===========================================================================

class _KpiRows extends pw.StatelessWidget {
  final List<ReportKpi> kpis;
  _KpiRows(this.kpis);

  /// Cards per row never exceeds this, but — unlike a naive fixed chunk —
  /// rows are balanced so a trailing row is never left with just one card
  /// (which, wrapped in the same `Expanded` as every other card, would
  /// stretch to the full row width instead of matching its siblings' size).
  static const _maxPerRow = 6;
  static const _cardHeight = 46.0;

  @override
  pw.Widget build(pw.Context context) {
    if (kpis.isEmpty) return pw.SizedBox.shrink();
    final numRows = (kpis.length / _maxPerRow).ceil();
    final perRow = (kpis.length / numRows).ceil();

    final rows = <pw.Widget>[];
    for (var i = 0; i < kpis.length; i += perRow) {
      final slice = kpis.sublist(i, math.min(i + perRow, kpis.length));
      final children = <pw.Widget>[];
      for (var j = 0; j < slice.length; j++) {
        if (j > 0) children.add(pw.SizedBox(width: 8));
        children.add(pw.Expanded(child: _kpiCard(slice[j])));
      }
      rows.add(pw.SizedBox(height: _cardHeight, child: pw.Row(children: children)));
      if (i + perRow < kpis.length) rows.add(pw.SizedBox(height: 8));
    }
    return pw.Column(children: rows);
  }

  pw.Widget _kpiCard(ReportKpi kpi) {
    final isDelta = kpi.sub.startsWith('▲') || kpi.sub.startsWith('▼');
    final subColor = _pc(kpi.subColor);
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _line, width: 0.7),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(width: 3, color: _pc(kpi.accent)),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // flex: 3 guarantees the label a minimum share of the row
                  // even when the value (flex: 2 below) is long — it used to
                  // take its full intrinsic width unconditionally, which
                  // could squeeze the label down to just a couple letters.
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          kpi.label,
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                          style: const pw.TextStyle(fontSize: 7.3, color: _ink3),
                        ),
                        if (kpi.sub.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          isDelta
                              ? pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: _tint(subColor, 0.16),
                                    borderRadius: pw.BorderRadius.circular(5),
                                  ),
                                  child: pw.Text(
                                    _pdfSafe(kpi.sub),
                                    style: pw.TextStyle(
                                      fontSize: 6.6,
                                      fontWeight: pw.FontWeight.bold,
                                      color: subColor,
                                    ),
                                  ),
                                )
                              : pw.Text(_pdfSafe(kpi.sub), style: pw.TextStyle(fontSize: 6.8, color: subColor)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        kpi.value,
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                        style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Charts — bin-packed into rows of 6 grid columns, same as _ChartsGrid, each
// chart re-drawn (not flattened to a table) to match its on-screen look.
// ===========================================================================

class _ChartRows extends pw.StatelessWidget {
  final List<ReportChart> charts;
  _ChartRows(this.charts);

  static const _rowHeight = 132.0;

  @override
  pw.Widget build(pw.Context context) {
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

    final widgets = <pw.Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final children = <pw.Widget>[];
      for (var j = 0; j < rows[i].length; j++) {
        if (j > 0) children.add(pw.SizedBox(width: 10));
        children.add(pw.Expanded(flex: rows[i][j].span, child: _chartCard(rows[i][j])));
      }
      widgets.add(pw.SizedBox(height: _rowHeight, child: pw.Row(children: children)));
      if (i != rows.length - 1) widgets.add(pw.SizedBox(height: 10));
    }
    return pw.Column(children: widgets);
  }
}

// ===========================================================================
// Buckets row — venta mayor / venta menor / sin venta (68% combined, equal
// thirds) + órdenes por hora (32%), mirroring `_BucketsRow` in
// reports_page.dart. Each chart's `span` is reused as its flex weight
// (68/68/68/96 sums to 300, i.e. exactly 68%/32%).
// ===========================================================================

class _BucketsPdfRow extends pw.StatelessWidget {
  final List<ProductListChart> buckets;
  final ReportChart? sideChart;
  _BucketsPdfRow({required this.buckets, required this.sideChart});

  static const _rowHeight = 132.0;

  @override
  pw.Widget build(pw.Context context) {
    final children = <ReportChart>[...buckets, ?sideChart];
    if (children.isEmpty) return pw.SizedBox.shrink();
    final widgets = <pw.Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) widgets.add(pw.SizedBox(width: 10));
      widgets.add(pw.Expanded(flex: children[i].span, child: _chartCard(children[i])));
    }
    return pw.SizedBox(height: _rowHeight, child: pw.Row(children: widgets));
  }
}

// ===== shared chart-card chrome (title + optional badge/subtitle + body) ===

pw.Widget _chartCard(ReportChart chart) {
  final plc = chart is ProductListChart ? chart : null;
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(11, 9, 11, 8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _line, width: 0.7),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    chart.title,
                    style: pw.TextStyle(fontSize: 8.6, fontWeight: pw.FontWeight.bold, color: _cellText),
                  ),
                  if (plc?.subtitle != null) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(plc!.subtitle!, style: const pw.TextStyle(fontSize: 6.6, color: _ink3)),
                  ],
                ],
              ),
            ),
            if (plc?.badgeText != null) _pdfPill(plc!.badgeText!, _pc(plc.badgeColor ?? const Color(0xFF16203B))),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Expanded(child: _chartBody(chart)),
      ],
    ),
  );
}

pw.Widget _pdfPill(String text, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: pw.BoxDecoration(color: _tint(color, 0.16), borderRadius: pw.BorderRadius.circular(5)),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, color: color)),
  );
}

pw.Widget _chartBody(ReportChart chart) {
  if (chart is LineChart) return _LineChartBody(chart);
  if (chart is BarsChart) return _BarsChartBody(chart);
  if (chart is DonutChart) return _DonutChartBody(chart);
  if (chart is HBarsChart) return _HBarsChartBody(chart);
  if (chart is ProductListChart) return _ProductListChartBody(chart);
  if (chart is StackChart) return _StackChartBody(chart);
  return pw.SizedBox.shrink();
}

// ----- line -----

class _LineChartBody extends pw.StatelessWidget {
  final LineChart chart;
  _LineChartBody(this.chart);

  @override
  pw.Widget build(pw.Context context) {
    if (chart.values.isEmpty) {
      return pw.Center(child: pw.Text('Sin datos', style: const pw.TextStyle(fontSize: 7.5, color: _ink3)));
    }
    final maxV = [...chart.values, ...?chart.values2].fold(0.0, (m, v) => v > m ? v : m);
    final color = _pc(chart.color);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.LayoutBuilder(
            builder: (context, constraints) {
              final size = PdfPoint(constraints!.maxWidth, constraints.maxHeight);
              return pw.CustomPaint(
                size: size,
                painter: (canvas, size) => _paintLine(canvas, size, chart.values, maxV, color),
              );
            },
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            for (final x in chart.xLabels) pw.Text(x, style: const pw.TextStyle(fontSize: 6.2, color: _ink3)),
          ],
        ),
      ],
    );
  }

  void _paintLine(PdfGraphics canvas, PdfPoint size, List<double> values, double maxV, PdfColor color) {
    final n = values.length;
    final pts = [
      for (var i = 0; i < n; i++)
        PdfPoint(
          n <= 1 ? size.x / 2 : size.x * i / (n - 1),
          maxV <= 0 ? 0.0 : (values[i] / maxV) * size.y,
        ),
    ];
    if (pts.isEmpty) return;

    canvas
      ..setFillColor(_tint(color, 0.14))
      ..moveTo(pts.first.x, 0);
    for (final p in pts) {
      canvas.lineTo(p.x, p.y);
    }
    canvas
      ..lineTo(pts.last.x, 0)
      ..closePath()
      ..fillPath();

    canvas
      ..setStrokeColor(color)
      ..setLineWidth(1.4)
      ..moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      canvas.lineTo(p.x, p.y);
    }
    canvas.strokePath();
  }
}

// ----- bars -----

class _BarsChartBody extends pw.StatelessWidget {
  final BarsChart chart;
  _BarsChartBody(this.chart);

  @override
  pw.Widget build(pw.Context context) {
    if (chart.labels.isEmpty) {
      return pw.Center(child: pw.Text('Sin datos', style: const pw.TextStyle(fontSize: 7.5, color: _ink3)));
    }
    final maxV = chart.values.fold(0.0, (m, v) => v > m ? v : m);
    final color = _pc(chart.color);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < chart.labels.length; i++) ...[
                if (i > 0) pw.SizedBox(width: 3),
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      if (chart.valueLabels != null) ...[
                        pw.Text(
                          chart.valueLabels![i],
                          maxLines: 1,
                          style: pw.TextStyle(fontSize: 6.4, fontWeight: pw.FontWeight.bold, color: _ink),
                        ),
                        pw.SizedBox(height: 2),
                      ],
                      pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Container(
                              height: (maxV <= 0 ? 0.03 : math.max(0.03, chart.values[i] / maxV)) * 62,
                              width: double.infinity,
                              color: color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            for (var i = 0; i < chart.labels.length; i++)
              pw.Expanded(
                child: pw.Text(
                  chart.labels[i],
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.2, color: _ink3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ----- donut -----

class _DonutChartBody extends pw.StatelessWidget {
  final DonutChart chart;
  _DonutChartBody(this.chart);

  @override
  pw.Widget build(pw.Context context) {
    final total = chart.segments.fold(0.0, (s, x) => s + x.value);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: 76,
          height: 76,
          child: pw.Stack(
            children: [
              pw.CustomPaint(
                size: const PdfPoint(76, 76),
                painter: (canvas, size) => _paintDonut(canvas, size, chart.segments, total),
              ),
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(chart.center, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink)),
                      pw.Text(chart.centerSub, style: const pw.TextStyle(fontSize: 5.3, color: _ink3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final s in chart.segments)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    children: [
                      pw.Container(width: 6, height: 6, color: _pc(s.color)),
                      pw.SizedBox(width: 5),
                      pw.Expanded(
                        child: pw.Text(s.label, maxLines: 1, style: const pw.TextStyle(fontSize: 7, color: _cellText)),
                      ),
                      pw.Text(s.valText, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _ink)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _paintDonut(PdfGraphics canvas, PdfPoint size, List<DonutSegment> segments, double total) {
    if (total <= 0) return;
    final cx = size.x / 2;
    final cy = size.y / 2;
    final outerR = size.x * 0.42;
    final innerR = outerR * 0.62;
    const steps = 48;
    var angle = math.pi / 2; // start at 12 o'clock
    for (final s in segments) {
      final sweep = s.value / total * 2 * math.pi;
      if (sweep <= 0) continue;
      canvas.setFillColor(_pc(s.color));
      final pts = <PdfPoint>[];
      for (var i = 0; i <= steps; i++) {
        final a = angle - sweep * (i / steps);
        pts.add(PdfPoint(cx + outerR * math.cos(a), cy + outerR * math.sin(a)));
      }
      for (var i = steps; i >= 0; i--) {
        final a = angle - sweep * (i / steps);
        pts.add(PdfPoint(cx + innerR * math.cos(a), cy + innerR * math.sin(a)));
      }
      canvas.moveTo(pts.first.x, pts.first.y);
      for (final p in pts.skip(1)) {
        canvas.lineTo(p.x, p.y);
      }
      canvas.fillPath();
      angle -= sweep;
    }
  }
}

// ----- horizontal bars -----

class _HBarsChartBody extends pw.StatelessWidget {
  final HBarsChart chart;
  _HBarsChartBody(this.chart);

  @override
  pw.Widget build(pw.Context context) {
    final maxV = chart.items.fold(0.0, (m, v) => v.value > m ? v.value : m);
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        for (final item in chart.items)
          pw.Row(
            children: [
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  item.label,
                  maxLines: 1,
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 6.6, color: _cellText),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.LayoutBuilder(
                  builder: (context, constraints) {
                    final trackWidth = constraints!.maxWidth;
                    final fraction = maxV <= 0 ? 0.02 : math.max(0.02, item.value / maxV);
                    return pw.Stack(
                      children: [
                        pw.Container(
                          height: 8,
                          width: trackWidth,
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F3F7)),
                        ),
                        pw.Container(height: 8, width: trackWidth * fraction, color: _pc(item.color)),
                      ],
                    );
                  },
                ),
              ),
              pw.SizedBox(width: 6),
              pw.SizedBox(
                width: 34,
                child: pw.Text(
                  item.valText,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 6.6, fontWeight: pw.FontWeight.bold, color: _ink),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ----- product list (venta mayor / menor / sin venta) -----

class _ProductListChartBody extends pw.StatelessWidget {
  final ProductListChart chart;
  _ProductListChartBody(this.chart);

  @override
  pw.Widget build(pw.Context context) {
    if (chart.items.isEmpty) {
      return pw.Center(child: pw.Text('Sin datos', style: const pw.TextStyle(fontSize: 7.5, color: _ink3)));
    }
    final color = _pc(chart.color);
    // The on-screen card scrolls; the PDF has no scroll, so cap the row
    // count to what fits in the fixed chart-row height instead of
    // overflowing the page.
    final visible = chart.items.take(9);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in visible)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(item.name, maxLines: 1, style: const pw.TextStyle(fontSize: 7, color: _cellText)),
                ),
                if (item.valueText.isNotEmpty)
                  pw.Text(item.valueText, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: color)),
              ],
            ),
          ),
        if (chart.items.length > visible.length)
          pw.Text(
            '+ ${chart.items.length - visible.length} más',
            style: const pw.TextStyle(fontSize: 6.5, color: _ink3),
          ),
      ],
    );
  }
}

// ----- stacked bars (rare; kept simple) -----

class _StackChartBody extends pw.StatelessWidget {
  final StackChart chart;
  _StackChartBody(this.chart);

  @override
  pw.Widget build(pw.Context context) {
    final totals = [
      for (var i = 0; i < chart.labels.length; i++)
        chart.series.fold(0.0, (s, series) => s + series.data[i]),
    ];
    final maxV = totals.fold(0.0, (m, v) => v > m ? v : m);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < chart.labels.length; i++) ...[
                if (i > 0) pw.SizedBox(width: 3),
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      for (final series in chart.series.reversed)
                        pw.Container(
                          height: (maxV <= 0 ? 0.01 : math.max(0.01, series.data[i] / maxV)) * 60,
                          width: double.infinity,
                          color: _pc(series.color),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            for (final l in chart.labels)
              pw.Expanded(
                child: pw.Text(l, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.2, color: _ink3)),
              ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// Main data table (mirrors _ReportTable / _TableCellView)
// ===========================================================================

/// `pw.MultiPage` refuses to lay out a single widget across more than 20
/// pages (`PdfTooBigPageException`) — verified empirically this table
/// starts tripping that ceiling somewhere around 400-550 rows depending on
/// how much page space the KPI/chart rows above it already used. A PDF
/// export isn't the right place for a multi-hundred-row raw dump anyway
/// (that's what the on-screen table and CSV export are for), so cap it
/// well under the threshold and note how many rows were left out.
const _maxPdfTableRows = 300;

/// Returns the table title/count and the table itself as *separate*
/// top-level `MultiPage` children rather than one `pw.Column` wrapping
/// both. `pw.Table` only knows how to split itself across pages when
/// `MultiPage` sees it directly in its content list — nested inside a
/// Column, the whole title+table block is treated as one unsplittable
/// unit, which is what caused the page-count ceiling to bite even for
/// tables that easily fit under it.
List<pw.Widget> _buildTableSection(ReportView view) {
  final rows = view.rows.take(_maxPdfTableRows).toList();
  final omitted = view.rows.length - rows.length;
  return [
    pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            view.tableTitle,
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
        ),
        pw.Text(view.tableCount, style: const pw.TextStyle(fontSize: 8.5, color: _ink3)),
      ],
    ),
    pw.SizedBox(height: 6),
    if (rows.isEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 14),
        child: pw.Center(child: pw.Text('Sin resultados', style: const pw.TextStyle(fontSize: 9, color: _ink3))),
      )
    else
      _dataTable(view, rows),
    if (omitted > 0) ...[
      pw.SizedBox(height: 6),
      pw.Text(
        '+ $omitted registros más — usa el detalle en pantalla o exporta CSV para verlos todos.',
        style: const pw.TextStyle(fontSize: 8, color: _ink3),
      ),
    ],
  ];
}

pw.Widget _dataTable(ReportView view, List<ReportTableRow> rows) {
  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: const pw.BorderSide(color: _line, width: 0.5),
      top: const pw.BorderSide(color: _line, width: 0.5),
      bottom: const pw.BorderSide(color: _line, width: 0.5),
    ),
    columnWidths: {
      for (var i = 0; i < view.headers.length; i++) i: const pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerBg),
        children: [
          for (final h in view.headers)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(
                h.label.toUpperCase(),
                textAlign: h.alignRight ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _ink3),
              ),
            ),
        ],
      ),
      for (final r in rows)
        pw.TableRow(
          children: [
            for (final c in r.cells)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: pw.Align(
                  alignment: c.alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                  child: _tableCell(c),
                ),
              ),
          ],
        ),
    ],
  );
}

pw.Widget _tableCell(ReportCell c) {
  switch (c.kind) {
    case ReportCellKind.badge:
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(color: _pc(c.badgeBg!), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(c.text, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pc(c.badgeFg!))),
      );
    case ReportCellKind.dot:
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(width: 5, height: 5, color: _pc(c.dotColor!)),
          pw.SizedBox(width: 4),
          pw.Text(c.text, style: const pw.TextStyle(fontSize: 8, color: _cellText)),
        ],
      );
    case ReportCellKind.plain:
      return pw.Text(
        c.text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: c.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _cellText,
        ),
      );
  }
}
