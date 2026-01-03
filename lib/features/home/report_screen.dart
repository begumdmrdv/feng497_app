import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

/// Eğer sende gerçek model varsa burayı kaldırıp kendi sample modeline bağla.
/// Tek ihtiyacımız: timestamp + mg/dL
class GlucoseSample {
  final DateTime ts;
  final double mgdl;

  GlucoseSample({required this.ts, required this.mgdl});
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const primary = Color(0xFF7B3FF2);

  // Demo data (sende gerçek dataya bağlayabilirsin)
  final List<GlucoseSample> _allSamples = [];

  late DateTime _start;
  late DateTime _end;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _start = _end.subtract(const Duration(days: 13));

    _seedFakeDataIfEmpty();
  }

  void _seedFakeDataIfEmpty() {
    if (_allSamples.isNotEmpty) return;

    final rng = Random(7);
    final start = DateTime.now().subtract(const Duration(days: 30));

    // 15 dakikada bir veri
    for (int i = 0; i < 30 * 24 * 4; i++) {
      final t = start.add(Duration(minutes: 15 * i));
      final base = 110 + 20 * sin(i / 25.0);
      final noise = rng.nextDouble() * 14 - 7;
      final v = (base + noise).clamp(55, 240).toDouble();
      _allSamples.add(GlucoseSample(ts: t, mgdl: v));
    }
  }

  List<GlucoseSample> get _rangeSamples {
    final list = _allSamples
        .where((s) => !s.ts.isBefore(_start) && !s.ts.isAfter(_end))
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return list;
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (start == null) return;

    final end = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: start,
      lastDate: DateTime.now(),
    );
    if (end == null) return;

    setState(() {
      _start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      _end = DateTime(end.year, end.month, end.day, 23, 59, 59);
    });
  }

  Future<void> _openPdfPreview() async {
    final samples = _rangeSamples;
    if (samples.length < 5) {
      _toast("Not enough glucose data in this range (need at least a few samples).");
      return;
    }

    setState(() => _loading = true);

    try {
      final series = samples.map((e) => e.mgdl).toList();

      final mean = _mean(series);
      final sd = _sd(series, mean);
      final cv = mean == 0 ? 0.0 : (sd / mean) * 100.0;

      final gmi = _gmi(mean);
      final tir = _tir(series);
      final tbr = _tbr(series);
      final tar = _tar(series);

      final numbers = ReportNumbers(
        start: _start,
        end: _end,
        mean: mean,
        sd: sd,
        cv: cv,
        gmi: gmi,
        tir: tir,
        tbr: tbr,
        tar: tar,
        sampleCount: series.length,
      );

      final pdfBytes = await ReportPdfBuilder.build(numbers: numbers, series: series);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: _fileNameFor(numbers),
          ),
        ),
      );
    } catch (e) {
      _toast("Report creation failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fileNameFor(ReportNumbers n) {
    final df = DateFormat("yyyy-MM-dd");
    return "DermaGly_Report_${df.format(n.start)}_${df.format(n.end)}.pdf";
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("dd MMM yyyy");
    final rangeLabel = "${df.format(_start)} - ${df.format(_end)}";
    final samplesCount = _rangeSamples.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("AGP Report", style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Report Range", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(rangeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text("Change"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Samples in range: $samplesCount",
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Glucose Statistics", style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 10),
                _HintRow(
                  title: "AGP (Ambulatory Glucose Profile)",
                  desc: "A standardized summary of glucose patterns for a selected time range.",
                ),
                SizedBox(height: 10),
                _HintRow(
                  title: "GMI",
                  desc: "Estimated HbA1c derived from mean glucose (approximation).",
                ),
                SizedBox(height: 10),
                _HintRow(
                  title: "Time in Range (TIR)",
                  desc: "Percent of readings between 70–180 mg/dL.",
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _openPdfPreview,
              icon: _loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_loading ? "Creating report..." : "Report"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const ReportPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B3FF2),
        elevation: 0,
        title: const Text("Report Preview", style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: PdfPreview(
        maxPageWidth: 760, // web’de daha stabil
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: fileName,
        build: (_) async => pdfBytes,
      ),
    );
  }
}

/// -------------------------
/// PDF Builder (HATASIZ - CustomPainter YOK)
/// -------------------------
class ReportPdfBuilder {
  static Future<Uint8List> build({
    required ReportNumbers numbers,
    required List<double> series,
  }) async {
    final doc = pw.Document();

    final logo = await imageFromAssetBundle('assets/images/logo.png');
    final df = DateFormat("dd MMM yyyy");

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        build: (ctx) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 52,
                  height: 52,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(14),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DermaGly Glucose Report (AGP Summary)",
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "${df.format(numbers.start)} — ${df.format(numbers.end)}",
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 14),

            // Top stats
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Row(
                children: [
                  _miniStat("Average Glucose", "${numbers.mean.toStringAsFixed(1)} mg/dL"),
                  pw.SizedBox(width: 10),
                  _miniStat("GMI", "${numbers.gmi.toStringAsFixed(1)} %"),
                  pw.SizedBox(width: 10),
                  _miniStat("SD / CV", "${numbers.sd.toStringAsFixed(1)} / ${numbers.cv.toStringAsFixed(1)}%"),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Time in range bar (layout-only)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Time in Range (sample-based)",
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),

                  // ✅ Kayma yok: Row + Expanded flex
                  _tirBar(numbers),

                  pw.SizedBox(height: 10),
                  pw.Text(
                    "TIR 70–180: ${numbers.tir.toStringAsFixed(1)}%   •   "
                        "TBR <70: ${numbers.tbr.toStringAsFixed(1)}%   •   "
                        "TAR >180: ${numbers.tar.toStringAsFixed(1)}%",
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Notes
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Text(
                "Notes: Metrics are computed from available glucose samples in the selected range. "
                    "If sampling interval is irregular, percentages are approximate. "
                    "Total samples: ${numbers.sampleCount}.",
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),

            pw.SizedBox(height: 10),

            // Raw summary (kısaltılmış)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Raw summary (sample values)",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _rawSummary(series),
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _miniStat(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tirBar(ReportNumbers n) {
    // clamp + normalize
    final tbr = n.tbr.clamp(0.0, 100.0);
    final tir = n.tir.clamp(0.0, 100.0);
    final tar = n.tar.clamp(0.0, 100.0);

    final sum = max(0.0001, tbr + tir + tar);
    final tbrN = (tbr / sum) * 100.0;
    final tirN = (tir / sum) * 100.0;
    final tarN = (tar / sum) * 100.0;

    int flexOf(double p) => max(1, (p * 10).round()); // 0.1% precision-ish

    final flexLow = flexOf(tbrN);
    final flexMid = flexOf(tirN);
    final flexHigh = flexOf(tarN);

    return pw.Container(
      height: 22,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: flexLow,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.red600,
                borderRadius: const pw.BorderRadius.horizontal(left: pw.Radius.circular(12)),
              ),
            ),
          ),
          pw.Expanded(
            flex: flexMid,
            child: pw.Container(color: PdfColors.green600),
          ),
          pw.Expanded(
            flex: flexHigh,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.orange600,
                borderRadius: const pw.BorderRadius.horizontal(right: pw.Radius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _rawSummary(List<double> series) {
    final head = series.take(60).map((e) => e.toStringAsFixed(1)).join(", ");
    if (series.length <= 60) return head;

    final tail = series.skip(max(0, series.length - 60)).map((e) => e.toStringAsFixed(1)).join(", ");
    return "$head … $tail";
  }
}

/// -------------------------
/// Numbers + math helpers
/// -------------------------
class ReportNumbers {
  final DateTime start;
  final DateTime end;

  final double mean;
  final double sd;
  final double cv;
  final double gmi;

  final double tir; // %
  final double tbr; // %
  final double tar; // %

  final int sampleCount;

  ReportNumbers({
    required this.start,
    required this.end,
    required this.mean,
    required this.sd,
    required this.cv,
    required this.gmi,
    required this.tir,
    required this.tbr,
    required this.tar,
    required this.sampleCount,
  });
}

double _mean(List<double> xs) {
  if (xs.isEmpty) return 0.0;
  final s = xs.fold<double>(0.0, (a, b) => a + b);
  return s / xs.length;
}

double _sd(List<double> xs, double mean) {
  if (xs.length < 2) return 0.0;
  final v = xs.map((x) => (x - mean) * (x - mean)).fold<double>(0.0, (a, b) => a + b) / (xs.length - 1);
  return sqrt(v);
}

// GMI approx: 3.31 + 0.02392 * mean(mg/dL)
double _gmi(double meanMgDl) => 3.31 + 0.02392 * meanMgDl;

double _tir(List<double> xs) {
  if (xs.isEmpty) return 0.0;
  final inRange = xs.where((x) => x >= 70 && x <= 180).length;
  return (inRange / xs.length) * 100.0;
}

double _tbr(List<double> xs) {
  if (xs.isEmpty) return 0.0;
  final low = xs.where((x) => x < 70).length;
  return (low / xs.length) * 100.0;
}

double _tar(List<double> xs) {
  if (xs.isEmpty) return 0.0;
  final high = xs.where((x) => x > 180).length;
  return (high / xs.length) * 100.0;
}

/// -------------------------
/// UI helpers
/// -------------------------
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HintRow extends StatelessWidget {
  final String title;
  final String desc;

  const _HintRow({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
