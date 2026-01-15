import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum GlucoseSource { unknown, live, ai, manual }

extension GlucoseSourceX on GlucoseSource {
  String get key => name;

  static GlucoseSource fromKey(String? s) {
    if (s == null) return GlucoseSource.unknown;
    for (final v in GlucoseSource.values) {
      if (v.name == s) return v;
    }
    return GlucoseSource.unknown;
  }
}

class GlucoseSample {
  final DateTime ts; // stored as UTC
  final double mgdl;
  final GlucoseSource source;

  GlucoseSample({
    required this.ts,
    required this.mgdl,
    this.source = GlucoseSource.unknown,
  });

  Map<String, dynamic> toJson() => {
    "ts": ts.toUtc().toIso8601String(),
    "mgdl": mgdl,
    "source": source.key,
  };

  factory GlucoseSample.fromJson(Map<String, dynamic> j) {
    final tsRaw = j["ts"];
    final mgRaw = j["mgdl"];
    final srcRaw = j["source"];

    final ts = (tsRaw is String) ? DateTime.parse(tsRaw).toUtc() : DateTime.now().toUtc();
    final mgdl = (mgRaw is num) ? mgRaw.toDouble() : 0.0;

    // Backward compatible: old saved items won't have "source"
    final source = GlucoseSourceX.fromKey(srcRaw is String ? srcRaw : null);

    return GlucoseSample(ts: ts, mgdl: mgdl, source: source);
  }
}

class GlucoseStore {
  static const _kKey = "glucose_samples_v1";

  /// Safety: parse list items even if they are Map<dynamic,dynamic>
  static Map<String, dynamic> _asStringKeyMap(dynamic m) {
    if (m is Map<String, dynamic>) return m;
    if (m is Map) {
      return m.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  static Future<List<GlucoseSample>> getAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final samples = <GlucoseSample>[];
      for (final item in decoded) {
        final map = _asStringKeyMap(item);
        if (map.isEmpty) continue;
        samples.add(GlucoseSample.fromJson(map));
      }

      samples.sort((a, b) => a.ts.compareTo(b.ts));
      return samples;
    } catch (_) {
      // If storage is corrupted, don't crash the app
      return [];
    }
  }

  static Future<void> saveAll(List<GlucoseSample> samples) async {
    final sp = await SharedPreferences.getInstance();
    final normalized = samples
        .map((e) => GlucoseSample(ts: e.ts.toUtc(), mgdl: e.mgdl, source: e.source))
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    final raw = jsonEncode(normalized.map((e) => e.toJson()).toList());
    await sp.setString(_kKey, raw);
  }

