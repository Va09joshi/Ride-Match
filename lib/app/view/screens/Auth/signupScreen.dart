import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts package

class Signupscreen extends StatefulWidget {
  const Signupscreen({super.key});

  @override
  State<Signupscreen> createState() => _SignupscreenState();
}

class _SignupscreenState extends State<Signupscreen> {
  // Added a controller for the Name field
  final TextEditingController _nameController = TextEditingController();
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

                    // Logo
                    // **ASSUMED PATH: Please ensure 'ridematch.jpg' is at 'assets/images/'**
                    Image.asset(
                      'assets/images/logo2.png',
                      height: 60,
                    ),
                    const SizedBox(height: 20),

                    // Headline updated for Sign Up
                    Column(
                      children: [
                        Text(
                          "Join the Ride",
                          style: GoogleFonts.lato(
                            fontSize: 32, // Increased for more impact
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Create an Account",
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

                    // Name Field
                    _buildTextField(
                      controller: _nameController,
                      hint: "Full Name",
                      icon: Icons.person_2_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      hint: "Email Address", // Changed hint
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _buildTextField(
                      controller: _passwordController,
                      hint: "Set Password", // Changed hint
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 30),

                    // Sign Up Button (Gradient) - Button text changed
                    GestureDetector(
                      onTap: () {
                        // Implement sign up logic here
                        debugPrint(
                            "Attempting Sign Up with: Name: ${_nameController.text}, Email: ${_emailController.text}");
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
                            "SIGN UP",
                            style: GoogleFonts.lato(
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

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: GoogleFonts.lato(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                             Navigator.pop(context);
                          },
                          child: Text(
                            "Log In",
                            style: GoogleFonts.lato(
                              color: primaryOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Removed all social media widgets below this point
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

  // The _socialIcon helper is no longer used, but kept to prevent build errors if referenced elsewhere.
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
