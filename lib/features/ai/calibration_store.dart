import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'glucose_predictor.dart';

class CalibrationStore {
  static const _keyA = 'calib_a';
  static const _keyB = 'calib_b';

  // ✅ NEW: store last calibration time + a small history (for audit/debug/demo)
  static const _keyLastTs = 'calib_last_ts';
  static const _keyHistory = 'calib_history_v1';

  Future<CalibrationParams> load() async {
    final sp = await SharedPreferences.getInstance();
    final a = sp.getDouble(_keyA) ?? 1.0;
    final b = sp.getDouble(_keyB) ?? 0.0;
    return CalibrationParams(a: a, b: b);
  }

  Future<void> save(CalibrationParams p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_keyA, p.a);
    await sp.setDouble(_keyB, p.b);
    await sp.setString(_keyLastTs, DateTime.now().toUtc().toIso8601String());
  }

  /// ✅ NEW: get last calibration time (nullable)
  Future<DateTime?> getLastCalibrationTime() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_keyLastTs);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  /// ✅ NEW: reset calibration back to defaults (a=1, b=0) + clear history
  Future<void> reset() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_keyA, 1.0);
    await sp.setDouble(_keyB, 0.0);
    await sp.remove(_keyLastTs);
    await sp.remove(_keyHistory);
  }

  /// ✅ Existing: very simple update using one ground-truth point:
  /// want: final = a*base + b -> match true
  /// We'll adjust b mostly.
  Future<CalibrationParams> updateWithOnePoint({
    required double basePred,
    required double trueMgDl,
    DateTime? ts,
  }) async {
    // Guards
    if (basePred.isNaN || basePred.isInfinite || trueMgDl.isNaN || trueMgDl.isInfinite) {
      // keep existing calibration unchanged
      return load();
    }

    final current = await load();
    final newB = trueMgDl - current.a * basePred;
    final updated = CalibrationParams(a: current.a, b: newB);

    await save(updated);
    await _appendHistory(
      CalibrationPoint(
        ts: (ts ?? DateTime.now()).toUtc(),
        basePred: basePred,
        trueMgDl: trueMgDl,
        usedA: updated.a,
        usedB: updated.b,
        method: "one_point_bias",
      ),
    );

    return updated;
  }

  /// ✅ NEW: Fit (a,b) using multiple calibration points (least squares)
  ///
  /// We solve: true ≈ a*base + b
  /// - If you provide 2+ points, we estimate both a and b
  /// - If points are degenerate, fallback to one-point bias update.
  Future<CalibrationParams> fitWithPoints({
    required List<CalibrationPair> points,
    DateTime? ts,
  }) async {
    final clean = points
        .where((p) =>
    !(p.basePred.isNaN || p.basePred.isInfinite || p.trueMgDl.isNaN || p.trueMgDl.isInfinite))
        .toList();

    if (clean.isEmpty) return load();

    // If only one point -> use existing one-point logic
    if (clean.length == 1) {
      return updateWithOnePoint(basePred: clean.first.basePred, trueMgDl: clean.first.trueMgDl, ts: ts);
    }

    // Least squares for y = a*x + b
    final xs = clean.map((p) => p.basePred).toList();
    final ys = clean.map((p) => p.trueMgDl).toList();

    final meanX = xs.reduce((a, b) => a + b) / xs.length;
    final meanY = ys.reduce((a, b) => a + b) / ys.length;

    double num = 0.0;
    double den = 0.0;
    for (int i = 0; i < xs.length; i++) {
      final dx = xs[i] - meanX;
      num += dx * (ys[i] - meanY);
      den += dx * dx;
    }

    // Degenerate X (all base predictions same) => fallback
    if (den.abs() < 1e-9) {
      // just bias shift using average
      final baseAvg = meanX;
      final trueAvg = meanY;
      return updateWithOnePoint(basePred: baseAvg, trueMgDl: trueAvg, ts: ts);
    }

    var a = num / den;
    var b = meanY - a * meanX;

    // ✅ Defensive clamp: avoid insane calibration (you can tune these)
    a = a.clamp(0.2, 5.0).toDouble();
    b = b.clamp(-200.0, 200.0).toDouble();

    final updated = CalibrationParams(a: a, b: b);
    await save(updated);

    await _appendHistory(
      CalibrationPoint(
        ts: (ts ?? DateTime.now()).toUtc(),
        basePred: meanX,
        trueMgDl: meanY,
        usedA: updated.a,
        usedB: updated.b,
        method: "least_squares_${clean.length}pts",
      ),
    );

    return updated;
  }

  /// ✅ NEW: Read history (last N points)
  Future<List<CalibrationPoint>> getHistory({int limit = 20}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_keyHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final pts = list.map(CalibrationPoint.fromJson).toList();
      pts.sort((a, b) => a.ts.compareTo(b.ts));
      if (pts.length <= limit) return pts;
      return pts.sublist(pts.length - limit);
    } catch (_) {
      return [];
    }
  }

  Future<void> _appendHistory(CalibrationPoint p) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await getHistory(limit: 200);

    final merged = [...existing, p]
      ..sort((a, b) => a.ts.compareTo(b.ts));

    // keep at most 200
    final trimmed = merged.length <= 200 ? merged : merged.sublist(merged.length - 200);

    await sp.setString(
      _keyHistory,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }
}

/// ✅ NEW: a simple pair used for fitting
class CalibrationPair {
  final double basePred;
  final double trueMgDl;

  const CalibrationPair({required this.basePred, required this.trueMgDl});
}

/// ✅ NEW: stored calibration audit point
class CalibrationPoint {
  final DateTime ts;
  final double basePred;
  final double trueMgDl;

  // what calibration was applied/saved after this update
  final double usedA;
  final double usedB;

  final String method;

  const CalibrationPoint({
    required this.ts,
    required this.basePred,
    required this.trueMgDl,
    required this.usedA,
    required this.usedB,
    required this.method,
  });

  Map<String, dynamic> toJson() => {
    "ts": ts.toIso8601String(),
    "basePred": basePred,
    "trueMgDl": trueMgDl,
    "usedA": usedA,
    "usedB": usedB,
    "method": method,
  };

  factory CalibrationPoint.fromJson(Map<String, dynamic> j) => CalibrationPoint(
    ts: DateTime.parse(j["ts"] as String).toUtc(),
    basePred: (j["basePred"] as num).toDouble(),
    trueMgDl: (j["trueMgDl"] as num).toDouble(),
    usedA: (j["usedA"] as num).toDouble(),
    usedB: (j["usedB"] as num).toDouble(),
    method: (j["method"] as String?) ?? "unknown",
  );
}
