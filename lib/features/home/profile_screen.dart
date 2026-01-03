import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    final displayName = _user?.displayName?.trim();
    final email = _user?.email ?? "";
    final nameShown = (displayName != null && displayName.isNotEmpty) ? displayName : "Your Profile";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),

      floatingActionButton: null,

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                    color: Colors.black.withOpacity(0.16),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nameShown,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email.isEmpty ? "Not signed in" : email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.86),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _openEditProfile,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded, size: 16, color: Colors.white.withOpacity(0.95)),
                              const SizedBox(width: 6),
                              Text(
                                "Edit Profile",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openSettingsSheet,
                    icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Menu items
            _MenuTile(
              title: "Events",
              icon: Icons.event_note_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventsScreen())),
            ),
            const SizedBox(height: 10),

            _MenuTile(
              title: "Devices",
              icon: Icons.devices_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevicesScreen())),
            ),
            const SizedBox(height: 10),

            _MenuTile(
              title: "Contact Persons",
              icon: Icons.group_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactPersonsScreen())),
            ),
            const SizedBox(height: 10),

            _MenuTile(
              title: "Alarm Settings",
              icon: Icons.notifications_active_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlarmSettingsScreen())),
            ),
            const SizedBox(height: 10),

            _MenuTile(
              title: "Remote Views",
              icon: Icons.cast_connected_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemoteViewsScreen())),
            ),
            const SizedBox(height: 10),

            _MenuTile(
              title: "Help",
              icon: Icons.help_outline_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (mounted) setState(() {});
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetTitle(title: "Settings"),
              const SizedBox(height: 10),
              _SheetAction(
                icon: Icons.logout_rounded,
                title: "Sign Out",
                subtitle: "Log out from your account",
                onTap: _signOut,
                danger: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    Navigator.of(context).pop(); // close sheet
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF7B3FF2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7B3FF2)),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================================
   EDIT PROFILE
