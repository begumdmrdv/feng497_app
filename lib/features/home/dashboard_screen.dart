import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class DashboardScreen extends StatefulWidget {
  final List<double> liveSeries;
  final double? liveCurrentValue;

  /// Backend: AI tips (optional)
  final List<TipItem> tips;

  const DashboardScreen({
    super.key,
    this.liveSeries = const [],
    this.liveCurrentValue,
    this.tips = const [],
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ----------------------------
  // ✅ WEBSOCKET LIVE DATA
  // ----------------------------
  WebSocketChannel? _channel;
  final List<double> _wsLiveSeries = <double>[];
  double? _wsLiveCurrentValue;

  final bool _useWebSocketLive = true;

  void _connectWs() {
    final uri = Uri.parse('ws://10.0.2.2:8000/ws/stream');
    _channel = WebSocketChannel.connect(uri);

    debugPrint("WS connecting to: $uri");

    _channel!.stream.listen((event) {
      debugPrint("WS raw: $event");

      try {
        final obj = jsonDecode(event);
        if (obj is Map && obj["type"] == "reading") {
          final data = obj["data"];
          final g = (data["glucose"] as num).toDouble();

          setState(() {
            _wsLiveCurrentValue = g;
            _wsLiveSeries.add(g);
            if (_wsLiveSeries.length > 60) _wsLiveSeries.removeAt(0);
          });
        }
      } catch (e) {
        debugPrint("WS parse error: $e");
      }
    }, onError: (e) {
      debugPrint("WS error: $e");
    }, onDone: () {
      debugPrint("WS closed");
    });
  }


  @override
  void initState() {
    super.initState();
    _months = _buildLast12Months();
    _setDailyMode();

    // ✅ WS'yi başlat
    if (_useWebSocketLive) {
      _connectWs();
    }
  }

  @override
  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    super.dispose();
  }

  // ----------------------------
  // EXISTING STATE (daily/monthly dummy)
  // ----------------------------
  bool _monthlyMode = false; // false => daily mode

  // Month selection (for monthly mode)
  late final List<_MonthItem> _months;
  _MonthItem? _selectedMonth;

  // Range selection (hours) for daily mode only
  final List<int> _ranges = [3, 6, 12, 24];
  int _selectedRange = 3;

  // daily window paging (optional)
  int _dayWindowOffset = 0;

  // Daily series (dummy)
  late List<double> _dailySeries;
  late double _dailyCurrentValue;

  // Monthly avg series (dummy)
  late List<double> _monthlySeries; // e.g., 30 points
  late double _monthlyAvgValue;

  // ----------------------------
  // Month helpers
  // ----------------------------
  List<_MonthItem> _buildLast12Months() {
    final now = DateTime.now();
    final items = <_MonthItem>[];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      items.add(_MonthItem(label: _monthLabel(d), year: d.year, month: d.month));
    }
    return items;
  }

  String _monthLabel(DateTime d) {
    const names = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return "${names[d.month - 1]} - ${d.year}";
  }

  // ----------------------------
  // MODE SETTERS
  // ----------------------------
  void _setDailyMode() {
    setState(() {
      _monthlyMode = false;
      _selectedMonth = null;
      _selectedRange = 3;
      _dayWindowOffset = 0;
      _recomputeDailySeries();
    });
  }

  void _setMonthlyMode(_MonthItem m) {
    setState(() {
      _monthlyMode = true;
      _selectedMonth = m;
      _recomputeMonthlySeries();
    });
  }

  // ----------------------------
  // Daily data (dummy)
  // ----------------------------
  void _recomputeDailySeries() {
    final today = DateTime.now();
    final seed = (today.year * 10000 + today.month * 100 + today.day) * 1000 +
        _selectedRange * 10 +
        _dayWindowOffset;
    final rng = Random(seed);

    final points = switch (_selectedRange) {
      3 => 18,
      6 => 24,
      12 => 30,
      _ => 36,
    };

    final baseline = 100 + rng.nextInt(18);
    final volatility = _selectedRange <= 6 ? 10 : 14;

    double v = baseline.toDouble();
    final series = <double>[];

    for (int i = 0; i < points; i++) {
      final drift = rng.nextDouble() * 2 - 1;
      final shock = (rng.nextDouble() * 2 - 1) * volatility;
      v = (v + drift + shock * 0.15).clamp(70.0, 220.0).toDouble();
      series.add(v);
    }

    _dailySeries = series;
    _dailyCurrentValue = series.last;
  }

  // ----------------------------
  // Monthly data (dummy)
  // ----------------------------
  void _recomputeMonthlySeries() {
    final m = _selectedMonth!;
    final seed = (m.year * 100 + m.month) * 999;
    final rng = Random(seed);

    const points = 30;
    double v = (95 + rng.nextInt(20)).toDouble();
    final series = <double>[];

    for (int i = 0; i < points; i++) {
      final drift = rng.nextDouble() * 2 - 1;
      final shock = (rng.nextDouble() * 2 - 1) * 6;
      v = (v + drift + shock * 0.15).clamp(75.0, 180.0).toDouble();
      series.add(v);
    }

    final avg = series.reduce((a, b) => a + b) / series.length;

    _monthlySeries = series;
    _monthlyAvgValue = avg;
  }

  // ----------------------------
  // Daily UI actions
  // ----------------------------
  void _selectRange(int h) {
    if (_monthlyMode) return;
    setState(() {
      _selectedRange = h;
      _dayWindowOffset = 0;
      _recomputeDailySeries();
    });
  }

  void _goOlderDailyWindow() {
    if (_monthlyMode) return;
    setState(() {
      _dayWindowOffset = (_dayWindowOffset + 1).clamp(0, 48);
      _recomputeDailySeries();
    });
  }

  void _goNewerDailyWindow() {
    if (_monthlyMode) return;
    setState(() {
      _dayWindowOffset = (_dayWindowOffset - 1).clamp(0, 48);
      _recomputeDailySeries();
    });
  }

  String _dailyRangeTitle() {
    if (_dayWindowOffset == 0) return "Last $_selectedRange hours";
    return "Last $_selectedRange hours (previous x$_dayWindowOffset)";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
    (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName! : "User";

    // LIVE veriyi burada seçiyoruz:
    // WS aktifse -> _wsLiveSeries
    // değilse -> widget.liveSeries
    final liveSeries = _useWebSocketLive ? _wsLiveSeries : widget.liveSeries;

    final liveValue = _useWebSocketLive
        ? _wsLiveCurrentValue
        : (widget.liveCurrentValue ??
        (liveSeries.isNotEmpty ? liveSeries.last : null));


    final liveTrendUp = (liveSeries.length >= 2)
        ? liveSeries.last >= liveSeries[liveSeries.length - 2]
        : true;

    final chartSeries = _monthlyMode ? _monthlySeries : _dailySeries;
    final mainValue = _monthlyMode ? _monthlyAvgValue : _dailyCurrentValue;

    final trendUp = chartSeries.length >= 2
        ? chartSeries.last >= chartSeries[chartSeries.length - 2]
        : true;

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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final maxW = min(c.maxWidth, 540.0);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _LiveGlucoseCard(
                    liveValue: liveValue,
                    trendUp: liveTrendUp,
                    series: liveSeries,
                  ),
                  const SizedBox(height: 14),

                  _GlucoseHistoryCard(
                    monthlyMode: _monthlyMode,
                    selectedMonth: _selectedMonth,
                    months: _months,
                    onPickMonth: (m) => _setMonthlyMode(m),
                    onBackToToday: _setDailyMode,
                    ranges: _ranges,
                    selectedRange: _selectedRange,
                    onRangeTap: _selectRange,
                    rangeTitle: _monthlyMode ? "Monthly overview" : _dailyRangeTitle(),
                    canGoNewer: !_monthlyMode && _dayWindowOffset > 0,
                    onGoNewer: _goNewerDailyWindow,
                    onGoOlder: _goOlderDailyWindow,
                    series: chartSeries,
                    value: mainValue,
                    trendUp: trendUp,
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Text("Tips", style: TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      TextButton(onPressed: () {}, child: const Text("Customize")),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _TipsCardsAlwaysVisible(tips: widget.tips),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: null,
    );
  }
}

// ---------------------------------------------------------------------
// Tips models / UI
// ---------------------------------------------------------------------
enum TipType { food, exercise, medicine }

class TipItem {
  final TipType type;
  final String message;
  final DateTime? createdAt;
  const TipItem({required this.type, required this.message, this.createdAt});
}

class _TipsCardsAlwaysVisible extends StatelessWidget {
  final List<TipItem> tips;
  const _TipsCardsAlwaysVisible({required this.tips});

  String _latestFor(TipType type) {
    final filtered = tips.where((t) => t.type == type).toList();
    if (filtered.isEmpty) return "Waiting for AI suggestions…";
    filtered.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
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
                  message: _latestFor(TipType.food),
                  color: const Color(0xFF1F5EA8),
                  icon: Icons.fastfood_rounded,
                ),
              ),
              SizedBox(
                width: (w - 12) / 2,
                child: _TipCard(
                  title: "Exercises",
                  message: _latestFor(TipType.exercise),
                  color: const Color(0xFFCDA1FF),
                  icon: Icons.directions_run_rounded,
                ),
              ),
              SizedBox(
                width: (w - 12) / 2,
                child: _TipCard(
                  title: "Medicine",
                  message: _latestFor(TipType.medicine),
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
                message: _latestFor(TipType.food),
                color: const Color(0xFF1F5EA8),
                icon: Icons.fastfood_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipCard(
                title: "Exercises",
                message: _latestFor(TipType.exercise),
                color: const Color(0xFFCDA1FF),
                icon: Icons.directions_run_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipCard(
                title: "Medicine",
                message: _latestFor(TipType.medicine),
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

// ---------------------------------------------------------------------
// Live card
// ---------------------------------------------------------------------
class _LiveGlucoseCard extends StatelessWidget {
  final double? liveValue;
  final bool trendUp;
  final List<double> series;

  const _LiveGlucoseCard({
    required this.liveValue,
    required this.trendUp,
    required this.series,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = series.isNotEmpty && liveValue != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Live Glucose",
                  style: TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B3FF2).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: Color(0xFF7B3FF2)),
                    SizedBox(width: 6),
                    Text(
                      "LIVE",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7B3FF2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasData) ...[
            const Text(
              "Waiting for live data…",
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 2.6,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${liveValue!.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text(
                    "mg/dl",
                    style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                Icon(
                  trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: const Color(0xFF7B3FF2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 2.6,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _MiniLineChart(values: series),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Real-time values are provided by the smartwatch module.",
              style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// History card + helpers (aynı)
// ---------------------------------------------------------------------
class _GlucoseHistoryCard extends StatelessWidget {
  final bool monthlyMode;
  final _MonthItem? selectedMonth;
  final List<_MonthItem> months;
  final ValueChanged<_MonthItem> onPickMonth;
  final VoidCallback onBackToToday;

  final List<int> ranges;
  final int selectedRange;
  final ValueChanged<int> onRangeTap;

  final String rangeTitle;
  final bool canGoNewer;
  final VoidCallback onGoNewer;
  final VoidCallback onGoOlder;

  final List<double> series;
  final double value;
  final bool trendUp;

  const _GlucoseHistoryCard({
    required this.monthlyMode,
    required this.selectedMonth,
    required this.months,
    required this.onPickMonth,
    required this.onBackToToday,
    required this.ranges,
    required this.selectedRange,
    required this.onRangeTap,
    required this.rangeTitle,
    required this.canGoNewer,
    required this.onGoNewer,
    required this.onGoOlder,
    required this.series,
    required this.value,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final labelTop = monthlyMode ? "Monthly Average" : "Blood Glucose";
    final rightValueLabel = monthlyMode ? "avg mg/dl" : "mg/dl";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  labelTop,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text("Details")),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  monthlyMode ? (selectedMonth?.label ?? "") : "Today",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (monthlyMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: onBackToToday,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B3FF2),
                      side: const BorderSide(color: Color(0xFF7B3FF2), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "Current day",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_MonthItem>(
                    hint: const Text("Select month"),
                    value: selectedMonth,
                    borderRadius: BorderRadius.circular(14),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    items: months
                        .map((m) => DropdownMenuItem<_MonthItem>(
                      value: m,
                      child: Text(
                        m.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                        .toList(),
                    onChanged: (m) {
                      if (m != null) onPickMonth(m);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ranges.map((h) {
                final selected = h == selectedRange;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Pill(
                    text: "${h}H",
                    selected: selected && !monthlyMode,
                    enabled: !monthlyMode,
                    onTap: () => onRangeTap(h),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              IconButton(
                onPressed: monthlyMode ? null : onGoOlder,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  rangeTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: canGoNewer ? onGoNewer : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 2.2,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _MiniLineChart(values: series),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${value.toStringAsFixed(0)} $rightValueLabel",
                      style: const TextStyle(
                        color: Color(0xFF7B3FF2),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: const Color(0xFF7B3FF2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthItem {
  final String label;
  final int year;
  final int month;

  const _MonthItem({required this.label, required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _MonthItem &&
              runtimeType == other.runtimeType &&
              year == other.year &&
              month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

class _Pill extends StatelessWidget {
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _Pill({
    required this.text,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFF7B3FF2)
        : enabled
        ? const Color(0xFFEDEDED)
        : const Color(0xFFEDEDED).withOpacity(0.5);

    final fg = selected
        ? Colors.white
        : enabled
        ? Colors.black87
        : Colors.black38;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Mini chart
// ---------------------------------------------------------------------
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

    const left = 6.0;
    const top = 8.0;
    const right = 6.0;
    const bottom = 10.0;

    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = top + (h / 3) * i;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF7B3FF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF7B3FF2).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = left + (w * i / max(1, (values.length - 1)));
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

    final lastX = left + w;
    final lastNorm = (values.last - minV) / range;
    final lastY = top + (h * (1 - lastNorm));
    final dotPaint = Paint()..color = const Color(0xFF7B3FF2);
    canvas.drawCircle(Offset(lastX, lastY), 3.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.values.length != values.length || oldDelegate.values != values;
  }
}
