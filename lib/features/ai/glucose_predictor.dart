import 'dart:math';

/// ✅ NEW: Unified model for BOTH simulator + live mapping (single pipeline)
class SensorFrame {
  final DateTime ts;
  final double sweatRate;
  final double temperature;
  final double ph;
  final double current;

  const SensorFrame({
    required this.ts,
    required this.sweatRate,
    required this.temperature,
    required this.ph,
    required this.current,
  });
}

class SweatReading {
  final DateTime ts;
  final double sweatRate;
  final double temperature;
  final double ph;
  final double current;

  SweatReading({
    required this.ts,
    required this.sweatRate,
    required this.temperature,
    required this.ph,
    required this.current,
  });

  /// ✅ NEW: Bridge to SensorFrame
  SensorFrame toFrame() => SensorFrame(
    ts: ts,
    sweatRate: sweatRate,
    temperature: temperature,
    ph: ph,
    current: current,
  );

  /// ✅ NEW: From SensorFrame
  static SweatReading fromFrame(SensorFrame f) => SweatReading(
    ts: f.ts,
    sweatRate: f.sweatRate,
    temperature: f.temperature,
    ph: f.ph,
    current: f.current,
  );
}

class CalibrationParams {
  final double a;
  final double b;

  const CalibrationParams({required this.a, required this.b});

  static const defaultParams = CalibrationParams(a: 1.0, b: 0.0);

  double apply(double baseMgDl) => a * baseMgDl + b;
}

class GlucosePrediction {
  final double mgDl;
  final Trend trend;
  final double confidence; // 0..1
  final RiskLevel risk30m;

  // ✅ NEW: explanation for UI / report
  final String? explain;

  GlucosePrediction({
    required this.mgDl,
    required this.trend,
    required this.confidence,
    required this.risk30m,
    this.explain,
  });
}

enum Trend { up, flat, down }
enum RiskLevel { low, medium, high }

class GlucosePredictor {
  final int windowSize;

  final List<double> _w;
  final double _bias;

  GlucosePredictor({
    this.windowSize = 12,
    List<double>? weights,
    double? bias,
  })  : _w = weights ??
      const [
        12.0, // mean_sweatRate
        -1.5, // mean_temp
        -8.0, // mean_ph
        0.08, // mean_current
        20.0, // slope_current
        10.0, // delta_current (last-first)
      ],
        _bias = bias ?? 140.0;

  /// Original API (backwards compatible)
  GlucosePrediction? predict(
      List<SweatReading> history, {
        CalibrationParams calibration = CalibrationParams.defaultParams,
        int sampleMinutes = 5, // ✅ NEW: for time-aware risk
        bool withExplain = true, // ✅ NEW
      }) {
    if (history.length < max(4, windowSize ~/ 3)) return null;

    final recent = history.length <= windowSize
        ? history
        : history.sublist(history.length - windowSize);

    final cleaned = _cleanRecent(recent);
    if (cleaned.length < max(4, windowSize ~/ 3)) return null;

    final x = _extractFeatures(cleaned);
    var base = _predictBase(x).clamp(40.0, 400.0);
    final finalPred = calibration.apply(base).clamp(40.0, 400.0);

    final slopePerMin = _slopePerMinuteFromRecent(cleaned, sampleMinutes);
    final trend = _trendFromSlopePerMin(slopePerMin);

    final conf = _confidenceHeuristic(cleaned);

    final risk = _riskHeuristic30m(
      currentMgDl: finalPred,
      slopePerMin: slopePerMin,
    );

    return GlucosePrediction(
      mgDl: finalPred,
      trend: trend,
      confidence: conf,
      risk30m: risk,
      explain: withExplain
          ? _explain(
        finalPred,
        slopePerMin,
        conf,
        risk,
        sampleMinutes,
        calibration,
      )
          : null,
    );
  }

  /// ✅ NEW: Predict directly from SensorFrames (single unified pipeline)
  GlucosePrediction? predictFromFrames(
      List<SensorFrame> frames, {
        CalibrationParams calibration = CalibrationParams.defaultParams,
        int sampleMinutes = 5,
        bool withExplain = true,
      }) {
    if (frames.length < max(4, windowSize ~/ 3)) return null;
    final readings = frames.map(SweatReading.fromFrame).toList();
    return predict(
      readings,
      calibration: calibration,
      sampleMinutes: sampleMinutes,
      withExplain: withExplain,
    );
  }

