import 'package:flutter/material.dart';
import 'package:ridematch/views/auth/Screens/LoginScreen.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ridematch/views/onboarding/onboardScreen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isVideoEnded = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.asset('assets/videos/animation.mp4')
      ..initialize().then((_) {
        setState(() {}); // Refresh UI
        _controller.play();
      });

    // Detect video end
    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration &&
          !_isVideoEnded) {
        _isVideoEnded = true; // Prevent multiple calls
        _checkOnboarding();
      }
    });

    _controller.setLooping(false); // Do not loop
  }

  Future<void> _checkOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isOnboarded = prefs.getBool('isOnboarded');
    String? token = prefs.getString('token');
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (isOnboarded == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _controller.value.isInitialized
          ? Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
