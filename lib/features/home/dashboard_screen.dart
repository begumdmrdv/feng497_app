import 'dart:math';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ haptic + sound
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ threshold settings
import 'glucose_store.dart';

import 'package:feng497_app/features/ai/glucose_predictor.dart';
import 'package:feng497_app/features/ai/calibration_store.dart';


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
  final List<DateTime> _wsLiveTs = <DateTime>[]; // ✅ timestamps for rapid-change
  double? _wsLiveCurrentValue;

  // ✅ WS connection status (for UI)
  bool _wsConnected = false;
  String? _wsLastError;

  // true ise live data WS'ten gelir
  final bool _useWebSocketLive = true;

  // ✅ Eğer WS gelmiyorsa GEÇİCİ simulator çalışsın
  final bool _enableLocalSimulatorWhenNoWs = true;
  Timer? _simTimer;
  bool _receivedAnyWs = false;

  // ✅ WS URI
  // Emulator connect URI (do not change unless you know what you're doing)
  final Uri _wsUriConnect = Uri.parse('ws://10.0.2.2:8000/ws/stream');
  // UI display URI (screenshot style). You can set this to _wsUriConnect.toString() if you want.
  final String _wsUriDisplay = 'ws://localhost:8000/ws/stream';

  // ----------------------------
  // ✅ ON-DEVICE AI (NO BACKEND)
  // ----------------------------
  final GlucosePredictor _predictor = GlucosePredictor(windowSize: 12);
  final CalibrationStore _calibStore = CalibrationStore();
  CalibrationParams _calib = CalibrationParams.defaultParams;

  final List<SweatReading> _aiBuffer = <SweatReading>[];
  final List<double> _aiSeries = <double>[];

  double? _aiCurrentValue;
  Trend _aiTrend = Trend.flat;
  double _aiConfidence = 0.0;
  RiskLevel _aiRisk = RiskLevel.low;

  // Live kartında WS mi AI mı gösterilsin?
  final bool _showAiOnLiveCard = true;

  // ----------------------------
  // ✅ ON-DEVICE AI TIPS (NO BACKEND)
  // ----------------------------
  final AITipsEngine _tipsEngine = AITipsEngine();
  final List<TipItem> _aiTips = <TipItem>[]; // <- on-device üretilen tips burada birikir

  // ✅ Coach Tips coming from Diary (persisted)
  final List<TipItem> _coachTips = <TipItem>[];
  int _coachUpdatedAtMs = 0;
  Timer? _coachPoll;

  List<TipItem> _mergedTipsForUI() {
    // Order matters: we want the *latest* message per type.
    // We merge: backend tips (if any) + diary coach tips + on-device tips.
    final list = <TipItem>[
      ...widget.tips,
      ..._coachTips,
      ..._aiTips,
    ];
    return list;
  }

  // ----------------------------
  // ✅ ALERT SETTINGS (NO BACKEND)
  // ----------------------------
  final AlertSettingsStore _alertStore = AlertSettingsStore();
  AlertSettings _alertSettings = AlertSettings.defaults();

  // Debounce: same alert repeated too often = annoying
  DateTime? _lastAlertAt;
  AlertType? _lastAlertType;

  // Last computed rapid change rate
  double? _lastRateMgDlPerMin;

  String _riskText(RiskLevel r) {
    switch (r) {
      case RiskLevel.low:
        return "Low risk";
      case RiskLevel.medium:
        return "Medium risk";
      case RiskLevel.high:
        return "High risk";
    }
  }

  void _handleIncomingGlucose(double g) {
    final now = DateTime.now();

    // 1) raw WS series (fallback için tut)
    _wsLiveCurrentValue = g;
    _wsLiveSeries.add(g);
    _wsLiveTs.add(now);

    if (_wsLiveSeries.length > 60) _wsLiveSeries.removeAt(0);
    if (_wsLiveTs.length > 60) _wsLiveTs.removeAt(0);

    final r = SweatReading(
      ts: now,
      sweatRate: 0.0,
      temperature: 0.0,
      ph: 0.0,
      current: g,
    );

    _aiBuffer.add(r);
    if (_aiBuffer.length > 200) _aiBuffer.removeAt(0);

    final pred = _predictor.predict(_aiBuffer, calibration: _calib);
    if (pred != null) {
      _aiCurrentValue = pred.mgDl;
      _aiTrend = pred.trend;
      _aiConfidence = pred.confidence;
      _aiRisk = pred.risk30m;

      _aiSeries.add(_aiCurrentValue!);
      if (_aiSeries.length > 60) _aiSeries.removeAt(0);

      _tipsEngine.updateTips(
        target: _aiTips,
        mgDl: _aiCurrentValue!,
        trend: _aiTrend,
        risk: _aiRisk,
        confidence: _aiConfidence,
        now: now,
      );
    } else {
      _aiSeries.add(g);
      if (_aiSeries.length > 60) _aiSeries.removeAt(0);

      _tipsEngine.updateTips(
        target: _aiTips,
        mgDl: g,
        trend: Trend.flat,
        risk: RiskLevel.low,
        confidence: 0.35,
        now: now,
      );
    }

    _maybeTriggerAlerts();
  }

  void _connectWs() {
    debugPrint("WS connecting to: $_wsUriConnect");

    try {
      _channel?.sink.close();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _wsConnected = false;
        _wsLastError = null;
        _receivedAnyWs = false;
      });
    }

    _channel = WebSocketChannel.connect(_wsUriConnect);

    double? _extractGlucose(dynamic obj) {
      if (obj is num) return obj.toDouble();
      if (obj is String) {
        final s = obj.trim();
        final asNum = double.tryParse(s);
        if (asNum != null) return asNum;

        try {
          final decoded = jsonDecode(s);
          return _extractGlucose(decoded);
        } catch (_) {
          return null;
        }
      }

      if (obj is Map) {
        final m = obj.map((k, v) => MapEntry(k.toString(), v));

        if (m["glucose"] is num) return (m["glucose"] as num).toDouble();

        // 2) {"data":{"glucose":111}}
        final data = m["data"];
        if (data is Map) {
          final dm = data.map((k, v) => MapEntry(k.toString(), v));
          if (dm["glucose"] is num) return (dm["glucose"] as num).toDouble();
          if (dm["value"] is num) return (dm["value"] as num).toDouble(); // optional alt key
        }

        if ((m["type"]?.toString().toLowerCase() == "reading") &&
            (m["glucose"] is num)) {
          return (m["glucose"] as num).toDouble();
        }

        return null;
      }

      return null;
    }

    _channel!.stream.listen(
          (event) {
        debugPrint("WS raw: $event");

        double? g;
        try {
          final decoded = (event is String) ? jsonDecode(event) : event;
          g = _extractGlucose(decoded);
        } catch (_) {
          g = _extractGlucose(event);
        }

        if (g == null) {
          if (mounted) {
            setState(() {
              _wsConnected = true;
              _wsLastError = "WS payload parsed failed (no glucose field).";
            });
          }
          _startSimulatorIfNeeded();
          return;
        }

        _receivedAnyWs = true;

        _stopSimulator();

        if (!mounted) return;
        setState(() {
          _wsConnected = true;
          _wsLastError = null;
          _handleIncomingGlucose(g!);
        });
      },
      onError: (e) {
        debugPrint("WS error: $e");
        if (mounted) {
          setState(() {
            _wsConnected = false;
            _wsLastError = "WS error: $e";
          });
        }
        _startSimulatorIfNeeded();
      },
      onDone: () {
        debugPrint("WS closed");
        if (mounted) {
          setState(() {
            _wsConnected = false;
            _wsLastError = "WS closed";
          });
        }
        _startSimulatorIfNeeded();
      },
    );
  }

  void _startSimulatorIfNeeded() {
    if (!_enableLocalSimulatorWhenNoWs) return;
    if (_receivedAnyWs) return; // WS bir kez bile geldiyse sim başlatma
    if (_simTimer != null) return;

    debugPrint("Simulator started (no WS data).");

    final rng = Random();
    double v = 110.0;

    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // küçük drift + gürültü
      v += (rng.nextDouble() * 2 - 1) * 2.0;
      v += sin(DateTime.now().millisecondsSinceEpoch / 5000.0) * 1.0;
      v = v.clamp(70.0, 220.0);

      if (!mounted) return;
      setState(() {
        // simulator çalışıyorsa ws kapalı say
        _wsConnected = false;
        _wsLastError ??= "Using simulator (no WS data)";
        _handleIncomingGlucose(v);
      });
    });
  }

  void _stopSimulator() {
    _simTimer?.cancel();
    _simTimer = null;
  }

  // ----------------------------------------
  // ✅ ALERT ENGINE (in-app, no backend)
  // ----------------------------------------
  void _maybeTriggerAlerts() {
    // We show alerts based on the value shown on live card:
    final bool aiEnabled = _showAiOnLiveCard && _aiSeries.isNotEmpty;

    final double? value =
    aiEnabled ? (_aiCurrentValue ?? _wsLiveCurrentValue) : _wsLiveCurrentValue;

    if (value == null) return;

    // Rapid change mg/dL per min
    _lastRateMgDlPerMin = _computeRateMgDlPerMin();

    final now = DateTime.now();
    final inQuietHours = _alertSettings.isInQuietHours(now);

    // Determine alert type (priority order)
    AlertType? type;

    // Threshold alerts
    if (value <= _alertSettings.lowThreshold) {
      type = AlertType.low;
    } else if (value >= _alertSettings.highThreshold) {
      type = AlertType.high;
    }

    // Rapid change alert (if enabled) — only if not already low/high
    if (type == null && _alertSettings.rapidChangeEnabled) {
      final rate = _lastRateMgDlPerMin;
      if (rate != null) {
        if (rate <= -_alertSettings.rapidDropThresholdMgDlPerMin) {
          type = AlertType.rapidDrop;
        } else if (rate >= _alertSettings.rapidRiseThresholdMgDlPerMin) {
          type = AlertType.rapidRise;
        }
      }
    }

    if (type == null) return;

    // Debounce
    if (_lastAlertAt != null && _lastAlertType != null) {
      final dt = now.difference(_lastAlertAt!).inSeconds;
      if (_lastAlertType == type && dt < _alertSettings.debounceSeconds) {
        return;
      }
    }

    // Quiet hours behavior:
    // - If quiet hours, suppress sound for non-critical.
    // - But for critical low, always do strong alert.
    final bool critical = (type == AlertType.low);

    // Haptic + sound
    if (_alertSettings.soundEnabled && (!inQuietHours || critical)) {
      SystemSound.play(SystemSoundType.alert);
    }
    if (_alertSettings.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }

    // In-app banner
    _showAlertSnack(type, value);

    _lastAlertAt = now;
    _lastAlertType = type;
  }

  double? _computeRateMgDlPerMin() {
    // Need at least 2 points with ts
    if (_wsLiveSeries.length < 2 || _wsLiveTs.length < 2) return null;

    // Use last ~6 points window for smoother rate (or all available)
    final int n = min(6, _wsLiveSeries.length);
    final startIdx = _wsLiveSeries.length - n;

    final v0 = _wsLiveSeries[startIdx];
    final t0 = _wsLiveTs[startIdx];
    final v1 = _wsLiveSeries.last;
    final t1 = _wsLiveTs.last;

    final dtSec = t1.difference(t0).inMilliseconds / 1000.0;
    if (dtSec <= 0.5) return null;

    final dv = v1 - v0;
    final ratePerMin = dv / (dtSec / 60.0);
    return ratePerMin;
  }

  void _showAlertSnack(AlertType type, double value) {
    if (!mounted) return;

    final msg = switch (type) {
      AlertType.low => "LOW glucose: ${value.toStringAsFixed(0)} mg/dl",
      AlertType.high => "HIGH glucose: ${value.toStringAsFixed(0)} mg/dl",
      AlertType.rapidDrop =>
      "Rapid drop detected (${_lastRateMgDlPerMin?.toStringAsFixed(1)} mg/dl/min)",
      AlertType.rapidRise =>
      "Rapid rise detected (${_lastRateMgDlPerMin?.toStringAsFixed(1)} mg/dl/min)",
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w800)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: "Settings",
          onPressed: _openAlertSettingsSheet,
        ),
      ),
    );
  }

  Future<void> _openAlertSettingsSheet() async {
    final updated = await showModalBottomSheet<AlertSettings>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AlertSettingsSheet(initial: _alertSettings),
    );

    if (updated != null) {
      setState(() => _alertSettings = updated);
      await _alertStore.save(updated);
    }
  }

  void _openEmergencyDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Emergency Help"),
        content: const Text(
          "This is a demo emergency flow (no backend / no SMS).\n\n"
              "In the real app, this would notify your selected caregiver/doctor with your latest glucose + trend + location link.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }


  // ----------------------------
  // ✅ Diary → Dashboard Coach Tips sync (SharedPreferences polling)
  // ----------------------------
  Future<void> _pullCoachTipsOnce() async {
    final snap = await CoachTipsStore.load();
    if (!mounted) return;

    if (snap.updatedAtMs == 0 || snap.updatedAtMs == _coachUpdatedAtMs) return;

    final now = DateTime.now();
    TipItem make(TipType type, String key, String fallback) {
      final msg = (snap.tips[key] ?? "").trim();
      return TipItem(
        type: type,
        message: msg.isEmpty ? fallback : msg,
        createdAt: DateTime.fromMillisecondsSinceEpoch(snap.updatedAtMs).toLocal(),
      );
    }

    setState(() {
      _coachUpdatedAtMs = snap.updatedAtMs;
      _coachTips
        ..clear()
        ..addAll([
          make(TipType.food, "food", "Log meals to get food tips tailored to your day."),
          make(TipType.exercise, "exercise", "Light walks after meals can help smooth glucose."),
          make(TipType.medicine, "medicine", "Medication tips are general—follow your clinician’s guidance."),
        ]);
    });
  }

  void _startCoachTipsPolling() {
    _coachPoll?.cancel();
    // Pull immediately and then poll.
    _pullCoachTipsOnce();
    _coachPoll = Timer.periodic(const Duration(seconds: 2), (_) {
      _pullCoachTipsOnce();
    });
  }

  void _stopCoachTipsPolling() {
    _coachPoll?.cancel();
    _coachPoll = null;
  }


  @override
  void initState() {
    super.initState();
    _months = _buildLast12Months();
    _setDailyMode();

    // ✅ Seed tips so UI never looks empty before data
    _tipsEngine.seedIfNeeded(_aiTips);

    // ✅ Sync Coach Tips from Diary (shows on Home screen)
    _startCoachTipsPolling();

    // ✅ Load calibration
    _calibStore.load().then((c) {
      if (!mounted) return;
      setState(() => _calib = c);
    });

    // ✅ Load alert settings
    _alertStore.load().then((s) {
      if (!mounted) return;
      setState(() => _alertSettings = s);
    });

    // ✅ Start WS
    if (_useWebSocketLive) {
      _connectWs();

      // WS 2-3 sn içinde gelmezse simulator başlat
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (!_receivedAnyWs) _startSimulatorIfNeeded();
      });
    } else {
      _startSimulatorIfNeeded();
    }
  }

  @override
  void dispose() {
    _stopCoachTipsPolling();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _stopSimulator();
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
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${names[d.month - 1]} - ${d.year}";
  }

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

    // Raw live source
    final liveSeriesRaw = _useWebSocketLive ? _wsLiveSeries : widget.liveSeries;

    final liveValueRaw = _useWebSocketLive
        ? _wsLiveCurrentValue
        : (widget.liveCurrentValue ??
        (liveSeriesRaw.isNotEmpty ? liveSeriesRaw.last : null));

    // ✅ If enabled, show AI on Live card
    final bool aiEnabled = _showAiOnLiveCard && _aiSeries.isNotEmpty;

    final liveValueShown = aiEnabled ? (_aiCurrentValue ?? liveValueRaw) : liveValueRaw;
    final liveSeriesShown = aiEnabled
        ? (_aiSeries.isNotEmpty ? _aiSeries : liveSeriesRaw)
        : liveSeriesRaw;

    final liveTrendUp = aiEnabled
        ? (_aiTrend == Trend.up
        ? true
        : (_aiTrend == Trend.down
        ? false
        : (liveSeriesShown.length >= 2
        ? liveSeriesShown.last >= liveSeriesShown[liveSeriesShown.length - 2]
        : true)))
        : (liveSeriesShown.length >= 2
        ? liveSeriesShown.last >= liveSeriesShown[liveSeriesShown.length - 2]
        : true);

    final chartSeries = _monthlyMode ? _monthlySeries : _dailySeries;
    final mainValue = _monthlyMode ? _monthlyAvgValue : _dailyCurrentValue;

    final trendUp = chartSeries.length >= 2
        ? chartSeries.last >= chartSeries[chartSeries.length - 2]
        : true;

    // last update time (from any incoming glucose)
    final DateTime? lastUpdate =
    _wsLiveTs.isNotEmpty ? _wsLiveTs.last : null;

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
          IconButton(
            onPressed: _openAlertSettingsSheet,
            icon: const Icon(Icons.tune_rounded),
            tooltip: "Alert settings",
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
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
                    liveValue: liveValueShown,
                    trendUp: liveTrendUp,
                    series: liveSeriesShown,
                    aiEnabled: aiEnabled,
                    aiConfidence: _aiConfidence,
                    aiRiskLabel: _riskText(_aiRisk),

                    lowThreshold: _alertSettings.lowThreshold,
                    highThreshold: _alertSettings.highThreshold,
                    rateMgDlPerMin: _lastRateMgDlPerMin,
                    onOpenSettings: _openAlertSettingsSheet,
                    onEmergency: _openEmergencyDialog,

                    // ✅ NEW (screenshot-style live WS header)
                    wsLabel: _wsConnected ? "WS: Open" : "WS: Closed",
                    wsUri: _wsUriDisplay,
                    onReconnect: _connectWs,
                    lastUpdate: lastUpdate,
                    wsError: _wsLastError,
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

                  _TipsCardsAlwaysVisible(tips: _mergedTipsForUI()),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// ✅ Alerts settings model/store (NO BACKEND)
// ---------------------------------------------------------------------
enum AlertType { low, high, rapidDrop, rapidRise }

class AlertSettings {
  final double lowThreshold; // mg/dl
  final double highThreshold; // mg/dl

  final bool rapidChangeEnabled;
  final double rapidDropThresholdMgDlPerMin;
  final double rapidRiseThresholdMgDlPerMin;

  final bool soundEnabled;
  final bool vibrationEnabled;

  final bool quietHoursEnabled;
  final int quietStartHour; // 0-23
  final int quietEndHour; // 0-23

  final int debounceSeconds;

  const AlertSettings({
    required this.lowThreshold,
    required this.highThreshold,
    required this.rapidChangeEnabled,
    required this.rapidDropThresholdMgDlPerMin,
    required this.rapidRiseThresholdMgDlPerMin,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.quietHoursEnabled,
    required this.quietStartHour,
    required this.quietEndHour,
    required this.debounceSeconds,
  });

  factory AlertSettings.defaults() => const AlertSettings(
    lowThreshold: 70,
    highThreshold: 170,
    rapidChangeEnabled: true,
    rapidDropThresholdMgDlPerMin: 3.0,
    rapidRiseThresholdMgDlPerMin: 3.0,
    soundEnabled: true,
    vibrationEnabled: true,
    quietHoursEnabled: true,
    quietStartHour: 23,
    quietEndHour: 7,
    debounceSeconds: 20,
  );

  bool isInQuietHours(DateTime now) {
    if (!quietHoursEnabled) return false;

    final h = now.hour;
    if (quietStartHour == quietEndHour) return false;

    // Example: 23 -> 7 crosses midnight
    if (quietStartHour > quietEndHour) {
      return h >= quietStartHour || h < quietEndHour;
    }
    // Example: 21 -> 23 (same day)
    return h >= quietStartHour && h < quietEndHour;
  }

  Map<String, dynamic> toJson() => {
    'low': lowThreshold,
    'high': highThreshold,
    'rapidOn': rapidChangeEnabled,
    'rapidDrop': rapidDropThresholdMgDlPerMin,
    'rapidRise': rapidRiseThresholdMgDlPerMin,
    'sound': soundEnabled,
    'vibe': vibrationEnabled,
    'quietOn': quietHoursEnabled,
    'quietStart': quietStartHour,
    'quietEnd': quietEndHour,
    'debounce': debounceSeconds,
  };

  static AlertSettings fromJson(Map<String, dynamic> m) {
    double d(String k, double def) => (m[k] is num) ? (m[k] as num).toDouble() : def;
    int i(String k, int def) =>
        (m[k] is int) ? m[k] as int : ((m[k] is num) ? (m[k] as num).toInt() : def);
    bool b(String k, bool def) => (m[k] is bool) ? (m[k] as bool) : def;

    return AlertSettings(
      lowThreshold: d('low', 70),
      highThreshold: d('high', 170),
      rapidChangeEnabled: b('rapidOn', true),
      rapidDropThresholdMgDlPerMin: d('rapidDrop', 3.0),
      rapidRiseThresholdMgDlPerMin: d('rapidRise', 3.0),
      soundEnabled: b('sound', true),
      vibrationEnabled: b('vibe', true),
      quietHoursEnabled: b('quietOn', true),
      quietStartHour: i('quietStart', 23).clamp(0, 23),
      quietEndHour: i('quietEnd', 7).clamp(0, 23),
      debounceSeconds: i('debounce', 20).clamp(5, 120),
    );
  }

  AlertSettings copyWith({
    double? lowThreshold,
    double? highThreshold,
    bool? rapidChangeEnabled,
    double? rapidDropThresholdMgDlPerMin,
    double? rapidRiseThresholdMgDlPerMin,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    int? debounceSeconds,
  }) {
    return AlertSettings(
      lowThreshold: lowThreshold ?? this.lowThreshold,
      highThreshold: highThreshold ?? this.highThreshold,
      rapidChangeEnabled: rapidChangeEnabled ?? this.rapidChangeEnabled,
      rapidDropThresholdMgDlPerMin:
      rapidDropThresholdMgDlPerMin ?? this.rapidDropThresholdMgDlPerMin,
      rapidRiseThresholdMgDlPerMin:
      rapidRiseThresholdMgDlPerMin ?? this.rapidRiseThresholdMgDlPerMin,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      debounceSeconds: debounceSeconds ?? this.debounceSeconds,
    );
  }
}

class AlertSettingsStore {
  static const _key = 'alert_settings_v1';

  Future<AlertSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return AlertSettings.defaults();
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        return AlertSettings.fromJson(m.map((k, v) => MapEntry(k.toString(), v)));
      }
      return AlertSettings.defaults();
    } catch (_) {
      return AlertSettings.defaults();
    }
  }

  Future<void> save(AlertSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(s.toJson()));
  }
}

