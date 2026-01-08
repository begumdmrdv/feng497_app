import 'dart:math';

enum Trend { up, flat, down }
enum RiskLevel { low, medium, high }

class GlucosePrediction {
  final double mgDl;
  final Trend trend;
  final double confidence; // 0..1 (heuristic)
  final RiskLevel risk30m;

  // ✅ NEW: human-readable explanation (optional)
  final String? explain;

  const GlucosePrediction({
    required this.mgDl,
    required this.trend,
    required this.confidence,
    required this.risk30m,
    this.explain,
  });
}

/// ✅ NEW: Standard input frame for BOTH simulator + real live mapping
/// You can feed either:
/// - glucose mg/dL directly (if WS sends glucose)
/// - OR sensor features (sweatRate/temp/ph/current) + calibration elsewhere
class SensorFrame {
  final DateTime ts;
  final double? glucoseMgDl; // optional direct glucose
  final double? sweatRate;
  final double? temp;
  final double? ph;
  final double? current;

  const SensorFrame({
    required this.ts,
    this.glucoseMgDl,
    this.sweatRate,
    this.temp,
    this.ph,
    this.current,
  });
}

/// On-device "AI-ish" forecasting from glucose time-series.
/// No backend, no extra packages.
///
/// IMPORTANT:
/// This is forecasting/smoothing (not a medical model).
class GlucoseAi {
  /// Basic predictor from glucose values.
  ///
  /// Params:
  /// - window: how many latest points to use
  /// - sampleMinutes: expected sampling interval (e.g., 5 for CGM-like)
  /// - forecastMinutes: how far to project (default 5)
  static GlucosePrediction? predict(
      List<double> rawSeries, {
        int window = 12,
        int sampleMinutes = 5,
        int forecastMinutes = 5,
        bool withExplain = true,
      }) {
    final clean = _cleanSeries(rawSeries);
    if (clean.length < 4) return null;

    final w = clean.length <= window
        ? clean
        : clean.sublist(clean.length - window);

    final last = w.last;

    // Slope per "index step"
    final slopePerStep = _slope(w);

    // Convert slope to per-minute slope (approx)
    final slopePerMin = sampleMinutes <= 0 ? 0.0 : (slopePerStep / sampleMinutes);

    // Project forward forecastMinutes
    final forecast = last + slopePerMin * forecastMinutes;

    // Light smoothing to avoid jitter
    final smoothed = 0.7 * last + 0.3 * forecast;

    final trend = _trendFromSlopePerMin(slopePerMin);

    final conf = _confidenceHeuristic(w);

    // Compute 30-min risk using time-aware projection
    final risk = _riskHeuristic30m(
      currentMgDl: smoothed,
      slopePerMin: slopePerMin,
    );

    return GlucosePrediction(
      mgDl: smoothed.clamp(40.0, 400.0),
      trend: trend,
      confidence: conf,
      risk30m: risk,
      explain: withExplain ? _explain(smoothed, slopePerMin, conf, risk, sampleMinutes) : null,
    );
  }

  /// ✅ NEW: Predictor from SensorFrames (takes glucoseMgDl if present).
  /// This lets you keep ONE pipeline: simulator fills frames; live fills frames later.
  static GlucosePrediction? predictFromFrames(
      List<SensorFrame> frames, {
        int window = 12,
        int sampleMinutes = 5,
        int forecastMinutes = 5,
        bool withExplain = true,
      }) {
    if (frames.isEmpty) return null;

    // Use glucoseMgDl values if present
    final series = <double>[];
    for (final f in frames) {
      final g = f.glucoseMgDl;
      if (g == null) continue;
      series.add(g);
    }
    if (series.length < 4) return null;

    return predict(
      series,
      window: window,
      sampleMinutes: sampleMinutes,
      forecastMinutes: forecastMinutes,
      withExplain: withExplain,
    );
  }

  static Trend _trendFromSlopePerMin(double sPerMin) {
    // Thresholds in mg/dL per minute (tune)
    if (sPerMin > 0.25) return Trend.up;     // > 0.25 mg/dL/min
    if (sPerMin < -0.25) return Trend.down;  // < -0.25 mg/dL/min
    return Trend.flat;
  }

  static double _confidenceHeuristic(List<double> w) {
    // Lower noise => higher confidence
    final sd = _stddev(w);
    if (sd < 2.0) return 0.92;
    if (sd < 5.0) return 0.78;
    if (sd < 10.0) return 0.60;
    return 0.40;
  }

  /// ✅ NEW: 30-min risk based on a 30-min projection (time-aware).
  static RiskLevel _riskHeuristic30m({
    required double currentMgDl,
    required double slopePerMin,
  }) {
    // Project 30 minutes
    final proj30 = currentMgDl + slopePerMin * 30.0;

    // Low risk zone
    if (proj30 < 70) return RiskLevel.high;
    if (proj30 < 85) return RiskLevel.medium;

    // High risk zone
    if (proj30 > 250) return RiskLevel.high;
    if (proj30 > 190) return RiskLevel.medium;

    // If current already extreme + moving worse
    if (currentMgDl <= 80 && slopePerMin < -0.25) return RiskLevel.high;
    if (currentMgDl >= 220 && slopePerMin > 0.25) return RiskLevel.high;

    return RiskLevel.low;
  }

  static double _slope(List<double> y) {
    final n = y.length;
    if (n < 2) return 0;

    // x = 0..n-1
    final meanX = (n - 1) / 2.0;
    final meanY = y.reduce((a, b) => a + b) / n;

    double num = 0;
    double den = 0;
    for (var i = 0; i < n; i++) {
      final dx = i - meanX;
      num += dx * (y[i] - meanY);
      den += dx * dx;
    }
    if (den == 0) return 0;
    return num / den;
  }

  static double _stddev(List<double> v) {
    if (v.length < 2) return 0;
    final m = v.reduce((a, b) => a + b) / v.length;
    var varSum = 0.0;
    for (final x in v) {
      final d = x - m;
      varSum += d * d;
    }
    return sqrt(varSum / (v.length - 1));
  }

  // ✅ NEW: sanitize input (removes NaN/inf, clamps absurd values)
  static List<double> _cleanSeries(List<double> raw) {
    final out = <double>[];
    for (final x in raw) {
      if (x.isNaN || x.isInfinite) continue;
      // light clamp to avoid poisoning
      final v = x.clamp(20.0, 600.0).toDouble();
      out.add(v);
    }
    return out;
  }

  // ✅ NEW: short explain string (for UI / report)
  static String _explain(
      double mgDl,
      double slopePerMin,
      double conf,
      RiskLevel risk,
      int sampleMinutes,
      ) {
    final slopeText = slopePerMin >= 0
        ? "+${slopePerMin.toStringAsFixed(2)}"
        : slopePerMin.toStringAsFixed(2);

    final trend = slopePerMin > 0.25
        ? "rising"
        : (slopePerMin < -0.25 ? "falling" : "stable");

    return "AI: smoothed forecast. Trend=$trend (slope $slopeText mg/dL/min, ~${sampleMinutes}min sampling). "
        "Confidence=${(conf * 100).round()}%. Risk(30m)=${risk.name}.";
  }
}
