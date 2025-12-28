import 'package:flutter/material.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

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
          "Activity",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: "Previous day",
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "15 May",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: "Next day",
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ProgramHeader(),
          SizedBox(height: 10),
          _NextWorkoutCard(),
          SizedBox(height: 16),
          _AreaOfFocusHeader(),
          SizedBox(height: 10),
          _FocusRow(),
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

class _ProgramHeader extends StatelessWidget {
  const _ProgramHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          "Your Program",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        TextButton(onPressed: () {}, child: const Text("Details")),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
      ],
    );
  }
}

class _NextWorkoutCard extends StatelessWidget {
  const _NextWorkoutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7B3FF2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Next Workout",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Legs Training and\nGlutes Workout at Home",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1.15,
            ),
          ),
          const Spacer(),

          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              const Text(
                "68 min",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),

              // play circle
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AreaOfFocusHeader extends StatelessWidget {
  const _AreaOfFocusHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          "Area of Focus",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        TextButton(onPressed: () {}, child: const Text("More")),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
      ],
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _FocusCard(icon: Icons.fitness_center_rounded)),
        SizedBox(width: 12),
        Expanded(child: _FocusCard(icon: Icons.self_improvement_rounded)),
        SizedBox(width: 12),
        Expanded(child: _FocusCard(icon: Icons.directions_walk_rounded)),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  final IconData icon;

  const _FocusCard({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 36, color: Colors.black54),
        ),
      ),
    );
  }
}
