import 'package:flutter/material.dart';
import 'package:ridematch/main.dart';
import 'package:ridematch/utils/images.dart';
import 'package:ridematch/views/auth/Screens/LoginScreen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController _controller = PageController();
  bool isLastPage = false;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Find a Ride, Anytime.",
      "subtitle": "Search nearby drivers or passengers heading your way. Quick, reliable, and effortless ride-sharing starts here.",
      "image": Images.onboard_one,
    },
    {
      "title": "Share Rides. Save Money.",
      "subtitle": " Split travel costs, reduce fuel use, and make your journey more affordable — because sharing is caring.",
      "image": Images.onboard_two,
    },
    {
      "title": "Let’s Get Started!",
      "subtitle": "You’re all set to carpool smarter, safer, and cheaper. Find your first ride and start saving today.",
      "image": Images.onboard_three,
    },
  ];

  // Save onboarding as completed
  Future<void> completeOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboarded', true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.95),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: onboardingData.length,
                  onPageChanged: (index) {
                    setState(() {
                      isLastPage = index == onboardingData.length - 1;
                    });
                  },
                  itemBuilder: (_, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          onboardingData[index]["image"]!,
                          height: 400,
                        ),
                        SizedBox(height: 30),
                        Text(
                          onboardingData[index]["title"]!,
                          style: GoogleFonts.dmSans(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff003161)
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 26),
                        Text(
                          onboardingData[index]["subtitle"]!,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip Button
                  TextButton(
                    onPressed: () async {
                      await completeOnboarding(); // Save and go to Home
                    },
                    child: Text(
                      "Skip",
                      style: GoogleFonts.dmSans(fontSize: 16,color: Colors.black45,fontWeight: FontWeight.w500),
                    ),
                  ),
                  SmoothPageIndicator(
                    controller: _controller,
                    count: onboardingData.length,
                    effect: WormEffect(
                      dotHeight: 10,
                      dotWidth: 10,
                      activeDotColor: Color(0xff003161),
                    ),
                  ),
                  // Next/Done Button
                  TextButton(
                    onPressed: () async {
                      if (isLastPage) {
                        await completeOnboarding(); // Save and go to Home
                      } else {
                        _controller.nextPage(
                          duration: Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(
                      isLastPage ? "Done" : "Next",
                      style: GoogleFonts.dmSans(fontSize: 16,fontWeight: FontWeight.w500,color: Color(0xff003161)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
