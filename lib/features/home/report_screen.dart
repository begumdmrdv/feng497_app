import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'glucose_store.dart';
import 'report_pdf.dart';
import 'report_preview_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // AGP default: 14 days
  int _days = 14;

  bool _loading = true;
  List<GlucoseSample> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await GlucoseStore.getAll();
    if (mounted) setState(() => _loading = false);
  }

  DateTime get _end => DateTime.now();
  DateTime get _start => DateTime.now().subtract(Duration(days: _days));

  List<GlucoseSample> get _rangeSamples {
    final s = _start;
    final e = _end;
    return _all.where((x) => x.ts.isAfter(s) && x.ts.isBefore(e)).toList();
  }

  // ---------- Metrics ----------
  double _mean(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  double _sd(List<double> v, double mean) {
    if (v.length < 2) return 0;
    final sumSq = v.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b);
    return sqrt(sumSq / (v.length - 1));
  }

  // GMI (%) = 3.31 + 0.02392 * mean(mg/dL)
  double _gmi(double meanMgdl) => 3.31 + 0.02392 * meanMgdl;

  ({double tir, double tbr, double tar}) _tir(List<double> v) {
    if (v.isEmpty) return (tir: 0, tbr: 0, tar: 0);
    final inRange = v.where((x) => x >= 70 && x <= 180).length;
    final below = v.where((x) => x < 70).length;
    final above = v.where((x) => x > 180).length;
    final n = v.length.toDouble();
    return (
    tir: (inRange / n) * 100,
    tbr: (below / n) * 100,
    tar: (above / n) * 100,
    );
  }

  Future<void> _openPdf() async {
    final samples = _rangeSamples;
    final series = samples.map((e) => e.mgdl).toList();

    if (series.length < 5) {
      _toast("Not enough glucose data in this range. (Need at least a few samples.)");
      return;
    }

    final mean = _mean(series);
    final sd = _sd(series, mean);
    final cv = mean == 0 ? 0.0 : (sd / mean) * 100.0;
    final gmi = _gmi(mean);
    final t = _tir(series);

    final numbers = ReportNumbers(
      start: _start,
      end: _end,
      mean: mean,
      sd: sd,
      cv: cv,
      gmi: gmi,
      tir: t.tir,
      tbr: t.tbr,
      tar: t.tar,
    );

    final df = DateFormat("yyyy-MM-dd");
    final fileName = "DermaGly_Report_${df.format(_start)}_${df.format(_end)}.pdf";

    final pdfFuture = ReportPdfBuilder.build(n: numbers, series: series);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewScreen(
          pdfFuture: pdfFuture,
          fileName: fileName,
        ),
      ),
    );
  }

  Future<void> _seedDemoData() async {
    await GlucoseStore.clearAll();
    final now = DateTime.now().toUtc();
    final rng = Random(42);

    for (int i = 0; i < 14 * 24; i++) {
      final ts = now.subtract(Duration(minutes: 60 * i));
      final base = 110 + 35 * sin(i / 6);
      final noise = rng.nextDouble() * 18 - 9;
      final val = (base + noise).clamp(55, 260).toDouble();
      await GlucoseStore.addSample(mgdl: val, ts: ts);
    }
    await _load();
    _toast("Demo glucose data generated ✅");
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    final dfTop = DateFormat("d MMM yyyy");
    final rangeLabel = "${dfTop.format(_start)}  →  ${dfTop.format(_end)}";

    final samples = _rangeSamples;
    final series = samples.map((e) => e.mgdl).toList();
    final mean = _mean(series);
    final sd = _sd(series, mean);
    final cv = mean == 0 ? 0.0 : (sd / mean) * 100.0;
    final gmi = series.isEmpty ? 0 : _gmi(mean);
    final t = _tir(series);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("AGP Report"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Range card (same look)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Report Range",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rangeLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${samples.length} samples",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _days,
                    borderRadius: BorderRadius.circular(14),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text("7 days")),
                      DropdownMenuItem(value: 14, child: Text("14 days")),
                      DropdownMenuItem(value: 30, child: Text("30 days")),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _days = v);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // KPI cards (2x2)
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: "Average Glucose",
                  value: series.isEmpty ? "—" : mean.toStringAsFixed(1),
                  unit: "mg/dL",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: "GMI",
                  value: series.isEmpty ? "—" : gmi.toStringAsFixed(1),
                  unit: "%",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: "SD",
                  value: series.isEmpty ? "—" : sd.toStringAsFixed(1),
                  unit: "mg/dL",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: "CV",
                  value: series.isEmpty ? "—" : cv.toStringAsFixed(1),
                  unit: "%",
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // TIR card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Time in Range (sample-based)",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _PctBar(label: "TIR 70–180", pct: t.tir, color: Colors.green),
                const SizedBox(height: 10),
                _PctBar(label: "TBR <70", pct: t.tbr, color: Colors.orange),
                const SizedBox(height: 10),
                _PctBar(label: "TAR >180", pct: t.tar, color: Colors.red),
                const SizedBox(height: 10),
                const Text(
                  "AGP is a standardized CGM summary. GMI is derived from mean glucose.",
                  style: TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Preview button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text(
                "Preview PDF",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Utility row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _load,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Refresh"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _seedDemoData,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Generate Demo Data"),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: null, // ✅ AI assistant removed
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.unit,
  });

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
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PctBar extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;

  const _PctBar({required this.label, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = pct.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(
              "${p.toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: p / 100,
            minHeight: 10,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}