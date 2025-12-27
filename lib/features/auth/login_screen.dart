import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register_screen.dart';
import '../home/home_shell.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Invalid email format.";
      case 'user-not-found':
        return "No user found with this email.";
      case 'wrong-password':
        return "Incorrect password.";
      case 'invalid-credential':
        return "Invalid email or password.";
      case 'user-disabled':
        return "This account has been disabled.";
      case 'too-many-requests':
        return "Too many attempts. Try again later.";
      default:
        return e.message ?? "Login failed.";
    }
  }

  Future<void> _login() async {
    final email = _emailC.text.trim();
    final pass = _passC.text;

    if (email.isEmpty || pass.isEmpty) {
      _toast("Please enter email and password.");
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      await FirebaseAuth.instance.currentUser?.reload();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );

    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthError(e));
    } catch (_) {
      _toast("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailC.text.trim();
    if (email.isEmpty) {
      _toast("Enter your email to reset your password.");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _toast("Password reset email sent 📩");
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthError(e));
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
                SizedBox(height: size.height * 0.07),

                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  "Welcome Back!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 30),

                _RoundedField(
                  controller: _emailC,
                  hint: "Email",
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                _RoundedField(
                  controller: _passC,
                  hint: "Password",
                  icon: Icons.lock_outline,
                  obscureText: _obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _resetPassword,
                    child: const Text(
                      "Forgot password?",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
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
                      "Log In",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?  ",
                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                    ),
                    InkWell(
                      onTap: _loading
                          ? null
                          : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialPillButton(
                      icon: Icons.g_mobiledata,
                      label: "Google",
                      onTap: () {
                        _toast("Google Sign-In (UI only) – we will add it later.");
                      },
                    ),
                    const SizedBox(width: 14),
                    _SocialPillButton(
                      icon: Icons.apple,
                      label: "Apple",
                      onTap: () {
                        _toast("Apple Sign-In (UI only) – we will add it later.");
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),
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

class _SocialPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 130,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