class _AlertSettingsSheet extends StatefulWidget {
  final AlertSettings initial;
  const _AlertSettingsSheet({required this.initial});

  @override
  State<_AlertSettingsSheet> createState() => _AlertSettingsSheetState();
}

class _AlertSettingsSheetState extends State<_AlertSettingsSheet> {
  late AlertSettings s;



  @override
  void initState() {
    super.initState();
    s = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    Widget row(String title, Widget trailing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
            trailing,
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + pad),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Alert settings", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),

            row(
              "Low threshold (mg/dl)",
              _NumberStepper(
                value: s.lowThreshold,
                min: 40,
                max: 120,
                step: 5,
                onChanged: (v) => setState(() => s = s.copyWith(lowThreshold: v)),
              ),
            ),
            row(
              "High threshold (mg/dl)",
              _NumberStepper(
                value: s.highThreshold,
                min: 120,
                max: 300,
                step: 5,
                onChanged: (v) => setState(() => s = s.copyWith(highThreshold: v)),
              ),
            ),

            const SizedBox(height: 8),
            SwitchListTile(
              value: s.rapidChangeEnabled,
              onChanged: (v) => setState(() => s = s.copyWith(rapidChangeEnabled: v)),
              title: const Text("Rapid change alerts", style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text("Warn if glucose rises/drops too fast."),
            ),
            if (s.rapidChangeEnabled) ...[
              row(
                "Rapid drop (mg/dl/min)",
                _NumberStepper(
                  value: s.rapidDropThresholdMgDlPerMin,
                  min: 1,
                  max: 10,
                  step: 0.5,
                  onChanged: (v) => setState(() => s = s.copyWith(rapidDropThresholdMgDlPerMin: v)),
                ),
              ),
              row(
                "Rapid rise (mg/dl/min)",
                _NumberStepper(
                  value: s.rapidRiseThresholdMgDlPerMin,
                  min: 1,
                  max: 10,
                  step: 0.5,
                  onChanged: (v) => setState(() => s = s.copyWith(rapidRiseThresholdMgDlPerMin: v)),
                ),
              ),
            ],

            const SizedBox(height: 8),
            SwitchListTile(
              value: s.soundEnabled,
              onChanged: (v) => setState(() => s = s.copyWith(soundEnabled: v)),
              title: const Text("Sound", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            SwitchListTile(
              value: s.vibrationEnabled,
              onChanged: (v) => setState(() => s = s.copyWith(vibrationEnabled: v)),
              title: const Text("Vibration", style: TextStyle(fontWeight: FontWeight.w800)),
            ),

            const SizedBox(height: 8),
            SwitchListTile(
              value: s.quietHoursEnabled,
              onChanged: (v) => setState(() => s = s.copyWith(quietHoursEnabled: v)),
              title: const Text("Quiet hours", style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text("Reduce sound at night (critical low still alerts)."),
            ),
            if (s.quietHoursEnabled) ...[
              row(
                "Quiet start hour",
                _IntStepper(
                  value: s.quietStartHour,
                  min: 0,
                  max: 23,
                  onChanged: (v) => setState(() => s = s.copyWith(quietStartHour: v)),
                ),
              ),
              row(
                "Quiet end hour",
                _IntStepper(
                  value: s.quietEndHour,
                  min: 0,
                  max: 23,
                  onChanged: (v) => setState(() => s = s.copyWith(quietEndHour: v)),
                ),
              ),
            ],

            const SizedBox(height: 8),
            row(
              "Alert debounce (sec)",
              _IntStepper(
                value: s.debounceSeconds,
                min: 5,
                max: 120,
                onChanged: (v) => setState(() => s = s.copyWith(debounceSeconds: v)),
              ),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B3FF2)),
                    onPressed: () => Navigator.pop(context, s),
                    child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    void dec() => onChanged((value - step).clamp(min, max));
    void inc() => onChanged((value + step).clamp(min, max));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: dec, icon: const Icon(Icons.remove_circle_outline)),
        Text(value.toStringAsFixed(step < 1 ? 1 : 0), style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(onPressed: inc, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }
}

class _IntStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _IntStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    void dec() => onChanged((value - 1).clamp(min, max));
    void inc() => onChanged((value + 1).clamp(min, max));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: dec, icon: const Icon(Icons.remove_circle_outline)),
        Text("$value", style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(onPressed: inc, icon: const Icon(Icons.add_circle_outline)),
      ],
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
// ✅ On-device "AI tips" engine (NO BACKEND)
// ---------------------------------------------------------------------
class AITipsEngine {
  static const Duration _minInterval = Duration(seconds: 45);
  final Map<TipType, DateTime> _lastAt = <TipType, DateTime>{};

  void seedIfNeeded(List<TipItem> target) {
    if (target.isNotEmpty) return;
    final now = DateTime.now();
    target.addAll([
      TipItem(
        type: TipType.food,
        message: "When data arrives, I’ll suggest foods based on your trend/risk.",
        createdAt: now,
      ),
      TipItem(
        type: TipType.exercise,
        message: "Light activity tips will appear here once we detect patterns.",
        createdAt: now,
      ),
      TipItem(
        type: TipType.medicine,
        message: "Medication tips are general only—always follow your clinician’s plan.",
        createdAt: now,
      ),
    ]);
  }

  void updateTips({
    required List<TipItem> target,
    required double mgDl,
    required Trend trend,
    required RiskLevel risk,
    required double confidence,
    required DateTime now,
  }) {
    final allow = confidence >= 0.45 || risk != RiskLevel.low;
    if (!allow) return;

    _maybeAdd(target, TipType.food, now, _foodTip(mgDl, trend, risk));
    _maybeAdd(target, TipType.exercise, now, _exerciseTip(mgDl, trend, risk));
    _maybeAdd(target, TipType.medicine, now, _medicineTip(mgDl, trend, risk));

    if (target.length > 60) {
      target.removeRange(0, target.length - 60);
    }
  }

  void _maybeAdd(List<TipItem> target, TipType type, DateTime now, String msg) {
    final last = _lastAt[type];
    if (last != null && now.difference(last) < _minInterval) return;

    final latestSameType = target.where((t) => t.type == type).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    if (latestSameType.isNotEmpty && latestSameType.first.message == msg) return;

    target.add(TipItem(type: type, message: msg, createdAt: now));
    _lastAt[type] = now;
  }

  String _foodTip(double g, Trend t, RiskLevel r) {
    if (r == RiskLevel.high && t == Trend.down) {
      return "Glucose falling fast: consider a quick carb source if you feel symptoms, then re-check.";
    }
    if (r == RiskLevel.high && t == Trend.up) {
      return "Glucose rising: choose water + lower-carb options for the next snack/meal.";
    }
    if (g < 90) {
      return "On the lower side: pair carbs with protein/fat (e.g., yogurt + fruit) to stabilize.";
    }
    if (g > 180) {
      return "High range: prefer fiber/protein-heavy foods (vegetables, eggs, legumes) and skip sugary drinks.";
    }
    return "Stable range: keep balanced meals (protein + fiber + moderate carbs) to maintain this trend.";
  }

  String _exerciseTip(double g, Trend t, RiskLevel r) {
    if (r == RiskLevel.high && t == Trend.down) {
      return "If glucose is dropping, avoid intense exercise until it stabilizes.";
    }
    if (g > 200 && t != Trend.down) {
      return "If you feel okay, a short walk after meals can help reduce spikes.";
    }
    if (g < 90) {
      return "Lower range: choose light movement only and carry fast carbs just in case.";
    }
    return "Good time for light-to-moderate activity: 10–20 min walk or gentle stretching.";
  }

  String _medicineTip(double g, Trend t, RiskLevel r) {
    if (r == RiskLevel.high) {
      return "Risk elevated: follow your care plan and consider contacting a clinician if readings stay abnormal.";
    }
    if (g < 80) {
      return "If you’re on glucose-lowering meds, monitor closely when low readings happen.";
    }
    if (g > 250) {
      return "If readings are persistently very high, follow your clinician guidance (hydration, ketone check if applicable).";
    }
    return "General reminder: take meds as prescribed; this app doesn’t adjust doses.";
  }
}

// ---------------------------------------------------------------------
// Live card (NOW: screenshot-style WS + status + last update)
// ---------------------------------------------------------------------
class _LiveGlucoseCard extends StatelessWidget {
  final double? liveValue;
  final bool trendUp;
  final List<double> series;

  final bool aiEnabled;
  final double aiConfidence;
  final String aiRiskLabel;

  final double lowThreshold;
  final double highThreshold;
  final double? rateMgDlPerMin;
  final VoidCallback onOpenSettings;
  final VoidCallback onEmergency;

  // ✅ NEW (WS header)
  final String wsLabel;
  final String wsUri;
  final VoidCallback onReconnect;
  final DateTime? lastUpdate;
  final String? wsError;

  const _LiveGlucoseCard({
    required this.liveValue,
    required this.trendUp,
    required this.series,
    this.aiEnabled = false,
    this.aiConfidence = 0.0,
    this.aiRiskLabel = "",

    required this.lowThreshold,
    required this.highThreshold,
    required this.rateMgDlPerMin,
    required this.onOpenSettings,
    required this.onEmergency,

    required this.wsLabel,
    required this.wsUri,
    required this.onReconnect,
    required this.lastUpdate,
    required this.wsError,
  });

  String _fmtTime(DateTime? t) {
    if (t == null) return "";
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    final hasData = series.isNotEmpty && liveValue != null;

    final bool isLow = hasData && liveValue! <= lowThreshold;
    final bool isHigh = hasData && liveValue! >= highThreshold;

    final String statusText = !hasData
        ? ""
        : isLow
        ? "LOW"
        : isHigh
        ? "HIGH"
        : "NORMAL";

    final Color statusColor = !hasData
        ? const Color(0xFF4AA3A5)
        : (isLow || isHigh)
        ? Colors.redAccent
        : const Color(0xFF4AA3A5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + LIVE chip
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
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 10, color: Color(0xFF7B3FF2)),
                    const SizedBox(width: 6),
                    Text(
                      aiEnabled ? "AI LIVE" : "LIVE",
                      style: const TextStyle(
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

          // WS row (screenshot-style)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  wsLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wsUri,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black54),
                ),
              ),
              IconButton(
                tooltip: "Reconnect",
                onPressed: onReconnect,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),

          if (wsError != null && wsError!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              wsError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Value + status pill (screenshot-style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!hasData) ...[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ] else ...[
                Text(
                  liveValue!.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: (isLow || isHigh) ? Colors.redAccent : Colors.black,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    "mg/dL",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.45)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Last update
          Text(
            lastUpdate == null ? "" : "Last update: ${_fmtTime(lastUpdate)}",
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),

          // (Keep your AI info line — optional)
          if (hasData && aiEnabled) ...[
            const SizedBox(height: 6),
            Text(
              aiConfidence <= 0.01
                  ? "AI: $aiRiskLabel • Calibrating…"
                  : "AI: $aiRiskLabel • Confidence ${(aiConfidence * 100).round()}%",
              style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600, fontSize: 11),
              maxLines: 1,
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
          other is _MonthItem && runtimeType == other.runtimeType && year == other.year && month == other.month;

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

    final fg = selected ? Colors.white : (enabled ? Colors.black87 : Colors.black38);

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