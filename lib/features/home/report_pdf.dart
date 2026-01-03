import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportNumbers {
  final DateTime start;
  final DateTime end;

  final double mean;
  final double sd;
  final double cv;
  final double gmi;

  final double tir;
  final double tbr;
  final double tar;

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
  });
}

class ReportPdfBuilder {
  static Future<Uint8List> build({
    required ReportNumbers n,
    required List<double> series,
  }) async {
    final doc = pw.Document();

    // ✅ logo asset (pubspec: assets/images/logo.png)
    final logo = await imageFromAssetBundle('assets/images/logo.png');

    final df = DateFormat("dd MMM yyyy");
    final meanStr = n.mean.toStringAsFixed(1);
    final sdStr = n.sd.toStringAsFixed(1);
    final cvStr = n.cv.toStringAsFixed(1);
    final gmiStr = n.gmi.toStringAsFixed(1);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        build: (_) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 58,
                height: 58,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(16),
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
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "${df.format(n.start)} — ${df.format(n.end)}",
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // KPI strip
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Row(
              children: [
                _kpi("Average Glucose", "$meanStr mg/dL"),
                pw.SizedBox(width: 10),
                _kpi("GMI", "$gmiStr %"),
                pw.SizedBox(width: 10),
                _kpi("SD / CV", "$sdStr / $cvStr%"),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // TIR card
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

                // ✅ BAR = sadece layout (no painter) => kayma azalır
                _tirBar(n.tbr, n.tir, n.tar),

                pw.SizedBox(height: 10),
                pw.Text(
                  "TIR 70–180: ${n.tir.toStringAsFixed(1)}%   •   "
                      "TBR <70: ${n.tbr.toStringAsFixed(1)}%   •   "
                      "TAR >180: ${n.tar.toStringAsFixed(1)}%",
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  "AGP is a standardized CGM summary. GMI is derived from mean glucose (approx.).",
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Raw summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Raw summary (sample values)",
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _rawSummary(series),
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _kpi(String title, String value) {
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

  static pw.Widget _tirBar(double tbr, double tir, double tar) {
    tbr = tbr.clamp(0.0, 100.0);
    tir = tir.clamp(0.0, 100.0);
    tar = tar.clamp(0.0, 100.0);

    final sum = max(0.0001, tbr + tir + tar);
    final tbrN = (tbr / sum) * 100.0;
    final tirN = (tir / sum) * 100.0;
    final tarN = (tar / sum) * 100.0;

    int flex(double p) => max(1, (p * 10).round()); // küçük yüzdelerde bile görünür

    final flexLow = flex(tbrN);
    final flexMid = flex(tirN);
    final flexHigh = flex(tarN);

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
    if (series.isEmpty) return "—";
    final head = series.take(70).map((e) => e.toStringAsFixed(1)).join(", ");
    if (series.length <= 70) return head;

    final tail = series.skip(max(0, series.length - 40)).map((e) => e.toStringAsFixed(1)).join(", ");
    return "$head … $tail";
  }
}