  /// Add one sample (dedupe by timestamp+value lightly)
  /// Default source is unknown for backward compatibility.
  static Future<void> addSample({
    required double mgdl,
    required DateTime ts,
    GlucoseSource source = GlucoseSource.unknown,
    int keepDays = 30,
  }) async {
    final all = await getAll();

    // keep only last N days to avoid huge storage
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: keepDays));
    final trimmed = all.where((s) => s.ts.isAfter(cutoff)).toList();

    final candidate = GlucoseSample(ts: ts.toUtc(), mgdl: mgdl, source: source);

    // simple dedupe (same second + almost same value)
    final exists = trimmed.any((s) =>
    s.ts.toUtc().difference(candidate.ts).inSeconds.abs() <= 1 &&
        (s.mgdl - candidate.mgdl).abs() < 0.01 &&
        s.source == candidate.source);

    if (!exists) trimmed.add(candidate);

    trimmed.sort((a, b) => a.ts.compareTo(b.ts));
    await saveAll(trimmed);
  }

  /// Add many samples efficiently (useful for importing / simulator bursts)
  static Future<void> addMany(
      List<GlucoseSample> samples, {
        int keepDays = 30,
      }) async {
    if (samples.isEmpty) return;

    final all = await getAll();
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: keepDays));
    final base = all.where((s) => s.ts.isAfter(cutoff)).toList();

    // Normalize incoming to UTC + sort
    final incoming = samples
        .map((s) => GlucoseSample(ts: s.ts.toUtc(), mgdl: s.mgdl, source: s.source))
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    // Build a quick index for dedupe
    bool exists(GlucoseSample cand) => base.any((s) =>
    s.ts.difference(cand.ts).inSeconds.abs() <= 1 &&
        (s.mgdl - cand.mgdl).abs() < 0.01 &&
        s.source == cand.source);

    for (final s in incoming) {
      if (!exists(s)) base.add(s);
    }

    base.sort((a, b) => a.ts.compareTo(b.ts));
    await saveAll(base);
  }

  /// Get samples in [from, to] inclusive-ish
  static Future<List<GlucoseSample>> getRange({
    required DateTime from,
    required DateTime to,
    GlucoseSource? source,
  }) async {
    final all = await getAll();
    final f = from.toUtc();
    final t = to.toUtc();

    final filtered = all.where((s) {
      final okTime = !s.ts.isBefore(f) && !s.ts.isAfter(t);
      final okSource = source == null ? true : s.source == source;
      return okTime && okSource;
    }).toList();

    filtered.sort((a, b) => a.ts.compareTo(b.ts));
    return filtered;
  }

  /// Remove older than [days] days.
  static Future<void> prune({int days = 30}) async {
    final all = await getAll();
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    final kept = all.where((s) => s.ts.isAfter(cutoff)).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    await saveAll(kept);
  }

  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
  }
}

// ---------------------------------------------------------------------
// ✅ Coach Tips shared store (Diary ↔ Dashboard) (NO BACKEND)
// ---------------------------------------------------------------------
//
// Why this exists:
// - DiaryScreen produces "AI Coach Tips" based on meal logs / patterns.
// - DashboardScreen needs to display the same tips on the Home tab.
// - IndexedStack keeps tabs alive, so we use SharedPreferences as a simple
//   cross-screen store and poll for updates.
//
// Storage format (JSON):
// {
//   "updatedAt": 1730000000000,
//   "tips": { "food": "...", "exercise": "...", "medicine": "..." }
// }
//
class CoachTipsStore {
  static const String _kKey = "coach_tips_v1";

  static const List<String> _kTypes = <String>["food", "exercise", "medicine"];

  static Future<void> save({
    required String food,
    required String exercise,
    required String medicine,
    DateTime? now,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      "updatedAt": (now ?? DateTime.now()).millisecondsSinceEpoch,
      "tips": <String, String>{
        "food": food,
        "exercise": exercise,
        "medicine": medicine,
      },
    };
    await sp.setString(_kKey, jsonEncode(payload));
  }

  /// Load latest tips. Returns:
  /// - updatedAt epoch ms (0 if missing)
  /// - tips map with keys: food/exercise/medicine (may be missing)
  static Future<CoachTipsSnapshot> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) {
      return const CoachTipsSnapshot(updatedAtMs: 0, tips: <String, String>{});
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const CoachTipsSnapshot(updatedAtMs: 0, tips: <String, String>{});
      }

      final updatedAt = decoded["updatedAt"];
      final updatedAtMs = (updatedAt is num) ? updatedAt.toInt() : 0;

      final tipsRaw = decoded["tips"];
      final tips = <String, String>{};
      if (tipsRaw is Map) {
        for (final k in _kTypes) {
          final v = tipsRaw[k];
          if (v is String && v.trim().isNotEmpty) tips[k] = v;
        }
      }

      return CoachTipsSnapshot(updatedAtMs: updatedAtMs, tips: tips);
    } catch (_) {
      return const CoachTipsSnapshot(updatedAtMs: 0, tips: <String, String>{});
    }
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
  }
}

class CoachTipsSnapshot {
  final int updatedAtMs;
  final Map<String, String> tips;
  const CoachTipsSnapshot({required this.updatedAtMs, required this.tips});
}
