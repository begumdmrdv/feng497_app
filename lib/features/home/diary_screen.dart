import 'package:flutter/material.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),

      // Purple top bar like your design
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
          "My Diary",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        centerTitle: false,
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
          _DietProgramCard(),
          SizedBox(height: 16),
          _MealsHeader(),
          SizedBox(height: 10),
          _MealsRow(),
          SizedBox(height: 90), // breathing space above bottom nav
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

class _DietProgramCard extends StatelessWidget {
  const _DietProgramCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
                "Diet Program",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text("Details"),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Top stats + circular "Remaining Calories"
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _StatLine(title: "Active Calories", value: "1,127", unit: "kcal"),
                    SizedBox(height: 10),
                    _StatLine(title: "Burned Calories", value: "102", unit: "kcal"),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: 0.62, // dummy progress
                        strokeWidth: 10,
                        backgroundColor: Color(0xFFEDEDED),
                        valueColor: AlwaysStoppedAnimation(Color(0xFF7B3FF2)),
                      ),
                    ),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "1503",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Remaining\nCalories",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // macros row
          Row(
            children: const [
              Expanded(
                child: _MacroBlock(title: "Carbohydrate", leftText: "12 g left"),
              ),
              Expanded(
                child: _MacroBlock(title: "Protein", leftText: "30 g left"),
              ),
              Expanded(
                child: _MacroBlock(title: "Fat", leftText: "10 g left"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const _StatLine({
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(width: 4),
        Text(
          unit,
          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _MacroBlock extends StatelessWidget {
  final String title;
  final String leftText;

  const _MacroBlock({required this.title, required this.leftText});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          leftText,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _MealsHeader extends StatelessWidget {
  const _MealsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          "Meals Today",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        TextButton(onPressed: () {}, child: const Text("Customize")),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
      ],
    );
  }
}

class _MealsRow extends StatelessWidget {
  const _MealsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MealCard(
            title: "Breakfast",
            items: "Bread\nApple\nEggs",
            kcal: "525 kcal",
            color: Color(0xFF1F5EA8),
            icon: Icons.breakfast_dining_rounded,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MealCard(
            title: "Lunch",
            items: "Salmon\nAvocado\nVeggies",
            kcal: "620 kcal",
            color: Color(0xFFCDA1FF),
            icon: Icons.lunch_dining_rounded,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MealCard(
            title: "Snacks",
            items: "Puding",
            kcal: "800 kcal",
            color: Color(0xFFFFC45C),
            icon: Icons.cookie_rounded,
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final String title;
  final String items;
  final String kcal;
  final Color color;
  final IconData icon;

  const _MealCard({
    required this.title,
    required this.items,
    required this.kcal,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top illustration placeholder
          Container(
            width: double.infinity,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.28),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 34),
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
            items,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.25,
            ),
          ),

          const Spacer(),

          Text(
            kcal,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
