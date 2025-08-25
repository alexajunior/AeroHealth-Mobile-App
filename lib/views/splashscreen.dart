import 'package:flutter/material.dart';
import 'package:aerohealth/views/login.dart';
import 'package:aerohealth/views/dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      final user = FirebaseAuth.instance.currentUser;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user != null ? const HomeScreen() : const LoginPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: const Color(0xFFc8f5ed),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: Image.asset('assets/aerohealth.png'),
          ),
        ),
      ),
    );
  }
}
