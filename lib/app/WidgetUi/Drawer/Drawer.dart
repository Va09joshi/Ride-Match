import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RideMatchDrawer extends StatelessWidget {
  final String userName;
  final String email;
  final String imageUrl;

  const RideMatchDrawer({
    super.key,
    required this.userName,
    required this.email,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white.withOpacity(0.93), // white with 93% opacity
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // --- Drawer Header (Profile only) ---
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.transparent, // no gradient
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(imageUrl),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.lato(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.lato(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 15), // more space before menu items

          // --- Drawer Menu Items ---
          buildMenuItem(Icons.history, "History", Colors.blueAccent),
          const SizedBox(height: 15),
          Divider(thickness: 2,height: 1,),
          const SizedBox(height: 15),
          buildMenuItem(Icons.payment, "Payments", Color(0xff3E5F44)),
          const SizedBox(height: 15),
          Divider(thickness: 2,height: 1,),

          const SizedBox(height: 15),
          buildMenuItem(Icons.description, "Terms & Conditions", Color(0xffFF894F)),
          const SizedBox(height: 15),
          Divider(thickness: 2,height: 1,),
          const SizedBox(height: 15),
          buildMenuItem(Icons.settings, "Settings", Color(0xff555879)),
          const SizedBox(height: 15),
          Divider(thickness: 2,height: 1,),
          const SizedBox(height: 15),
          buildMenuItem(Icons.add_circle, "Add", Color(0xff819A91)),
          const SizedBox(height: 15),
          Divider(thickness: 2,height: 1,),

          const SizedBox(height: 15),

          // --- Logout Button ---
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: ListTile(

              leading: const Icon(Icons.logout, color: Color(0xff901E3E)),
              title: Text(
                "Logout",
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {},
            ),
          ),
          Divider(thickness: 2,height: 1,),
        ],
      ),
    );
  }

  // Helper function for menu items
  Widget buildMenuItem(IconData icon, String text, Color color) {
    return Center(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          text,
          style: GoogleFonts.lato(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        onTap: () {},
      ),
    );
  }
}
