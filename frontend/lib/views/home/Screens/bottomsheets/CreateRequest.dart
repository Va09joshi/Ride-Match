import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:ridematch/services/API.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateLocationRequestScreen extends StatefulWidget {
  final String rideId;

  const CreateLocationRequestScreen({super.key, required this.rideId});

  @override
  State<CreateLocationRequestScreen> createState() =>
      _CreateLocationRequestScreenState();
}

class _CreateLocationRequestScreenState
    extends State<CreateLocationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  Position? currentPosition;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 🌍 Get current location and reverse geocode to address
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location services are disabled."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location permission denied."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      String address = await _getAddressFromPosition(position);

      setState(() {
        currentPosition = position;
        fromController.text = address;
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  // 🔄 Reverse geocoding helper
  Future<String> _getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
      }
    } catch (e) {
      print("Reverse geocoding failed: $e");
    }
    return "Current Location";
  }

  // 📅 Date Picker
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // 🕒 Time Picker
  Future<void> _selectTime() async {
    final picked =
    await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => selectedTime = picked);
  }

  // 📤 Submit Ride Request
  Future<void> _createRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Unable to get current location!"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");
      String? userId = prefs.getString("userId");

      if (token == null || userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ User not logged in!"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // Ensure pickup address is human-readable
      String pickupAddress = fromController.text.trim();
      if (pickupAddress.isEmpty || pickupAddress == "Current Location") {
        pickupAddress = await _getAddressFromPosition(currentPosition!);
      }

      // Format date & time for backend
      String formattedDate = selectedDate != null
          ? "${selectedDate!.year.toString().padLeft(4, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}"
          : "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

      String formattedTime = selectedTime != null
          ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
          : "${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}";

      final body = {
        "userId": userId,
        "from": pickupAddress,
        "to": toController.text.trim(),
        "note": noteController.text.trim(),
        "date": formattedDate,
        "time": formattedTime,
        "location": {
          "type": "Point",
          "coordinates": [currentPosition!.longitude, currentPosition!.latitude]
        },
      };

      print("DEBUG: Request Body -> ${json.encode(body)}"); // Debug

      final response = await http.post(
        Uri.parse(
            "$baseurl/api/rides/${widget.rideId}/request"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(body),
      );

      print("DEBUG: Response Status -> ${response.statusCode}");
      print("DEBUG: Response Body -> ${response.body}");

      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Invalid server response"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData['success'] == true) {

        // Check if backend says already requested
        if (responseData['message']?.toString().toLowerCase().contains("already requested") ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ You have already requested this ride"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (responseData['request'] != null) {
          final request = responseData['request'];
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "✅ Ride Request Sent!",
                style: TextStyle(color: Colors.black),
              ),
              backgroundColor: Colors.white,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, request);
        }

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ ${responseData['message'] ?? 'Failed to create request'}",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Error: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 🧱 Reusable TextField
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xff113F67)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      style: GoogleFonts.dmSans(fontSize: 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xff113F67),
        title: Text("Request Ride",
            style: GoogleFonts.dmSans(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Request Details",
                        style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff113F67))),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: fromController,
                      label: "From (Pickup)",
                      icon: Icons.location_on_outlined,
                      validator: (v) =>
                      v!.isEmpty ? "Enter pickup location" : null,
                      suffix: IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _getCurrentLocation,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: toController,
                      label: "To (Destination)",
                      icon: Icons.flag_outlined,
                      validator: (v) =>
                      v!.isEmpty ? "Enter destination" : null,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: TextEditingController(
                              text: selectedDate == null
                                  ? ""
                                  : "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}"),
                          label: "Select Date",
                          icon: Icons.calendar_today,
                          validator: (v) =>
                          selectedDate == null ? "Select date" : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _selectTime,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: TextEditingController(
                              text: selectedTime == null
                                  ? ""
                                  : selectedTime!.format(context)),
                          label: "Select Time",
                          icon: Icons.access_time,
                          validator: (v) =>
                          selectedTime == null ? "Select time" : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: noteController,
                      label: "Note / Purpose",
                      icon: Icons.comment_outlined,
                      validator: (v) =>
                      v!.isEmpty ? "Enter short note" : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: isLoading ? null : _createRequest,
                  label: Text(
                    isLoading ? "Posting..." : "Post Request",
                    style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff113F67),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
