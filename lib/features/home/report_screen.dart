import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          "AGP Report",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
        children: const [
          _RangeLine(),
          SizedBox(height: 14),
          _HeaderRow(),
          SizedBox(height: 12),
          _ReportPanel(),
          SizedBox(height: 90),
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

class _RangeLine extends StatelessWidget {
  const _RangeLine();

  @override
  Widget build(BuildContext context) {
    return const Text(
      "49 days 2023/03/01 - 2023/04/19",
      style: TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          "Glucose Statistics",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        SizedBox(
          height: 34,
          child: ElevatedButton(
            onPressed: null, // frontend-only for now
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7B3FF2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Color(0xFF7B3FF2),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 18),
            ),
            child: Text(
              "Report",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9).withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: const [
          _StatCard(
            title: "Average Glucose",
            subtitleTop: "Suggested Target <154",
            bigValue: "102.0",
            unit: "mg/dL",
            showInfo: true,
          ),
          SizedBox(height: 12),
          _StatCard(
            title: "GMI",
            subtitleTop: "Suggested Target <7%",
            bigValue: "5.1",
            unit: "%",
            showInfo: true,
          ),
          SizedBox(height: 12),
          _TimeInRangeCard(),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitleTop;
  final String bigValue;
  final String unit;
  final bool showInfo;

  const _StatCard({
    required this.title,
    required this.subtitleTop,
    required this.bigValue,
    required this.unit,
    this.showInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (showInfo) ...[
                const SizedBox(width: 6),
                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.black45),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitleTop,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bigValue,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeInRangeCard extends StatelessWidget {
  const _TimeInRangeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                "Time in Range",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(width: 6),
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.black45),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "(Range:70-140)",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Suggested Target >70%",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Text(
                "62.1%",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              Text(
                "14h54min",
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
