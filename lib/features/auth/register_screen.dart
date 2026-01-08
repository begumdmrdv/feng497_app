import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _nameC = TextEditingController();

  bool _hidePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailC.text.trim();
    final pass = _passC.text;
    final name = _nameC.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _toast("Please enter your email and password.");
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (name.isNotEmpty) {
        await cred.user?.updateDisplayName(name);
        await cred.user?.reload();
      }

      // ✅ Do NOT navigate manually. AuthGate will show Home automatically.
      if (mounted) Navigator.pop(context); // go back to login UI (optional)
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthError(e));
    } catch (e) {
      _toast("Register error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Invalid email address.";
      case 'email-already-in-use':
        return "This email is already in use.";
      case 'weak-password':
        return "Password is too weak. Try at least 6 characters.";
      case 'operation-not-allowed':
        return "Email/password sign-up is disabled in Firebase.";
      case 'network-request-failed':
        return "Network error. Check your connection.";
      default:
        return e.message ?? "Authentication error.";
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Container(
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
                        const Text(
                          "Create Account",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                        ),
                        const SizedBox(height: 14),

                        _Field(controller: _nameC, hint: "Name (optional)", icon: Icons.badge_outlined),
                        const SizedBox(height: 12),
                        _Field(controller: _emailC, hint: "Email", icon: Icons.person_outline_rounded, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _passC,
                          hint: "Password",
                          icon: Icons.lock_outline_rounded,
                          obscure: _hidePass,
                          trailing: IconButton(
                            onPressed: () => setState(() => _hidePass = !_hidePass),
                            icon: Icon(_hidePass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white.withOpacity(0.9)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B3FF2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text("Sign Up", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: _loading ? null : () => Navigator.pop(context),
                          child: const Text("Back to Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
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

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
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
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.72), fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
