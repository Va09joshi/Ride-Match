import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Screens
import 'package:ridematch/views/home/Screens/homeScreen.dart';
import 'package:ridematch/views/post/Screens/postScreen.dart';
import 'package:ridematch/views/profile/Screen/profileScreen.dart';
import 'package:ridematch/views/ride/rideScreen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? bookedRide; // Add this

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(bookedRide: bookedRide), // Pass bookedRide
      const RideScreen(),
      const PostScreen(),
      const ProfileScreen(),
    ];
  }

  void updateBookedRide(Map<String, dynamic> ride) {
    setState(() {
      bookedRide = ride;
      _screens[0] = HomeScreen(bookedRide: bookedRide);
      _currentIndex = 0; // Switch to Home tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final double itemWidth = MediaQuery.of(context).size.width / 4;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              bottom: 12,
              left: _currentIndex * itemWidth + (itemWidth / 2) - 30,
              child: Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xff4A70A9),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Row(
              children: [
                buildNavItem(Icons.home_rounded, "Home", 0),
                buildNavItem(Icons.directions_car_rounded, "Ride", 1),
                buildNavItem(Icons.post_add_rounded, "Post", 2),
                buildNavItem(Icons.person_rounded, "Profile", 3),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNavItem(IconData icon, String label, int index) {
    bool active = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: active ? const Color(0xff4A70A9) : const Color(0xff9BB4C0),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: active ? 1 : 0,
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff4A70A9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
