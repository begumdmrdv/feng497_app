import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
    (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName! : "User";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),

      body: SafeArea(
        child: Column(
          children: [
            // Purple header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF7B3FF2),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Settings icon top right
                  Row(
                    children: [
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Settings (UI only)")),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.settings, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 6),

                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Edit Profile (UI only)")),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "Edit Profile",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Menu list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
                  _MenuTile(
                    icon: Icons.event_note_rounded,
                    title: "Events",
                    showChevron: true,
                  ),
                  SizedBox(height: 10),
                  _MenuTile(
                    icon: Icons.devices_other_rounded,
                    title: "Devices",
                    showChevron: true,
                  ),
                  SizedBox(height: 10),
                  _MenuTile(
                    icon: Icons.contacts_rounded,
                    title: "Contact Persons",
                    showChevron: true,
                  ),
                  SizedBox(height: 10),
                  _MenuTile(
                    icon: Icons.notifications_active_rounded,
                    title: "Alarm Settings",
                    showChevron: true,
                    showBadge: true,
                  ),
                  SizedBox(height: 10),
                  _MenuTile(
                    icon: Icons.home_work_rounded,
                    title: "Remote Views",
                    showChevron: true,
                  ),
                  SizedBox(height: 10),
                  _MenuTile(
                    icon: Icons.help_outline_rounded,
                    title: "Help",
                    showChevron: true,
                  ),
                  SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7B3FF2),
        onPressed: () {},
        child: const Icon(Icons.smart_toy_outlined),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool showChevron;
  final bool showBadge;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.showChevron = true,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$title (UI only)")),
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF7B3FF2), size: 20),
                ),

                // tiny red dot like your Alarm Settings
                if (showBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),

            const Spacer(),

            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7B3FF2),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
