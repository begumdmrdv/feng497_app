import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Global error handling (useful during PDF generation / storage issues)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print("FlutterError: ${details.exceptionAsString()}");
  };

  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    // ignore: avoid_print
    print("Uncaught zone error: $error");
    // ignore: avoid_print
    print(stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _primary = Color(0xFF7B3FF2);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FENG497 App',

      // ✅ Theme alignment (matches your purple UI)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _primary),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),

      // ✅ If user already logged in → go HomeShell, else Login
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) return const LoginScreen();

        return const HomeShell();
      },
    );
  }
}
