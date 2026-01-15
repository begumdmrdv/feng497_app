import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ActivityCategory { walkRun, yoga, strength, cycling, hiit, other }

extension ActivityCategoryX on ActivityCategory {
  String get title {
    switch (this) {
      case ActivityCategory.walkRun:
        return "Walk / Run";
      case ActivityCategory.yoga:
        return "Yoga";
      case ActivityCategory.strength:
        return "Strength";
      case ActivityCategory.cycling:
        return "Cycling";
      case ActivityCategory.hiit:
        return "HIIT";
      case ActivityCategory.other:
        return "Other";
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityCategory.walkRun:
        return Icons.directions_walk_rounded;
      case ActivityCategory.yoga:
        return Icons.self_improvement_rounded;
      case ActivityCategory.strength:
        return Icons.fitness_center_rounded;
      case ActivityCategory.cycling:
        return Icons.directions_bike_rounded;
      case ActivityCategory.hiit:
        return Icons.flash_on_rounded;
      case ActivityCategory.other:
        return Icons.sports_gymnastics_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ActivityCategory.walkRun:
        return const Color(0xFF1F5EA8);
      case ActivityCategory.yoga:
        return const Color(0xFFCDA1FF);
      case ActivityCategory.strength:
        return const Color(0xFF7B3FF2);
      case ActivityCategory.cycling:
        return const Color(0xFF2CB67D);
      case ActivityCategory.hiit:
        return const Color(0xFFFF6B6B);
      case ActivityCategory.other:
        return const Color(0xFFFFC45C);
    }
  }
}

class ActivityEntry {
  final String id;
  final ActivityCategory category;
  final String name;
  final int minutes; // duration

  final DateTime createdAt;

  ActivityEntry({
    required this.id,
    required this.category,
    required this.name,
    required this.minutes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "category": category.index,
    "name": name,
    "minutes": minutes,
    "createdAt": createdAt.toIso8601String(),
  };

  static ActivityEntry fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: (json["id"] ?? "") as String,
      category: ActivityCategory.values[(json["category"] ?? 0) as int],
      name: (json["name"] ?? "") as String,
      minutes: (json["minutes"] as num).toInt(),
      createdAt: DateTime.parse(json["createdAt"] as String),
    );
  }
}

