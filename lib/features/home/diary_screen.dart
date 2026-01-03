import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MealType { breakfast, lunch, dinner, snacks }

extension MealTypeX on MealType {
  String get title {
    switch (this) {
      case MealType.breakfast:
        return "Breakfast";
      case MealType.lunch:
        return "Lunch";
      case MealType.dinner:
        return "Dinner";
      case MealType.snacks:
        return "Snacks";
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.breakfast_dining_rounded;
      case MealType.lunch:
        return Icons.lunch_dining_rounded;
      case MealType.dinner:
        return Icons.dinner_dining_rounded;
      case MealType.snacks:
        return Icons.cookie_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MealType.breakfast:
        return const Color(0xFF1F5EA8);
      case MealType.lunch:
        return const Color(0xFFCDA1FF);
      case MealType.dinner:
        return const Color(0xFF7B3FF2);
      case MealType.snacks:
        return const Color(0xFFFFC45C);
    }
  }
}

class MealEntry {
  final String id;
  final MealType mealType;
  final String name;
  final double calories;

  /// grams (optional) - if user doesn't input, we auto-estimate from calories.
  final double carbsG;
  final double proteinG;
  final double fatG;

  final DateTime createdAt;

  MealEntry({
    required this.id,
    required this.mealType,
    required this.name,
    required this.calories,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "mealType": mealType.index,
    "name": name,
    "calories": calories,
    "carbsG": carbsG,
    "proteinG": proteinG,
    "fatG": fatG,
    "createdAt": createdAt.toIso8601String(),
  };

  static MealEntry fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: (json["id"] ?? "") as String,
      mealType: MealType.values[(json["mealType"] ?? 0) as int],
      name: (json["name"] ?? "") as String,
      calories: (json["calories"] as num).toDouble(),
      carbsG: (json["carbsG"] as num).toDouble(),
      proteinG: (json["proteinG"] as num).toDouble(),
      fatG: (json["fatG"] as num).toDouble(),
      createdAt: DateTime.parse(json["createdAt"] as String),
    );
  }
}

