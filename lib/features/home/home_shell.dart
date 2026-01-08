import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'diary_screen.dart';
import 'activity_screen.dart';
import 'report_screen.dart';
import 'profile_screen.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
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
