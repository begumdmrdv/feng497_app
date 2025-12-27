import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Month selection
  late final List<_MonthItem> _months;
  late _MonthItem _selectedMonth;

  // Range selection (hours)
  final List<int> _ranges = [3, 6, 12, 24];
  int _selectedRange = 3;

  // Window offset for "hour navigation"
  // 0 = last window, 1 = previous window, 2 = older window...
  int _windowOffset = 0;

  // Mock chart data
  late List<double> _series;
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _months = _buildLast12Months();
    _selectedMonth = _months.first; // current month on top
    _recompute();
  }

  List<_MonthItem> _buildLast12Months() {
    final now = DateTime.now();
    final items = <_MonthItem>[];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      items.add(_MonthItem(
        label: _monthLabel(d),
        year: d.year,
        month: d.month,
      ));
    }
    return items;
  }

  String _monthLabel(DateTime d) {
    const names = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${names[d.month - 1]} - ${d.year}";
  }

  void _recompute() {
    // Create deterministic-seeming randomness based on month + range + offset
    final seed = (_selectedMonth.year * 100 + _selectedMonth.month) * 1000
        + _selectedRange * 10
        + _windowOffset;

    final rng = Random(seed);

    // Number of points for the chart
    // More points -> smoother line. Choose based on range.
    final points = switch (_selectedRange) {
      3 => 18,
      6 => 24,
      12 => 30,
      _ => 36, // 24H
    };

    // Baseline & volatility depend on range a bit
    final baseline = 105 + rng.nextInt(15); // 105-119
    final volatility = _selectedRange <= 6 ? 10 : 14;

    // Build series (dummy glucose curve)
    double v = baseline.toDouble();
    final series = <double>[];
    for (int i = 0; i < points; i++) {
      final drift = rng.nextDouble() * 2 - 1; // [-1,1]
      final shock = (rng.nextDouble() * 2 - 1) * volatility;
      v = (v + drift + shock * 0.15).clamp(70, 220);
      series.add(v);
    }

    // Add a spike sometimes (looks real)
    if (rng.nextBool()) {
      final idx = rng.nextInt(points);
      series[idx] = (series[idx] + 40 + rng.nextInt(30)).clamp(70, 240);
    }

    _series = series;
    _currentValue = series.last;
  }

  void _selectRange(int h) {
    setState(() {
      _selectedRange = h;
      _windowOffset = 0; // reset window when range changes
      _recompute();
    });
  }

  void _changeMonth(_MonthItem m) {
    setState(() {
      _selectedMonth = m;
      _windowOffset = 0;
      _recompute();
    });
  }

  // Window navigation: let user go back/forward in time windows
  void _goOlderWindow() {
    setState(() {
      _windowOffset = (_windowOffset + 1).clamp(0, 48); // cap to avoid infinity
      _recompute();
    });
  }

  void _goNewerWindow() {
    setState(() {
      _windowOffset = (_windowOffset - 1).clamp(0, 48);
      _recompute();
    });
  }

  String _rangeTitle() {
    // "Last 3 hours" with window shift like "Last 3 hours (Window -1)"
    if (_windowOffset == 0) return "Last $_selectedRange hours";
    return "Last $_selectedRange hours (Previous window x$_windowOffset)";
  }

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;
    final displayName =
    (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!
        : "User";

    final trendUp = _series.length >= 2 ? _series.last >= _series[_series.length - 2] : true;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B3FF2),
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Hello, Welcome!",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Blood Glucose Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Blood Glucose",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text("Details"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Month dropdown
                Row(
                  children: [
                    Text(
                      _selectedMonth.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_MonthItem>(
                          value: _selectedMonth,
                          borderRadius: BorderRadius.circular(14),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          items: _months
                              .map(
                                (m) => DropdownMenuItem<_MonthItem>(
                              value: m,
                              child: Text(
                                m.label,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                              .toList(),
                          onChanged: (m) {
                            if (m != null) _changeMonth(m);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Range pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _ranges.map((h) {
                      final selected = h == _selectedRange;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Pill(
                          text: "${h}H",
                          selected: selected,
                          onTap: () => _selectRange(h),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // Window navigation row (hour-to-hour shifting)
                Row(
                  children: [
                    IconButton(
                      onPressed: _windowOffset < 48 ? _goOlderWindow : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: "Go to previous hours",
                    ),
                    Expanded(
                      child: Text(
                        _rangeTitle(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _windowOffset > 0 ? _goNewerWindow : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: "Go to newer hours",
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Graph + value
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 140,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _MiniLineChart(values: _series),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_currentValue.toStringAsFixed(0)} mg/dl",
                          style: const TextStyle(
                            color: Color(0xFF7B3FF2),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          color: const Color(0xFF7B3FF2),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tips header
          Row(
            children: [
              const Text(
                "Tips",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text("Customize")),
            ],
          ),

          const SizedBox(height: 10),

          // Tips cards row
          const Row(
            children: [
              Expanded(
                child: _TipCard(
                  title: "Foods",
                  subtitle: "Go with higher\nprotein meals",
                  color: Color(0xFF1F5EA8),
                  icon: Icons.fastfood_rounded,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _TipCard(
                  title: "Exercises",
                  subtitle: "Do some breath\nexercises",
                  color: Color(0xFFCDA1FF),
                  icon: Icons.directions_run_rounded,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _TipCard(
                  title: "Medicine",
                  subtitle: "If you have pain you\ncan use parol.",
                  color: Color(0xFFFFC45C),
                  icon: Icons.medication_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7B3FF2),
        onPressed: () {},
        child: const Icon(Icons.smart_toy_outlined),
      ),
    );
  }
}

class _MonthItem {
  final String label;
  final int year;
  final int month;

  const _MonthItem({
    required this.label,
    required this.year,
    required this.month,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _MonthItem && runtimeType == other.runtimeType && year == other.year && month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

class _Pill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  const _Pill({
    required this.text,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7B3FF2) : const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _TipCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple line chart drawn with CustomPainter.
/// No external chart package needed.
/// Backend later -> just provide the values list.
class _MiniLineChart extends StatelessWidget {
  final List<double> values;

  const _MiniLineChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniLineChartPainter(values: values),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  final List<double> values;

  _MiniLineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    // padding
    const left = 6.0;
    const top = 8.0;
    const right = 6.0;
    const bottom = 10.0;

    final w = size.width - left - right;
    final h = size.height - top - bottom;

    // grid lines
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = top + (h / 3) * i;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
    }

    // line paint
    final linePaint = Paint()
      ..color = const Color(0xFF7B3FF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // fill paint
    final fillPaint = Paint()
      ..color = const Color(0xFF7B3FF2).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = left + (w * i / (values.length - 1));
      final norm = (values[i] - minV) / range;
      final y = top + (h * (1 - norm));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, top + h);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(left + w, top + h);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // last point dot
    final lastX = left + w;
    final lastNorm = (values.last - minV) / range;
    final lastY = top + (h * (1 - lastNorm));

    final dotPaint = Paint()..color = const Color(0xFF7B3FF2);
    canvas.drawCircle(Offset(lastX, lastY), 3.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
