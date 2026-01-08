import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ NEW (optional but recommended): for demo AI data without backend
// If path differs in your project, fix this import.
import '../home/glucose_store.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _pass2C = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _pass2C.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "This email is already in use.";
      case 'invalid-email':
        return "Invalid email format.";
      case 'weak-password':
        return "Password is too weak (use at least 6 characters).";
      case 'operation-not-allowed':
        return "Email/Password sign-in is not enabled in Firebase.";
      case 'network-request-failed':
        return "Network error. Check your connection.";
      default:
        return e.message ?? "Sign up failed.";
    }
  }

  Future<void> _register() async {
    final fullName = _nameC.text.trim();
    final email = _emailC.text.trim();
    final p1 = _passC.text;
    final p2 = _pass2C.text;

    if (fullName.isEmpty) {
      _toast("Please enter your full name.");
      return;
    }

    if (email.isEmpty || p1.isEmpty || p2.isEmpty) {
      _toast("Please fill in all fields.");
      return;
    }

    if (p1 != p2) {
      _toast("Passwords do not match.");
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: p1,
      );

      // Save full name into Firebase Auth user profile (no extra backend needed)
      await cred.user?.updateDisplayName(fullName);
      await cred.user?.reload();

      if (!mounted) return;
      _toast("Account created ✅");
      Navigator.of(context).pop(); // back to Login
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthError(e));
    } catch (e) {
      _toast("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ NEW: Seed demo AI glucose samples so Report + PDF works without backend
  Future<void> _seedDemoData() async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      await GlucoseStore.clearAll();

      final now = DateTime.now().toUtc();
      final rng = Random(42);

      // 14 days hourly samples
      for (int i = 0; i < 14 * 24; i++) {
        final ts = now.subtract(Duration(hours: i));

        // smooth-ish daily pattern + noise
        final base = 110 + 35 * sin(i / 6);
        final noise = rng.nextDouble() * 18 - 9;
        final val = (base + noise).clamp(55, 260).toDouble();

        await GlucoseStore.addSample(
          mgdl: val,
          ts: ts,
          source: GlucoseSource.ai,
        );
      }

      _toast("Demo glucose data created ✅ (AI-tagged). Go to Report tab.");
    } catch (e) {
      _toast("Could not create demo data: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);
    const bgTop = Color(0xFF6C2BD9);
    const bgMid = Color(0xFF9B5CFF);
    const bgBottom = Color(0xFFE2C9FF);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgMid, bgBottom],
              ),
            ),
          ),

          // Blur overlay (same vibe as Login)
          Positioned.fill(
            child: IgnorePointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.white.withOpacity(0.06)),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      // Header row
                      Row(
                        children: [
                          IconButton(
                            onPressed: _loading ? null : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Create Account",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Icon badge
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Form card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.22)),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 26,
                              offset: const Offset(0, 14),
                              color: Colors.black.withOpacity(0.16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _RoundedField(
                              controller: _nameC,
                              hint: "Full Name",
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.name,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 14),

                            _RoundedField(
                              controller: _emailC,
                              hint: "Email",
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 14),

                            _RoundedField(
                              controller: _passC,
                              hint: "Password",
                              icon: Icons.lock_outline,
                              obscureText: _obscure1,
                              enabled: !_loading,
                              suffix: IconButton(
                                onPressed: _loading ? null : () => setState(() => _obscure1 = !_obscure1),
                                icon: Icon(
                                  _obscure1 ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            _RoundedField(
                              controller: _pass2C,
                              hint: "Confirm Password",
                              icon: Icons.lock_reset,
                              obscureText: _obscure2,
                              enabled: !_loading,
                              suffix: IconButton(
                                onPressed: _loading ? null : () => setState(() => _obscure2 = !_obscure2),
                                icon: Icon(
                                  _obscure2 ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5A21D6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Text(
                                  "Create Account",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),

                            // ✅ NEW: Dev tools (no backend). Optional but very useful for demo.
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.20)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, color: Colors.white.withOpacity(0.95)),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          "Developer Tools",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Create demo AI glucose samples so Report + PDF works without backend.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: OutlinedButton.icon(
                                      onPressed: _loading ? null : _seedDemoData,
                                      icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                                      label: const Text(
                                        "Generate Demo AI Data",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.white.withOpacity(0.55)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final bool enabled;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.9)),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
