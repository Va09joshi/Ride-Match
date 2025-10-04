import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ride_match/app/view/screens/Auth/LoginScreen.dart';
import 'package:ride_match/app/view/screens/Dash/Home/HomeScreen.dart';
import 'package:ride_match/app/view/screens/document/verificationScreen.dart';

// Replace with your home screen widget


class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();

    // Add a delay of 3 seconds, then navigate
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Homescreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/logo2.png",
              width: 200,
              height: 200,
            ),
          ],
        ),
      ),
    );
  }
}
