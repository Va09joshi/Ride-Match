import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/controllers/map.dart';
import 'package:ridematch/views/dashboard/Screens/Dashboard.dart';
import 'package:ridematch/views/home/Screens/homeScreen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  String? selectedSeats;
  bool isLoading = false;

  Future<void> publishRide() async {
    if (fromController.text.isEmpty ||
        toController.text.isEmpty ||
        durationController.text.isEmpty ||
        amountController.text.isEmpty ||
        selectedSeats == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token'); // JWT token

      final response = await http.post(
        Uri.parse('http://192.168.29.206:5000/api/rides'), // backend endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "from": fromController.text,
          "to": toController.text,
          "seats": selectedSeats,
          "duration": durationController.text,
          "amount": amountController.text,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride published successfully')),
        );
        Navigator.pushReplacement(context,MaterialPageRoute(builder: (_){
           return DashboardScreen();
        }));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error publishing ride')),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server error')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xff003161),
        elevation: 4,
        shadowColor: Colors.black,
        centerTitle: true,
        title: Text(
          "Add a Ride",
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            MapContainer(),
            SizedBox(height: 30,),
            _buildLabel("From"),
            _buildTextField(controller: fromController, hint: "Enter starting location"),
            _buildLabel("To"),
            _buildTextField(controller: toController, hint: "Enter destination"),
            _buildLabel("No of Seats"),
            Container(
              width: 500,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xfff1f7fa),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedSeats,
                  dropdownColor: Colors.white,
                  hint: Text(
                    "Select seats",
                    style: GoogleFonts.dmSans(color: Colors.grey[600]),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
                  items: ['1', '2', '3', '4', '5','6','7']
                      .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, style: GoogleFonts.dmSans(fontSize: 15)),

                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSeats = value;
                    });
                  },
                ),
              ),
            ),
            _buildLabel("Ride Duration"),
            _buildTextField(controller: durationController, hint: "Enter duration (e.g., 30 mins)"),
            _buildLabel("Amount"),
            _buildTextField(controller: amountController, hint: "Enter amount (₹)"),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff003161),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isLoading ? null : publishRide,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    "Publish",
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 10),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({required String hint, required TextEditingController controller}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xfff1f7fa),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.grey[600]),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