/// Activity screen:
/// - Like Diary: date-based tracking, persistent storage
/// - Categories with + add
/// - Program goals + progress (minutes + sessions)
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _bg = Color(0xFFF4F1E8);
  static const _purple = Color(0xFF7B3FF2);

  // User program goals (editable)
  int _goalMinutesPerWeek = 150; // WHO guideline-ish baseline
  int _goalSessionsPerWeek = 4;

  late DateTime _selectedDate;
  bool _loading = true;

  final Map<ActivityCategory, List<ActivityEntry>> _entries = {
    for (final c in ActivityCategory.values) c: <ActivityEntry>[],
  };

  // ----------------------------
  // ✅ ON-DEVICE "AI Tips" (NO BACKEND)
  // ----------------------------
  final ActivityTipsEngine _tipsEngine = ActivityTipsEngine();
  final List<ActivityTipItem> _aiTips = <ActivityTipItem>[];

  void _refreshAiTips() {
    _tipsEngine.seedIfNeeded(_aiTips);

    _tipsEngine.updateTips(
      target: _aiTips,
      date: _selectedDate,
      goalMinutesPerWeek: _goalMinutesPerWeek,
      goalSessionsPerWeek: _goalSessionsPerWeek,
      totalMinutesToday: _todayTotalMinutes,
      sessionsToday: _todaySessions,
      perCategoryMinutes: _minutesByCategory(),
      perCategorySessions: _sessionsByCategory(),
    );

    // keep short history
    if (_aiTips.length > 40) {
      _aiTips.removeRange(0, _aiTips.length - 40);
    }
  }

  Map<ActivityCategory, int> _minutesByCategory() {
    final m = <ActivityCategory, int>{};
    for (final c in ActivityCategory.values) {
      final list = _entries[c] ?? const <ActivityEntry>[];
      m[c] = list.fold<int>(0, (a, b) => a + b.minutes);
    }
    return m;
  }

  Map<ActivityCategory, int> _sessionsByCategory() {
    final m = <ActivityCategory, int>{};
    for (final c in ActivityCategory.values) {
      m[c] = (_entries[c] ?? const <ActivityEntry>[]).length;
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadAllForDate(_selectedDate);
  }

  // -----------------------
  // Keys + persistence
  // -----------------------
  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "activity_$y-$m-$day";
  }

  String _programKey() => "activity_program_settings";

  Future<void> _loadProgramSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_programKey());
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final m = decoded.map((k, v) => MapEntry(k.toString(), v));
        final minutes = (m["goalMinutesPerWeek"] as num?)?.toInt();
        final sessions = (m["goalSessionsPerWeek"] as num?)?.toInt();
        if (minutes != null && minutes > 0) _goalMinutesPerWeek = minutes;
        if (sessions != null && sessions > 0) _goalSessionsPerWeek = sessions;
      }
    } catch (_) {}
  }

  Future<void> _saveProgramSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      "goalMinutesPerWeek": _goalMinutesPerWeek,
      "goalSessionsPerWeek": _goalSessionsPerWeek,
    });
    await prefs.setString(_programKey(), payload);
  }

  Future<void> _loadAllForDate(DateTime date) async {
    setState(() => _loading = true);
    await _loadProgramSettings();

    // clear
    for (final c in ActivityCategory.values) {
      _entries[c] = <ActivityEntry>[];
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dateKey(date));

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final e = ActivityEntry.fromJson(item);
              _entries[e.category] = [...(_entries[e.category] ?? []), e];
            } else if (item is Map) {
              final map = item.map((k, v) => MapEntry(k.toString(), v));
              final e = ActivityEntry.fromJson(map);
              _entries[e.category] = [...(_entries[e.category] ?? []), e];
            }
          }
        }
      } catch (_) {}
    }

    // ✅ update AI tips
    _refreshAiTips();

    setState(() => _loading = false);
  }

  Future<void> _saveCurrentDate() async {
    final prefs = await SharedPreferences.getInstance();
    final all = <ActivityEntry>[];
    for (final c in ActivityCategory.values) {
      all.addAll(_entries[c] ?? []);
    }
    await prefs.setString(
      _dateKey(_selectedDate),
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  // -----------------------
  // Computations
  // -----------------------
  int get _todayTotalMinutes {
    int sum = 0;
    for (final c in ActivityCategory.values) {
      for (final e in _entries[c] ?? []) {
        sum += (e.minutes as num).toInt();
      }
    }
    return sum;
  }

  int get _todaySessions {
    int count = 0;
    for (final c in ActivityCategory.values) {
      count += (_entries[c] ?? []).length;
    }
    return count;
  }

  // “Your Program completed” logic:
  // It completes as user logs sessions/minutes for the day.
  // (If you later want weekly aggregation, we can sum last 7 days.)
  double get _progressMinutes =>
      (_todayTotalMinutes / max(1, _goalMinutesPerWeek)).clamp(0.0, 1.0);
  double get _progressSessions =>
      (_todaySessions / max(1, _goalSessionsPerWeek)).clamp(0.0, 1.0);

  int clamp0(int v) => max(0, v);

  // -----------------------
  // UI actions
  // -----------------------
  String _prettyDate(DateTime d) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: "Select date",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _purple,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() =>
      _selectedDate = DateTime(picked.year, picked.month, picked.day));
      await _loadAllForDate(_selectedDate);
    }
  }

  Future<void> _editProgram() async {
    final result = await showDialog<_ProgramDialogResult>(
      context: context,
      builder: (_) => _ProgramDialog(
        initialMinutes: _goalMinutesPerWeek,
        initialSessions: _goalSessionsPerWeek,
      ),
    );

    if (result == null) return;

    setState(() {
      _goalMinutesPerWeek = result.goalMinutesPerWeek;
      _goalSessionsPerWeek = result.goalSessionsPerWeek;
      _refreshAiTips(); // ✅
    });

    await _saveProgramSettings();
  }

  Future<void> _addActivity(ActivityCategory category) async {
    final result = await showDialog<_AddActivityResult>(
      context: context,
      builder: (_) => _AddActivityDialog(category: category),
    );

    if (result == null) return;

    final now = DateTime.now();
    final entry = ActivityEntry(
      id: "${now.microsecondsSinceEpoch}_${category.index}",
      category: category,
      name: result.name.trim(),
      minutes: result.minutes,
      createdAt: now,
    );

    setState(() {
      _entries[category] = [entry, ...(_entries[category] ?? [])];
      _refreshAiTips(); // ✅
    });

    await _saveCurrentDate();
  }

  Future<void> _removeEntry(ActivityEntry e) async {
    setState(() {
      _entries[e.category] =
          (_entries[e.category] ?? []).where((x) => x.id != e.id).toList();
      _refreshAiTips(); // ✅
    });
    await _saveCurrentDate();
  }

  Future<void> _clearDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear day?"),
        content: const Text("This will remove all activities for the selected date."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      for (final c in ActivityCategory.values) {
        _entries[c] = <ActivityEntry>[];
      }
      _refreshAiTips(); // ✅
    });
    await _saveCurrentDate();
  }

  // -----------------------
  // Build
  // -----------------------
  @override
  Widget build(BuildContext context) {
    final remainingMinutes = clamp0(_goalMinutesPerWeek - _todayTotalMinutes);
    final remainingSessions = clamp0(_goalSessionsPerWeek - _todaySessions);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Activity", style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            onPressed: _pickDate,
            tooltip: "Select date",
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // date row
          Row(
            children: [
              Text(_prettyDate(_selectedDate),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              TextButton(
                onPressed: _clearDay,
                child: const Text(
                  "Clear",
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Your Program (no details)
          _YourProgramCard(
            goalMinutesPerWeek: _goalMinutesPerWeek,
            goalSessionsPerWeek: _goalSessionsPerWeek,
            doneMinutes: _todayTotalMinutes,
            doneSessions: _todaySessions,
            remainingMinutes: remainingMinutes,
            remainingSessions: remainingSessions,
            progressMinutes: _progressMinutes,
            progressSessions: _progressSessions,
            onEditProgram: _editProgram,
          ),

          const SizedBox(height: 16),

          // Areas of Focus (no more)
          const Text("Areas of Focus",
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),

          // grid
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final isNarrow = w < 380;
              final cols = isNarrow ? 2 : 3;
              final spacing = 12.0;
              final itemW = (w - spacing * (cols - 1)) / cols;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: ActivityCategory.values.map((cat) {
                  final list = _entries[cat] ?? const <ActivityEntry>[];
                  final totalMin = list.fold<int>(0, (a, b) => a + b.minutes);

                  return SizedBox(
                    width: itemW,
                    child: _FocusCard(
                      category: cat,
                      totalMinutes: totalMin,
                      entries: list,
                      onAdd: () => _addActivity(cat),
                      onRemove: _removeEntry,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 18),

          // ✅ AI Tips section
          Row(
            children: [
              const Text("AI Coach Tips",
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() => _refreshAiTips());
                },
                child: const Text("Refresh"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ActivityTipsCardsAlwaysVisible(tips: _aiTips),

          const SizedBox(height: 18),
        ],
      ),
      // AI assistant removed
      floatingActionButton: null,
    );
  }
}

// ------------------------------------------------------------
// ✅ On-device AI Tips model/engine/widgets (NO BACKEND)
// ------------------------------------------------------------
enum ActivityTipType { food, exercise, medicine }

class ActivityTipItem {
  final ActivityTipType type;
  final String message;
  final DateTime createdAt;

  const ActivityTipItem({
    required this.type,
    required this.message,
    required this.createdAt,
  });
}

class ActivityTipsEngine {
  static const Duration _minInterval = Duration(seconds: 35);
  final Map<ActivityTipType, DateTime> _lastAt = <ActivityTipType, DateTime>{};

  void seedIfNeeded(List<ActivityTipItem> target) {
    if (target.isNotEmpty) return;
    final now = DateTime.now();
    target.addAll([
      ActivityTipItem(
        type: ActivityTipType.exercise,
        message: "Log an activity and I’ll recommend the next best move for consistency.",
        createdAt: now,
      ),
      ActivityTipItem(
        type: ActivityTipType.food,
        message: "Food tips will adapt to your activity intensity and duration.",
        createdAt: now,
      ),
      ActivityTipItem(
        type: ActivityTipType.medicine,
        message: "General reminder: this app never adjusts doses—follow your clinician plan.",
        createdAt: now,
      ),
    ]);
  }

  void updateTips({
    required List<ActivityTipItem> target,
    required DateTime date,
    required int goalMinutesPerWeek,
    required int goalSessionsPerWeek,
    required int totalMinutesToday,
    required int sessionsToday,
    required Map<ActivityCategory, int> perCategoryMinutes,
    required Map<ActivityCategory, int> perCategorySessions,
  }) {
    final now = DateTime.now();

    // If user is viewing a past day, keep tips more neutral (avoid “do it now”)
    final isToday = _sameDay(date, DateTime.now());

    final int hiitMin = perCategoryMinutes[ActivityCategory.hiit] ?? 0;
    final int strengthMin = perCategoryMinutes[ActivityCategory.strength] ?? 0;
    final int walkMin = perCategoryMinutes[ActivityCategory.walkRun] ?? 0;
    final int yogaMin = perCategoryMinutes[ActivityCategory.yoga] ?? 0;
    final int cycleMin = perCategoryMinutes[ActivityCategory.cycling] ?? 0;

    final double minutesProgress =
    (totalMinutesToday / max(1, goalMinutesPerWeek)).clamp(0.0, 2.0);
    final double sessionsProgress =
    (sessionsToday / max(1, goalSessionsPerWeek)).clamp(0.0, 2.0);

    // ----- EXERCISE TIP
    final ex = _exerciseTip(
      isToday: isToday,
      totalMinutes: totalMinutesToday,
      sessions: sessionsToday,
      minutesProgress: minutesProgress,
      sessionsProgress: sessionsProgress,
      hiitMin: hiitMin,
      strengthMin: strengthMin,
      walkMin: walkMin,
      yogaMin: yogaMin,
      cycleMin: cycleMin,
    );
    _maybeAdd(target, ActivityTipType.exercise, now, ex);

    // ----- FOOD TIP
    final food = _foodTip(
      isToday: isToday,
      totalMinutes: totalMinutesToday,
      hiitMin: hiitMin,
      strengthMin: strengthMin,
      walkMin: walkMin,
      yogaMin: yogaMin,
      cycleMin: cycleMin,
    );
    _maybeAdd(target, ActivityTipType.food, now, food);

    // ----- MEDICINE TIP (generic / safety)
    final med = _medicineTip(
      isToday: isToday,
      totalMinutes: totalMinutesToday,
      hiitMin: hiitMin,
    );
    _maybeAdd(target, ActivityTipType.medicine, now, med);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _maybeAdd(
      List<ActivityTipItem> target, ActivityTipType type, DateTime now, String msg) {
    final last = _lastAt[type];
    if (last != null && now.difference(last) < _minInterval) return;

    final latestSameType = target.where((t) => t.type == type).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (latestSameType.isNotEmpty && latestSameType.first.message == msg) return;

    target.add(ActivityTipItem(type: type, message: msg, createdAt: now));
    _lastAt[type] = now;
  }

  String _exerciseTip({
    required bool isToday,
    required int totalMinutes,
    required int sessions,
    required double minutesProgress,
    required double sessionsProgress,
    required int hiitMin,
    required int strengthMin,
    required int walkMin,
    required int yogaMin,
    required int cycleMin,
  }) {
    if (!isToday) {
      if (totalMinutes == 0) return "No activity logged on this day.";
      if (hiitMin > 0) return "HIIT day: good job. Ensure recovery (sleep + hydration).";
      if (strengthMin > 0) return "Strength logged: aim to balance with light cardio on other days.";
      if (walkMin + cycleMin > 0) return "Cardio day: consistency beats intensity—keep it regular.";
      if (yogaMin > 0) return "Yoga logged: great for mobility—pair with a short walk on other days.";
      return "Nice variety—keep a balanced weekly routine.";
    }

    if (totalMinutes == 0 && sessions == 0) {
      return "Start small: 10–15 min walk today. Consistency first.";
    }
    if (hiitMin >= 20) {
      return "You did HIIT: avoid another intense session today—do light walk/stretch instead.";
    }
    if (strengthMin >= 30 && walkMin == 0 && cycleMin == 0) {
      return "After strength, add a 10 min easy walk to cool down and support recovery.";
    }

    if (minutesProgress < 0.35 && sessionsProgress < 0.5) {
      return "You’re building momentum: add one short session (10–20 min) to close the gap.";
    }
    if (minutesProgress >= 1.0 || sessionsProgress >= 1.0) {
      return "You’re on track. Keep it light now—mobility or easy walk to maintain consistency.";
    }
    return "Good progress—finish with a gentle 10 min walk or yoga to support recovery.";
  }

  String _foodTip({
    required bool isToday,
    required int totalMinutes,
    required int hiitMin,
    required int strengthMin,
    required int walkMin,
    required int yogaMin,
    required int cycleMin,
  }) {
    if (totalMinutes == 0) {
      return isToday
          ? "No activity yet: choose a balanced meal (protein + fiber) to keep energy stable."
          : "No activity: keep meals balanced (protein + fiber + moderate carbs).";
    }

    final highIntensity = hiitMin > 0 || strengthMin > 0;
    final longCardio = (walkMin + cycleMin) >= 45;

    if (highIntensity) {
      return "Post-workout: prioritize protein + water. Add carbs only if you feel drained.";
    }
    if (longCardio) {
      return "Long cardio: hydrate and add electrolytes if needed. Choose carbs with fiber after.";
    }
    if (yogaMin >= 30) {
      return "Mobility day: keep meals light—protein + vegetables works well.";
    }
    return "Nice work: a balanced snack (yogurt + fruit / nuts) can help recovery.";
  }

  String _medicineTip({
    required bool isToday,
    required int totalMinutes,
    required int hiitMin,
  }) {
    // Safety-first, non-prescriptive
    if (!isToday) {
      return "Reminder: this app does not change medication. Always follow your clinician’s plan.";
    }

    if (hiitMin > 0) {
      return "If you use glucose-lowering meds, monitor closely after intense exercise. Follow your care plan.";
    }
    if (totalMinutes > 0) {
      return "General reminder: stay hydrated and follow prescribed medication schedule (no dose changes here).";
    }
    return "General reminder: medication tips are informational only—follow your clinician guidance.";
  }
}

class _ActivityTipsCardsAlwaysVisible extends StatelessWidget {
  final List<ActivityTipItem> tips;
  const _ActivityTipsCardsAlwaysVisible({required this.tips});

  String _latestFor(ActivityTipType type) {
    final filtered = tips.where((t) => t.type == type).toList();
    if (filtered.isEmpty) return "Waiting for AI suggestions…";
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.first.message;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isVeryNarrow = w < 360;

        if (isVeryNarrow) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (w - 12) / 2,
                child: _TipCard(
                  title: "Foods",
                  message: _latestFor(ActivityTipType.food),
                  color: const Color(0xFF1F5EA8),
                  icon: Icons.fastfood_rounded,
                ),
              ),
              SizedBox(
                width: (w - 12) / 2,
                child: _TipCard(
                  title: "Exercises",
                  message: _latestFor(ActivityTipType.exercise),
                  color: const Color(0xFFCDA1FF),
                  icon: Icons.directions_run_rounded,
                ),
              ),
              SizedBox(
                width: (w - 12) / 2,
                child: _TipCard(
                  title: "Medicine",
                  message: _latestFor(ActivityTipType.medicine),
                  color: const Color(0xFFFFC45C),
                  icon: Icons.medication_rounded,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _TipCard(
                title: "Foods",
                message: _latestFor(ActivityTipType.food),
                color: const Color(0xFF1F5EA8),
                icon: Icons.fastfood_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipCard(
                title: "Exercises",
                message: _latestFor(ActivityTipType.exercise),
                color: const Color(0xFFCDA1FF),
                icon: Icons.directions_run_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipCard(
                title: "Medicine",
                message: _latestFor(ActivityTipType.medicine),
                color: const Color(0xFFFFC45C),
                icon: Icons.medication_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const _TipCard({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.25,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Your Program Card (like diary remaining logic)
// ------------------------------------------------------------
class _YourProgramCard extends StatelessWidget {
  final int goalMinutesPerWeek;
  final int goalSessionsPerWeek;

  final int doneMinutes;
  final int doneSessions;

  final int remainingMinutes;
  final int remainingSessions;

  final double progressMinutes;
  final double progressSessions;

  final VoidCallback onEditProgram;

  const _YourProgramCard({
    required this.goalMinutesPerWeek,
    required this.goalSessionsPerWeek,
    required this.doneMinutes,
    required this.doneSessions,
    required this.remainingMinutes,
    required this.remainingSessions,
    required this.progressMinutes,
    required this.progressSessions,
    required this.onEditProgram,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Your Program",
                  style: TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onEditProgram,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text("Edit"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7B3FF2),
                  side: const BorderSide(color: Color(0xFF7B3FF2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _Kpi(label: "Goal (min/week)", value: "$goalMinutesPerWeek"),
              ),
              Expanded(
                child: _Kpi(label: "Done today", value: "$doneMinutes"),
              ),
              Expanded(
                child: _Kpi(label: "Remaining", value: "$remainingMinutes"),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _Kpi(label: "Goal (sessions/week)", value: "$goalSessionsPerWeek"),
              ),
              Expanded(
                child: _Kpi(label: "Sessions today", value: "$doneSessions"),
              ),
              Expanded(
                child: _Kpi(label: "Remaining", value: "$remainingSessions"),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // progress bars
          _ProgressRow(
            title: "Minutes progress",
            subtitle: "${(progressMinutes * 100).toStringAsFixed(0)}%",
            progress: progressMinutes,
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            title: "Sessions progress",
            subtitle: "${(progressSessions * 100).toStringAsFixed(0)}%",
            progress: progressSessions,
          ),

          const SizedBox(height: 10),
          Text(
            "Tip: Consistency matters—small daily activity is better than rare intense sessions.",
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: Colors.black.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  const _Kpi({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;

  const _ProgressRow({required this.title, required this.subtitle, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        Text(subtitle, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.55))),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.black.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7B3FF2)),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Focus card (big, shadow, + in corner)
// ------------------------------------------------------------
class _FocusCard extends StatelessWidget {
  final ActivityCategory category;
  final int totalMinutes;
  final List<ActivityEntry> entries;
  final VoidCallback onAdd;
  final Future<void> Function(ActivityEntry e) onRemove;

  const _FocusCard({
    required this.category,
    required this.totalMinutes,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: category.color.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(category.icon, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$totalMinutes min",
                      style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Text(
                "No activity yet. Tap + to add.",
                style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w700, fontSize: 12),
              ),
            )
          else
            Column(
              children: entries.take(3).map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EntryChip(entry: e, onDelete: () => onRemove(e)),
                );
              }).toList(),
            ),

          if (entries.length > 3)
            Text(
              "+${entries.length - 3} more",
              style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w800, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  final ActivityEntry entry;
  final VoidCallback onDelete;

  const _EntryChip({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "${entry.name} • ${entry.minutes} min",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            onPressed: onDelete,
            tooltip: "Remove",
          )
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Add Activity Dialog
// ------------------------------------------------------------
class _AddActivityResult {
  final String name;
  final int minutes;
  _AddActivityResult({required this.name, required this.minutes});
}

class _AddActivityDialog extends StatefulWidget {
  final ActivityCategory category;
  const _AddActivityDialog({required this.category});

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _minCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add to ${widget.category.title}"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "Activity name",
                hintText: "e.g., Treadmill run",
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? "Enter a name" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Duration (minutes)",
                hintText: "e.g., 30",
              ),
              validator: (v) {
                final x = _parseInt(v ?? "");
                if (x == null || x <= 0) return "Enter a valid minute value";
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B3FF2)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            Navigator.pop(
              context,
              _AddActivityResult(
                name: _nameCtrl.text.trim(),
                minutes: _parseInt(_minCtrl.text)!,
              ),
            );
          },
          child: const Text("Save"),
        )
      ],
    );
  }
}

// ------------------------------------------------------------
// Program Dialog (user defines program targets)
// ------------------------------------------------------------
class _ProgramDialogResult {
  final int goalMinutesPerWeek;
  final int goalSessionsPerWeek;

  _ProgramDialogResult({
    required this.goalMinutesPerWeek,
    required this.goalSessionsPerWeek,
  });
}

class _ProgramDialog extends StatefulWidget {
  final int initialMinutes;
  final int initialSessions;

  const _ProgramDialog({required this.initialMinutes, required this.initialSessions});

  @override
  State<_ProgramDialog> createState() => _ProgramDialogState();
}

class _ProgramDialogState extends State<_ProgramDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minCtrl;
  late final TextEditingController _sesCtrl;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(text: widget.initialMinutes.toString());
    _sesCtrl = TextEditingController(text: widget.initialSessions.toString());
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _sesCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Program"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Weekly goal minutes",
                hintText: "e.g., 150",
              ),
              validator: (v) {
                final x = _parseInt(v ?? "");
                if (x == null || x <= 0) return "Enter a valid number";
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _sesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Weekly goal sessions",
                hintText: "e.g., 4",
              ),
              validator: (v) {
                final x = _parseInt(v ?? "");
                if (x == null || x <= 0) return "Enter a valid number";
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              "These goals help you track consistency. We show progress using today’s logged activities.",
              style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w600),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B3FF2)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            Navigator.pop(
              context,
              _ProgramDialogResult(
                goalMinutesPerWeek: _parseInt(_minCtrl.text)!,
                goalSessionsPerWeek: _parseInt(_sesCtrl.text)!,
              ),
            );
          },
          child: const Text("Save"),
        )
      ],
    );
  }
}
