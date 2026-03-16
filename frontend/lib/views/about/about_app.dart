import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xff0B2847),
        title: Text(
          "About App",
          style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _topBanner(),
            const SizedBox(height: 20),
            _infoSection("App Info", [
              _infoRow("Version", "1.0.0"),
              _infoRow("Developer", "Vaibhav Joshi"),
              _infoRow("Website", "www.ridematchapp.com"),
            ]),
            const SizedBox(height: 20),
            _infoSection("Contact", [
              _infoRow("Email", "support@example.com"),
            ]),
            const SizedBox(height: 20),
            _infoSection("About RideMatch", [
              _infoRow(
                "Description",
                "RideMatch is a modern ride-sharing app designed for convenience, safety, and social connections. Connect with drivers or passengers quickly and easily.",
              ),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _topBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff113F67), Color(0xff0B2847)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 90, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            "RideMatch",
            style: GoogleFonts.dmSans(
                fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "Your trusted ride-sharing app",
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Container(
      width: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.dmSans(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 12),
          ...children
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
        ],
      ),
    );
  }
}