================================ */

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameC = TextEditingController();
  bool _saving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameC.text = _user?.displayName ?? "";
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      _toast("Please enter your name.");
      return;
    }
    setState(() => _saving = true);
    try {
      await _user?.updateDisplayName(name);
      await _user?.reload();
      if (!mounted) return;
      _toast("Profile updated ✅");
      Navigator.of(context).pop();
    } catch (_) {
      _toast("Could not update profile.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Edit Profile"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Display Name", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameC,
                  decoration: const InputDecoration(
                    hintText: "Your name",
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Save", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ================================
   EVENTS (saved timeline)
================================ */

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _k = "dg_events_v1";
  bool _loading = true;
  List<_EventItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    final decoded = (raw == null) ? [] : (jsonDecode(raw) as List);
    _items = decoded.map((e) => _EventItem.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    if (mounted) setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _add() async {
    final res = await showDialog<_EventItem>(
      context: context,
      builder: (_) => const _AddEventDialog(),
    );
    if (res == null) return;
    setState(() {
      _items.insert(0, res);
    });
    await _save();
    _toast("Event added ✅");
  }

  Future<void> _delete(int index) async {
    final removed = _items[index];
    setState(() => _items.removeAt(index));
    await _save();
    _toast("Deleted: ${removed.title}");
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Events"),
        actions: [
          IconButton(onPressed: _add, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty)
          ? const Center(child: Text("No events yet. Tap + to add."))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final e = _items[i];
          return _Card(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(e.icon, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(e.note, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        _fmt(e.at),
                        style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _delete(i),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) {
    final two = (int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year} • ${two(d.hour)}:${two(d.minute)}";
  }
}

class _AddEventDialog extends StatefulWidget {
  const _AddEventDialog();

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  final _titleC = TextEditingController();
  final _noteC = TextEditingController();
  _EventType _type = _EventType.meal;

  @override
  void dispose() {
    _titleC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return AlertDialog(
      title: const Text("Add Event"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<_EventType>(
            value: _type,
            items: _EventType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
            decoration: const InputDecoration(
              labelText: "Type",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleC,
            decoration: const InputDecoration(
              labelText: "Title",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteC,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Note",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primary),
          onPressed: () {
            final title = _titleC.text.trim();
            final note = _noteC.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              _EventItem(
                title: title,
                note: note.isEmpty ? "—" : note,
                type: _type.name,
                at: DateTime.now(),
              ),
            );
          },
          child: const Text("Add"),
        ),
      ],
    );
  }
}

enum _EventType { meal, insulin, exercise, note }

extension on _EventType {
  String get label {
    switch (this) {
      case _EventType.meal:
        return "Meal";
      case _EventType.insulin:
        return "Insulin";
      case _EventType.exercise:
        return "Exercise";
      case _EventType.note:
        return "Note";
    }
  }
}

class _EventItem {
  final String title;
  final String note;
  final String type;
  final DateTime at;

  _EventItem({
    required this.title,
    required this.note,
    required this.type,
    required this.at,
  });

  IconData get icon {
    switch (type) {
      case 'insulin':
        return Icons.medication_rounded;
      case 'exercise':
        return Icons.directions_run_rounded;
      case 'note':
        return Icons.sticky_note_2_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
    "title": title,
    "note": note,
    "type": type,
    "at": at.toIso8601String(),
  };

  static _EventItem fromJson(Map<String, dynamic> j) => _EventItem(
    title: (j["title"] ?? "").toString(),
    note: (j["note"] ?? "").toString(),
    type: (j["type"] ?? "meal").toString(),
    at: DateTime.tryParse((j["at"] ?? "").toString()) ?? DateTime.now(),
  );
}

/* ================================
   DEVICES (simple registry)
================================ */

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  static const _k = "dg_devices_v1";
  bool _loading = true;
  List<String> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _devices = sp.getStringList(_k) ?? [];
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_k, _devices);
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Device"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            hintText: "e.g. DermaGly Patch #1",
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );
    c.dispose();

    if (name == null || name.isEmpty) return;

    setState(() => _devices.insert(0, name));
    await _save();
  }

  Future<void> _remove(int i) async {
    setState(() => _devices.removeAt(i));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Devices"),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_devices.isEmpty)
          ? const Center(child: Text("No devices yet. Tap + to add."))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = _devices[i];
          return _Card(
            child: Row(
              children: [
                const Icon(Icons.sensors_rounded, color: primary),
                const SizedBox(width: 10),
                Expanded(child: Text(d, style: const TextStyle(fontWeight: FontWeight.w900))),
                IconButton(
                  onPressed: () => _remove(i),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ================================
   CONTACT PERSONS (name + phone)
================================ */

class ContactPersonsScreen extends StatefulWidget {
  const ContactPersonsScreen({super.key});

  @override
  State<ContactPersonsScreen> createState() => _ContactPersonsScreenState();
}

class _ContactPersonsScreenState extends State<ContactPersonsScreen> {
  static const _k = "dg_contacts_v1";
  bool _loading = true;
  List<_Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    final decoded = (raw == null) ? [] : (jsonDecode(raw) as List);
    _contacts = decoded.map((e) => _Contact.fromJson(e as Map<String, dynamic>)).toList();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(_contacts.map((e) => e.toJson()).toList()));
  }

  Future<void> _add() async {
    final res = await showDialog<_Contact>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (res == null) return;
    setState(() => _contacts.insert(0, res));
    await _save();
  }

  Future<void> _remove(int i) async {
    setState(() => _contacts.removeAt(i));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Contact Persons"),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_contacts.isEmpty)
          ? const Center(child: Text("No contacts yet. Tap + to add."))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _contacts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final c = _contacts[i];
          return _Card(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_rounded, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(c.phone, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _remove(i),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Contact"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameC,
            decoration: const InputDecoration(
              labelText: "Name",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneC,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "Phone",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        TextButton(
          onPressed: () {
            final n = _nameC.text.trim();
            final p = _phoneC.text.trim();
            if (n.isEmpty || p.isEmpty) return;
            Navigator.pop(context, _Contact(name: n, phone: p));
          },
          child: const Text("Add"),
        ),
      ],
    );
  }
}

class _Contact {
  final String name;
  final String phone;

  _Contact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {"name": name, "phone": phone};
  static _Contact fromJson(Map<String, dynamic> j) => _Contact(
    name: (j["name"] ?? "").toString(),
    phone: (j["phone"] ?? "").toString(),
  );
}

/* ================================
   ALARM SETTINGS
================================ */

class AlarmSettingsScreen extends StatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  static const _k = "dg_alarm_v1";

  bool _loading = true;
  bool _enabled = true;
  int _low = 70;
  int _high = 180;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _enabled = (j["enabled"] ?? true) as bool;
      _low = (j["low"] ?? 70) as int;
      _high = (j["high"] ?? 180) as int;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode({"enabled": _enabled, "low": _low, "high": _high}));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Alarm Settings"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: SwitchListTile(
              value: _enabled,
              onChanged: (v) async {
                setState(() => _enabled = v);
                await _save();
              },
              title: const Text("Enable Alerts", style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text("Show warning when glucose is out of range"),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Thresholds (mg/dL)", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _NumberRow(
                  label: "Low",
                  value: _low,
                  onMinus: () async {
                    setState(() => _low = (_low - 1).clamp(40, 120));
                    await _save();
                  },
                  onPlus: () async {
                    setState(() => _low = (_low + 1).clamp(40, 120));
                    await _save();
                  },
                ),
                const SizedBox(height: 10),
                _NumberRow(
                  label: "High",
                  value: _high,
                  onMinus: () async {
                    setState(() => _high = (_high - 1).clamp(120, 350));
                    await _save();
                  },
                  onPlus: () async {
                    setState(() => _high = (_high + 1).clamp(120, 350));
                    await _save();
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      _toast("Saved ✅  Low: $_low  High: $_high");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _NumberRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline_rounded)),
        Text("$value", style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline_rounded)),
      ],
    );
  }
}

/* ================================
   REMOTE VIEWS (share code)
================================ */

class RemoteViewsScreen extends StatefulWidget {
  const RemoteViewsScreen({super.key});

  @override
  State<RemoteViewsScreen> createState() => _RemoteViewsScreenState();
}

class _RemoteViewsScreenState extends State<RemoteViewsScreen> {
  static const _k = "dg_remote_code_v1";
  bool _loading = true;
  bool _enabled = false;
  String _code = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _genCode() {
    final chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final r = Random();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _enabled = sp.getBool("${_k}_enabled") ?? false;
    _code = sp.getString(_k) ?? _genCode();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool("${_k}_enabled", _enabled);
    await sp.setString(_k, _code);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Remote Views"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: SwitchListTile(
              value: _enabled,
              onChanged: (v) async {
                setState(() => _enabled = v);
                await _save();
              },
              title: const Text("Enable Remote View", style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text("Allow a trusted person to view your summary"),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Share Code", style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  _code,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _toast("Copy feature not wired (UI only).");
                        },
                        child: const Text("Copy"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() => _code = _genCode());
                          await _save();
                          _toast("New code generated ✅");
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: primary),
                        child: const Text("Regenerate"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "This is a simple prototype feature. In a real system, you would share data securely via backend access control.",
                  style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ================================
   HELP
================================ */

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Help"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _FaqTile(
            q: "What is Time in Range (TIR)?",
            a: "TIR is the percentage of glucose readings between 70–180 mg/dL. Higher is generally better.",
          ),
          _FaqTile(
            q: "What is GMI?",
            a: "GMI is an estimated A1C-like value derived from average glucose. It is not a lab A1C.",
          ),
          _FaqTile(
            q: "How do alarms work?",
            a: "Alarms use your configured thresholds. This app prototype only stores settings; notification wiring can be added later.",
          ),
          _FaqTile(
            q: "How to add devices?",
            a: "Devices screen is a prototype registry (names). Real Bluetooth/SDK connection can be added later.",
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;

  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.w900)),
        children: [
          const SizedBox(height: 6),
          Text(a, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/* ================================
   UI Helpers
================================ */

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  const _SheetTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.tune_rounded),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = danger ? Colors.red : const Color(0xFF7B3FF2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: c),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}
