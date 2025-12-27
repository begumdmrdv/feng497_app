import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
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
    } catch (_) {
      _toast("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6C2BD9),
              Color(0xFF9B5CFF),
              Color(0xFFE2C9FF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                SizedBox(height: size.height * 0.05),

                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 44,
                  ),
                ),

                const SizedBox(height: 22),

                // ✅ NEW: Full Name
                _RoundedField(
                  controller: _nameC,
                  hint: "Full Name",
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 14),

                _RoundedField(
                  controller: _emailC,
                  hint: "Email",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                _RoundedField(
                  controller: _passC,
                  hint: "Password",
                  icon: Icons.lock_outline,
                  obscureText: _obscure1,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
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
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(
                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
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

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.9)),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      ),
    );
  }
}
