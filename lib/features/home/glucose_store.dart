import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GlucoseSample {
  final DateTime ts;
  final double mgdl;

  GlucoseSample({required this.ts, required this.mgdl});

  Map<String, dynamic> toJson() => {
    "ts": ts.toIso8601String(),
    "mgdl": mgdl,
  };

  factory GlucoseSample.fromJson(Map<String, dynamic> j) => GlucoseSample(
    ts: DateTime.parse(j["ts"] as String),
    mgdl: (j["mgdl"] as num).toDouble(),
  );
}

class GlucoseStore {
  static const _kKey = "glucose_samples_v1";

  static Future<List<GlucoseSample>> getAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(GlucoseSample.fromJson).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
  }

  static Future<void> saveAll(List<GlucoseSample> samples) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(samples.map((e) => e.toJson()).toList());
    await sp.setString(_kKey, raw);
  }

  /// Add one sample (dedupe by timestamp+value lightly)
  static Future<void> addSample({required double mgdl, required DateTime ts}) async {
    final all = await getAll();
    // keep only last 30 days to avoid huge storage
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final trimmed = all.where((s) => s.ts.isAfter(cutoff)).toList();

    final candidate = GlucoseSample(ts: ts.toUtc(), mgdl: mgdl);
    // simple dedupe
    final exists = trimmed.any((s) =>
    s.ts.toUtc().difference(candidate.ts).inSeconds.abs() <= 1 &&
        (s.mgdl - candidate.mgdl).abs() < 0.01);

    if (!exists) trimmed.add(candidate);

    trimmed.sort((a, b) => a.ts.compareTo(b.ts));
    await saveAll(trimmed);
  }

  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
  }
}
