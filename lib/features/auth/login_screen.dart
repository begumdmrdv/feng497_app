import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register_screen.dart';
import '../home/home_shell.dart'; // ✅ if your path differs, fix this import

// ✅ NEW: demo glucose data (AI-tagged) so app works without backend
import '../home/glucose_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _hidePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
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
      case 'invalid-email':
        return "Invalid email address.";
      case 'user-not-found':
        return "No user found with this email.";
      case 'wrong-password':
        return "Incorrect password.";
      case 'user-disabled':
        return "This user account is disabled.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      case 'network-request-failed':
        return "Network error. Check your connection.";
      case 'invalid-credential':
        return "Email or password is incorrect.";
      default:
        return e.message ?? "Authentication error.";
    }
  }

  Future<void> _login() async {
    final email = _emailC.text.trim();
    final pass = _passC.text;

    if (email.isEmpty || pass.isEmpty) {
      _toast("Please enter your email and password.");
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("LOGIN FirebaseAuthException: ${e.code} - ${e.message}");
      _toast(_friendlyAuthError(e));
    } catch (e) {
      debugPrint("LOGIN error: $e");
      _toast("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailC.text.trim();

    if (email.isEmpty) {
      _toast("Please type your email first.");
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _toast("Password reset email sent. Check your inbox.");
    } on FirebaseAuthException catch (e) {
      debugPrint("RESET FirebaseAuthException: ${e.code} - ${e.message}");
      _toast(_friendlyAuthError(e));
    } catch (e) {
      debugPrint("RESET error: $e");
      _toast("Could not send reset email. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goRegister() {
    if (_loading) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // ✅ NEW: Seed demo AI glucose samples so Report + PDF show "AI Insights"
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
    const bgTop = Color(0xFF7B3FF2);
    const bgBottom = Color(0xFFCDA1FF);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
          ),
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
                      // =========================
                      // Logo card
                      // =========================
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.22)),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 34,
                              offset: const Offset(0, 18),
                              color: Colors.black.withOpacity(0.22),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // ✅ UPDATED: badge area is FULL logo (no padding)
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(36),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.97),
                                    Colors.white.withOpacity(0.82),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 28,
                                    offset: const Offset(0, 18),
                                    color: Colors.black.withOpacity(0.22),
                                  ),
                                  BoxShadow(
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                    color: Colors.white.withOpacity(0.20),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(36),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover, // ✅ fills the entire square
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, __, ___) {
                                    return const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 48),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "DermaGly",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Sudor Glyco Sense",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // =========================
                      // Form card
                      // =========================
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
                            _Field(
                              controller: _emailC,
                              hint: "Email",
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 12),
                            _Field(
                              controller: _passC,
                              hint: "Password",
                              icon: Icons.lock_outline_rounded,
                              obscure: _hidePass,
                              enabled: !_loading,
                              trailing: IconButton(
                                onPressed: _loading ? null : () => setState(() => _hidePass = !_hidePass),
                                icon: Icon(
                                  _hidePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white.withOpacity(0.90),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading ? null : _forgotPassword,
                                child: const Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary.withOpacity(0.95),
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
                                  "Log In",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.88),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _goRegister,
                                  child: const Text(
                                    "Sign Up",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ✅ NEW: Dev tools (no backend). Helps demo AI features fast.
                            const SizedBox(height: 16),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final bool enabled;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.92)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
