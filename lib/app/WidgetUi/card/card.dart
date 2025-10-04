import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String location;
  final String car;
  final String time;
  final String money; // 💰 New field
  final Widget? leading;
  final VoidCallback? onTap;
  final double borderRadius;
  final double elevation;
  final Gradient? gradient;

  const CustomCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.car,
    required this.time,
    required this.money, // 💰 Required
    this.leading,
    this.onTap,
    this.borderRadius = 16,
    this.elevation = 4,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasGradient = gradient != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: gradient,
          color: hasGradient ? null : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: elevation,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: leading,
              title: Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hasGradient ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: hasGradient ? Colors.white70 : Colors.grey[700],
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: hasGradient ? Colors.white70 : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.directions_car, size: 18, color: Color(0xff113F67)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    car,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: hasGradient ? Colors.white70 : Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 18, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: hasGradient ? Colors.white70 : Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 💰 Money Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.currency_rupee, color: Colors.green, size: 20),
                Text(
                  money,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasGradient ? Colors.white : Colors.green[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
