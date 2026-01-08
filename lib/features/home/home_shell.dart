import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'diary_screen.dart';
import 'activity_screen.dart';
import 'report_screen.dart';
import 'profile_screen.dart';

// ✅ NEW: Keep storage lean when app runs
import 'glucose_store.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = const [
    DashboardScreen(),
    DiaryScreen(),
    ActivityScreen(),
    ReportScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // ✅ NEW: prune old glucose samples once at app start (no backend needed)
    _pruneGlucoseSamples();
  }

  Future<void> _pruneGlucoseSamples() async {
    try {
      await GlucoseStore.prune(days: 30);
    } catch (_) {
      // Don't crash if storage is corrupted or missing
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ NEW: preserves each tab's state (scroll position, local UI state, etc.)
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6C2BD9),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: "Diary",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run_rounded),
            label: "Activity",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_rounded),
            label: "Report",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