/// This screen:
/// - Stores daily meal entries in SharedPreferences
/// - Date picker to navigate past days
/// - Diet Program targets (reasonable diabetic-friendly default)
///
/// Targets (default, can be personalized later):
/// - 1800 kcal/day
/// - Carbs 45% (limit-ish), Protein 25%, Fat 30%
/// => Carbs ~ 202g, Protein ~ 113g, Fat ~ 60g
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  // ---------- Theme-ish ----------
  static const _bg = Color(0xFFF4F1E8);
  static const _purple = Color(0xFF7B3FF2);

  // ---------- Targets (algorithm baseline) ----------
  // You can later personalize these based on user's weight/goal.
  static const double _targetCalories = 1800;

  // Macro ratios:
  static const double _carbRatio = 0.45; // diabetic-friendly "moderate carb"
  static const double _proteinRatio = 0.25;
  static const double _fatRatio = 0.30;

  // kcal per gram:
  static const double _kcalPerCarbG = 4;
  static const double _kcalPerProteinG = 4;
  static const double _kcalPerFatG = 9;

  late DateTime _selectedDate;

  final Map<MealType, List<MealEntry>> _entries = {
    MealType.breakfast: <MealEntry>[],
    MealType.lunch: <MealEntry>[],
    MealType.dinner: <MealEntry>[],
    MealType.snacks: <MealEntry>[],
  };

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadForDate(_selectedDate);
  }

  // -----------------------
  // Persistence helpers
  // -----------------------
  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "diary_$y-$m-$day";
  }

  Future<void> _loadForDate(DateTime date) async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dateKey(date));

    // clear current
    for (final t in MealType.values) {
      _entries[t] = <MealEntry>[];
    }

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final e = MealEntry.fromJson(item);
              _entries[e.mealType] = [...(_entries[e.mealType] ?? []), e];
            } else if (item is Map) {
              final map = item.map((k, v) => MapEntry(k.toString(), v));
              final e = MealEntry.fromJson(map);
              _entries[e.mealType] = [...(_entries[e.mealType] ?? []), e];
            }
          }
        }
      } catch (_) {
        // ignore malformed data
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _saveCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final all = <MealEntry>[];
    for (final t in MealType.values) {
      all.addAll(_entries[t] ?? []);
    }
    final encoded = jsonEncode(all.map((e) => e.toJson()).toList());
    await prefs.setString(_dateKey(_selectedDate), encoded);
  }

  // -----------------------
  // Computations
  // -----------------------
  double get _consumedCalories {
    double sum = 0;
    for (final t in MealType.values) {
      for (final e in _entries[t] ?? []) {
        sum += e.calories;
      }
    }
    return sum;
  }

  double get _consumedCarbsG {
    double sum = 0;
    for (final t in MealType.values) {
      for (final e in _entries[t] ?? []) {
        sum += e.carbsG;
      }
    }
    return sum;
  }

  double get _consumedProteinG {
    double sum = 0;
    for (final t in MealType.values) {
      for (final e in _entries[t] ?? []) {
        sum += e.proteinG;
      }
    }
    return sum;
  }

  double get _consumedFatG {
    double sum = 0;
    for (final t in MealType.values) {
      for (final e in _entries[t] ?? []) {
        sum += e.fatG;
      }
    }
    return sum;
  }

  double get _targetCarbsG => (_targetCalories * _carbRatio) / _kcalPerCarbG;
  double get _targetProteinG => (_targetCalories * _proteinRatio) / _kcalPerProteinG;
  double get _targetFatG => (_targetCalories * _fatRatio) / _kcalPerFatG;

  double clamp0(double v) => max(0, v);

  // -----------------------
  // UI actions
  // -----------------------
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
      setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
      await _loadForDate(_selectedDate);
    }
  }

  String _prettyDate(DateTime d) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  Future<void> _addMeal(MealType type) async {
    final result = await showDialog<_MealDialogResult>(
      context: context,
      builder: (_) => _AddMealDialog(mealType: type),
    );

    if (result == null) return;

    final now = DateTime.now();

    // If macros not given, estimate from calories using a meal-level split.
    // For diabetics: slightly lower carbs, decent protein.
    // We'll estimate: carbs 45%, protein 25%, fat 30% (same as daily target).
    final calories = result.calories;

    final hasAnyMacro = (result.carbsG != null) || (result.proteinG != null) || (result.fatG != null);

    double carbsG;
    double proteinG;
    double fatG;

    if (!hasAnyMacro) {
      carbsG = (calories * _carbRatio) / _kcalPerCarbG;
      proteinG = (calories * _proteinRatio) / _kcalPerProteinG;
      fatG = (calories * _fatRatio) / _kcalPerFatG;
    } else {
      carbsG = result.carbsG ?? (calories * _carbRatio) / _kcalPerCarbG;
      proteinG = result.proteinG ?? (calories * _proteinRatio) / _kcalPerProteinG;
      fatG = result.fatG ?? (calories * _fatRatio) / _kcalPerFatG;
    }

    final entry = MealEntry(
      id: "${now.microsecondsSinceEpoch}_${type.index}",
      mealType: type,
      name: result.name.trim(),
      calories: calories,
      carbsG: carbsG,
      proteinG: proteinG,
      fatG: fatG,
      createdAt: now,
    );

    setState(() {
      _entries[type] = [entry, ...(_entries[type] ?? [])];
    });

    await _saveCurrent();
  }

  Future<void> _removeEntry(MealEntry e) async {
    setState(() {
      _entries[e.mealType] = (_entries[e.mealType] ?? []).where((x) => x.id != e.id).toList();
    });
    await _saveCurrent();
  }

  Future<void> _clearDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear day?"),
        content: const Text("This will remove all meals for the selected date."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
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
      for (final t in MealType.values) {
        _entries[t] = <MealEntry>[];
      }
    });
    await _saveCurrent();
  }

  // -----------------------
  // Build
  // -----------------------
  @override
  Widget build(BuildContext context) {
    final consumedCal = _consumedCalories;
    final remainingCal = clamp0(_targetCalories - consumedCal);

    final remainingCarb = clamp0(_targetCarbsG - _consumedCarbsG);
    final remainingProtein = clamp0(_targetProteinG - _consumedProteinG);
    final remainingFat = clamp0(_targetFatG - _consumedFatG);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Diary",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          // Calendar is functional
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
          // Date row
          Row(
            children: [
              Text(
                _prettyDate(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearDay,
                child: const Text(
                  "Clear",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Diet Program (calories + macros remaining)
          _DietProgramCard(
            targetCalories: _targetCalories,
            consumedCalories: consumedCal,
            remainingCalories: remainingCal,
            remainingCarbsG: remainingCarb,
            remainingProteinG: remainingProtein,
            remainingFatG: remainingFat,
            targetCarbsG: _targetCarbsG,
            targetProteinG: _targetProteinG,
            targetFatG: _targetFatG,
          ),

          const SizedBox(height: 16),

          // Meals Today header (no customize, no details)
          Row(
            children: const [
              Text("Meals Today", style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),

          _MealCard(
            type: MealType.breakfast,
            entries: _entries[MealType.breakfast] ?? const [],
            onAdd: () => _addMeal(MealType.breakfast),
            onRemove: _removeEntry,
          ),
          const SizedBox(height: 12),
          _MealCard(
            type: MealType.lunch,
            entries: _entries[MealType.lunch] ?? const [],
            onAdd: () => _addMeal(MealType.lunch),
            onRemove: _removeEntry,
          ),
          const SizedBox(height: 12),
          _MealCard(
            type: MealType.dinner,
            entries: _entries[MealType.dinner] ?? const [],
            onAdd: () => _addMeal(MealType.dinner),
            onRemove: _removeEntry,
          ),
          const SizedBox(height: 12),
          _MealCard(
            type: MealType.snacks,
            entries: _entries[MealType.snacks] ?? const [],
            onAdd: () => _addMeal(MealType.snacks),
            onRemove: _removeEntry,
          ),

          const SizedBox(height: 18),
        ],
      ),
      // AI assistant icon removed => no FAB
      floatingActionButton: null,
    );
  }
}

// ------------------------------------------------------------
// Diet Program Card
// ------------------------------------------------------------
class _DietProgramCard extends StatelessWidget {
  final double targetCalories;
  final double consumedCalories;
  final double remainingCalories;

  final double remainingCarbsG;
  final double remainingProteinG;
  final double remainingFatG;

  final double targetCarbsG;
  final double targetProteinG;
  final double targetFatG;

  const _DietProgramCard({
    required this.targetCalories,
    required this.consumedCalories,
    required this.remainingCalories,
    required this.remainingCarbsG,
    required this.remainingProteinG,
    required this.remainingFatG,
    required this.targetCarbsG,
    required this.targetProteinG,
    required this.targetFatG,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (consumedCalories / max(1, targetCalories)).clamp(0.0, 1.0);

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
      child: Row(
        children: [
          Expanded(
            child: _DietTextSide(
              targetCalories: targetCalories,
              consumedCalories: consumedCalories,
              remainingCalories: remainingCalories,
              remainingCarbsG: remainingCarbsG,
              remainingProteinG: remainingProteinG,
              remainingFatG: remainingFatG,
            ),
          ),
          const SizedBox(width: 12),
          _RingProgress(
            progress: progress,
            centerTop: remainingCalories.toStringAsFixed(0),
            centerBottom: "Remaining\nCalories",
          ),
        ],
      ),
    );
  }
}

class _DietTextSide extends StatelessWidget {
  final double targetCalories;
  final double consumedCalories;
  final double remainingCalories;

  final double remainingCarbsG;
  final double remainingProteinG;
  final double remainingFatG;

  const _DietTextSide({
    required this.targetCalories,
    required this.consumedCalories,
    required this.remainingCalories,
    required this.remainingCarbsG,
    required this.remainingProteinG,
    required this.remainingFatG,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Diet Program", style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: "Active Calories",
                value: "${targetCalories.toStringAsFixed(0)} kcal",
              ),
            ),
            Expanded(
              child: _Kpi(
                label: "Consumed",
                value: "${consumedCalories.toStringAsFixed(0)} kcal",
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _MacroMini(
                label: "Carbohydrate",
                value: "${remainingCarbsG.toStringAsFixed(0)} g left",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroMini(
                label: "Protein",
                value: "${remainingProteinG.toStringAsFixed(0)} g left",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroMini(
                label: "Fat",
                value: "${remainingFatG.toStringAsFixed(0)} g left",
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        Text(
          "Tip: To keep glucose stable, distribute carbs across meals and avoid large spikes.",
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            color: Colors.black.withOpacity(0.55),
            fontWeight: FontWeight.w600,
          ),
        )
      ],
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
          style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700, fontSize: 12),
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

class _MacroMini extends StatelessWidget {
  final String label;
  final String value;
  const _MacroMini({required this.label, required this.value});

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
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// Simple ring progress widget
class _RingProgress extends StatelessWidget {
  final double progress; // 0..1
  final String centerTop;
  final String centerBottom;

  const _RingProgress({
    required this.progress,
    required this.centerTop,
    required this.centerBottom,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(92, 92),
            painter: _RingPainter(progress: progress),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerTop,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                centerBottom,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.1,
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = min(size.width, size.height) / 2 - 6;

    final bg = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = const Color(0xFF7B3FF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, r, bg);

    final sweep = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}

// ------------------------------------------------------------
// Meal Cards (bigger, shadow, realistic)
// ------------------------------------------------------------
class _MealCard extends StatelessWidget {
  final MealType type;
  final List<MealEntry> entries;
  final VoidCallback onAdd;
  final Future<void> Function(MealEntry e) onRemove;

  const _MealCard({
    required this.type,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  double get totalCalories => entries.fold(0.0, (a, b) => a + b.calories);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: type.color.withOpacity(0.28),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(type.icon, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${totalCalories.toStringAsFixed(0)} kcal",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.add_rounded, color: Colors.black87),
                      SizedBox(width: 6),
                      Text("Add", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
                    ],
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 12),

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
                "No items yet. Tap + Add to log what you ate.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            )
          else
            Column(
              children: entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MealEntryTile(
                    entry: e,
                    onDelete: () => onRemove(e),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _MealEntryTile extends StatelessWidget {
  final MealEntry entry;
  final VoidCallback onDelete;

  const _MealEntryTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${entry.calories.toStringAsFixed(0)} kcal • "
                      "C ${entry.carbsG.toStringAsFixed(0)}g  "
                      "P ${entry.proteinG.toStringAsFixed(0)}g  "
                      "F ${entry.fatG.toStringAsFixed(0)}g",
                  style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w700, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            tooltip: "Remove",
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Add Meal Dialog
// ------------------------------------------------------------
class _MealDialogResult {
  final String name;
  final double calories;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;

  _MealDialogResult({
    required this.name,
    required this.calories,
    this.carbsG,
    this.proteinG,
    this.fatG,
  });
}

class _AddMealDialog extends StatefulWidget {
  final MealType mealType;
  const _AddMealDialog({required this.mealType});

  @override
  State<_AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<_AddMealDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _carbCtrl.dispose();
    _protCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  double? _parse(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add to ${widget.mealType.title}"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: "What did you eat?",
                  hintText: "e.g., Oatmeal + yogurt",
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter a name" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Calories (kcal)",
                  hintText: "e.g., 420",
                ),
                validator: (v) {
                  final x = _parse(v ?? "");
                  if (x == null || x <= 0) return "Enter a valid calorie value";
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Optional macros
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      "Macros (optional)",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _carbCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Carbs (g)"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _protCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Protein (g)"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _fatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Fat (g)"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "If you leave macros empty, we estimate them with a diabetic-friendly split.",
                style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w600),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B3FF2)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final name = _nameCtrl.text.trim();
            final calories = _parse(_calCtrl.text)!;

            final carbs = _parse(_carbCtrl.text);
            final protein = _parse(_protCtrl.text);
            final fat = _parse(_fatCtrl.text);

            Navigator.pop(
              context,
              _MealDialogResult(
                name: name,
                calories: calories,
                carbsG: carbs,
                proteinG: protein,
                fatG: fat,
              ),
            );
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
