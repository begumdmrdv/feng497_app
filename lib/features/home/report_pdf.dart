import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportNumbers {
  final DateTime start;
  final DateTime end;

  final double mean;
  final double sd;
  final double cv;
  final double gmi;

  final double tir; // 70-180
  final double tbr; // <70
  final double tar; // >180

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

    // Logo (optional)
    pw.ImageProvider? logo;
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // ignore if asset not found
    }

    final df = DateFormat("d MMM yyyy");

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null)
                    pw.Container(
                      width: 56,
                      height: 56,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(14),
                        boxShadow: const [
                          pw.BoxShadow(
                            blurRadius: 10,
                            offset: PdfPoint(0, 6),
                            color: PdfColor(0, 0, 0, 0.12),
                          )
                        ],
                      ),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DermaGly — Glucose Report (AGP Summary)",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "${df.format(n.start)}  →  ${df.format(n.end)}",
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _kpi("Average Glucose", "${n.mean.toStringAsFixed(1)} mg/dL"),
                    _kpi("GMI", "${n.gmi.toStringAsFixed(1)} %"),
                    _kpi("SD / CV", "${n.sd.toStringAsFixed(1)} / ${n.cv.toStringAsFixed(1)}%"),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(14),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Time in Range (sample-based)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    _bar("TIR 70–180", n.tir, PdfColors.green600),
                    pw.SizedBox(height: 6),
                    _bar("TBR <70", n.tbr, PdfColors.orange600),
                    pw.SizedBox(height: 6),
                    _bar("TAR >180", n.tar, PdfColors.red600),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      "Notes: Values are computed from available glucose samples. If sampling interval is regular, percentages approximate time-based metrics.",
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              pw.Text(
                "Raw summary (last ${series.length} samples)",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                series.take(60).map((e) => e.toStringAsFixed(1)).join(", ") + (series.length > 60 ? " …" : ""),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _kpi(String title, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _bar(String label, double pct, PdfColor color) {
    final p = pct.clamp(0, 100);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.Text("${p.toStringAsFixed(1)}%", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          height: 10,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(99),
          ),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              width: (p / 100) * 420,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
