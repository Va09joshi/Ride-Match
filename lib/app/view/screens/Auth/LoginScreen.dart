import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ride_match/app/view/screens/Auth/signupScreen.dart';
import 'package:ride_match/app/view/screens/document/verificationScreen.dart'; // Import Google Fonts package

class RideMatchLogin extends StatefulWidget {
  const RideMatchLogin({super.key});

  @override
  State<RideMatchLogin> createState() => _RideMatchLoginState();
}

class _RideMatchLoginState extends State<RideMatchLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Define colors based on the logo and provided design
  final Color primaryBlue = const Color(0xFF192182); // Dark blue from logo
  final Color primaryOrange = const Color(0xFFE87D2A); // Orange from logo
  final Color lightBackgroundColor = const Color(0xFFFFFFFF); // White background
  final Color inputBorderColor = const Color(0xFFE0E0E0); // Light border for fields

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackgroundColor,
      body: Stack(
        children: [
          // Background waves/shapes (for visual effect like the image)

          // Top Right Shape - Larger and more transparent, pushed to the edge
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade300.withOpacity(0.2), // Reduced opacity
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Bottom Left Shape - Larger and more transparent, pushed to the edge
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.08), // Reduced opacity
                shape: BoxShape.circle,
              ),
            ),
          ),


          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),



                    Image.asset(
                      'assets/images/logo2.png',
                      height: 60, // Reduced logo height
                    ),
                    const SizedBox(height: 20),

                    // Headline using Lato
                    Column(
                      children: [
                        Text(
                          "Find Your Ride",
                          style: GoogleFonts.lato(
                            fontSize: 32, // Increased for more impact
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8), // Increased vertical space
                        Text(
                          "Match & Go!",
                          style: GoogleFonts.lato(
                            fontSize: 24, // Slightly smaller subtitle
                            fontWeight: FontWeight.w600,
                            color: Colors.black54, // Changed color to hint at subtitle
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      hint: "Username or email",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _buildTextField(
                      controller: _passwordController,
                      hint: "Password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 30),

                    // Login Button (Gradient)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_){
                          return Verificationscreen();
                        }));
                        debugPrint(
                            "Attempting login with: Email/User: ${_emailController.text}");
                      },
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: LinearGradient(
                            colors: [primaryBlue, primaryOrange],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "LOG IN",
                            style: GoogleFonts.lato( // Applied Lato
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Forgot Password & Create Account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            "Forgot Password?",
                            style: GoogleFonts.lato( // Applied Lato
                              color: primaryBlue.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Text(
                          " | ",
                          style: TextStyle(color: Color(0xFFE0E0E0)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_){
                              return Signupscreen();
                            }));
                          },
                          child: Text(
                            "Create Account",
                            style: GoogleFonts.lato( // Applied Lato
                              color: primaryOrange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // --- START Social Login Buttons ---
                    // Social login text
                    Text(
                      "or connect with",
                      style: GoogleFonts.lato(color: Colors.black54), // Applied Lato
                    ),
                    const SizedBox(height: 12),

                    // Social Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google Icon
                        _socialIcon(
                            icon: Icons.g_mobiledata, color: Colors.black54, onTap: () => debugPrint('Google Login')),
                        const SizedBox(width: 20),
                        // Facebook Icon
                        _socialIcon(
                            icon: Icons.facebook, color: Colors.black54, onTap: () => debugPrint('Facebook Login')),
                        const SizedBox(width: 20),
                        // Apple Icon
                        _socialIcon(
                            icon: Icons.apple, color: Colors.black54, onTap: () => debugPrint('Apple Login')),
                      ],
                    ),
                    // --- END Social Login Buttons ---

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), // More rounded corners
        border: Border.all(color: inputBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: GoogleFonts.lato(fontSize: 16), // Applied Lato
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryBlue, size: 20),
          hintText: hint,
          hintStyle: GoogleFonts.lato(color: Colors.grey.shade500), // Applied Lato
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          )
              : null,
        ),
      ),
    );
  }

  // Re-added the _socialIcon widget
  Widget _socialIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: inputBorderColor, width: 1),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}