  List<double> _extractFeatures(List<SweatReading> w) {
    double mean(double Function(SweatReading r) f) =>
        w.map(f).reduce((a, b) => a + b) / w.length;

    final meanSweat = mean((r) => r.sweatRate);
    final meanTemp = mean((r) => r.temperature);
    final meanPh = mean((r) => r.ph);
    final meanCur = mean((r) => r.current);

    final curSeries = w.map((r) => r.current).toList();
    final slopeCur = _slope(curSeries);
    final deltaCur = w.last.current - w.first.current;

    // ✅ NEW: defensive clamp for features (prevents blow-ups)
    double safe(double v, double lo, double hi) => v.isNaN || v.isInfinite ? 0.0 : v.clamp(lo, hi).toDouble();

    return [
      safe(meanSweat / 10.0, 0.0, 10.0),
      safe(meanTemp / 40.0, 0.0, 2.0),
      safe(meanPh / 14.0, 0.0, 1.5),
      safe(meanCur / 1000.0, -10.0, 10.0),
      safe(slopeCur / 1000.0, -10.0, 10.0),
      safe(deltaCur / 1000.0, -10.0, 10.0),
    ];
  }

  double _predictBase(List<double> x) {
    if (x.length != _w.length) {
      throw StateError("Feature length ${x.length} != weight length ${_w.length}");
    }
    double s = _bias;
    for (var i = 0; i < x.length; i++) {
      s += _w[i] * x[i];
    }
    return s;
  }

  /// ✅ NEW: convert slope to per-minute slope if sampling interval is known
  double _slopePerMinuteFromRecent(List<SweatReading> recent, int sampleMinutes) {
    if (recent.length < 2) return 0.0;
    if (sampleMinutes <= 0) return 0.0;

    // Use last 4 points for slope
    final last = recent.length <= 4 ? recent : recent.sublist(recent.length - 4);
    final sIndex = _slope(last.map((r) => r.current).toList());

    // index-step slope -> per-minute (approx)
    return sIndex / sampleMinutes;
  }

  Trend _trendFromSlopePerMin(double sPerMin) {
    // Thresholds in mg/dL per minute (tune)
    if (sPerMin > 0.25) return Trend.up;
    if (sPerMin < -0.25) return Trend.down;
    return Trend.flat;
  }

  double _confidenceHeuristic(List<SweatReading> recent) {
    final cur = recent.map((r) => r.current).toList();
    final sd = _stddev(cur);

    if (sd < 3.0) return 0.9;
    if (sd < 8.0) return 0.7;
    if (sd < 15.0) return 0.5;
    return 0.35;
  }

  /// ✅ NEW: 30-min risk based on a 30-min projection (time-aware)
  RiskLevel _riskHeuristic30m({
    required double currentMgDl,
    required double slopePerMin,
  }) {
    final proj30 = currentMgDl + slopePerMin * 30.0;

    if (proj30 < 70) return RiskLevel.high;
    if (proj30 < 85) return RiskLevel.medium;

    if (proj30 > 250) return RiskLevel.high;
    if (proj30 > 190) return RiskLevel.medium;

    // fallback: if already extreme + moving worse
    if (currentMgDl <= 80 && slopePerMin < -0.25) return RiskLevel.high;
    if (currentMgDl >= 220 && slopePerMin > 0.25) return RiskLevel.high;

    return RiskLevel.low;
  }

  double _slope(List<double> y) {
    final n = y.length;
    if (n < 2) return 0;

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

  double _stddev(List<double> v) {
    if (v.length < 2) return 0;
    final m = v.reduce((a, b) => a + b) / v.length;
    final varSum = v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b);
    return sqrt(varSum / (v.length - 1));
  }

  // ✅ NEW: Remove bad sensor readings (NaN/inf), keeps pipeline stable.
  List<SweatReading> _cleanRecent(List<SweatReading> recent) {
    bool ok(double v) => !(v.isNaN || v.isInfinite);
    return recent.where((r) {
      return ok(r.sweatRate) && ok(r.temperature) && ok(r.ph) && ok(r.current);
    }).toList();
  }

  // ✅ NEW: short explanation for UI / report
  String _explain(
      double mgDl,
      double slopePerMin,
      double conf,
      RiskLevel risk,
      int sampleMinutes,
      CalibrationParams calib,
      ) {
    final slopeText = slopePerMin >= 0
        ? "+${slopePerMin.toStringAsFixed(2)}"
        : slopePerMin.toStringAsFixed(2);

    final trend = slopePerMin > 0.25
        ? "rising"
        : (slopePerMin < -0.25 ? "falling" : "stable");

    return "AI: sweat→glucose linear model + calibration (a=${calib.a.toStringAsFixed(2)}, b=${calib.b.toStringAsFixed(1)}). "
        "Trend=$trend (slope $slopeText mg/dL/min, ~${sampleMinutes}min sampling). "
        "Confidence=${(conf * 100).round()}%. Risk(30m)=${risk.name}.";
  }
}
