import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ridematch/views/ride_detail/ridedetails.dart';
import 'package:shimmer/shimmer.dart';

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  List<Map<String, dynamic>> nearbyRides = [];
  List<Map<String, dynamic>> myRides = [];
  bool loading = true;
  String? currentUserId;

  static const baseUrl = "https://ridematch-final.onrender.com/api";

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('userId');
    if (currentUserId == null || currentUserId == "null" || currentUserId!.trim().isEmpty) {
      currentUserId = null;
    }
    await _fetchRides();
  }

  List<Map<String, dynamic>> parseRides(dynamic data) {
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [];
  }

  Future<void> _fetchRides() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => loading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition();

      if (currentUserId != null) {
        final myResponse = await http.get(Uri.parse("$baseUrl/rides/user/$currentUserId"));
        if (myResponse.statusCode == 200) {
          final myData = jsonDecode(myResponse.body);
          myRides = parseRides(myData['rides']);
        }
      }

      final nearbyResponse =
      await http.get(Uri.parse("$baseUrl/rides?excludeUserId=$currentUserId"));

      if (nearbyResponse.statusCode == 200) {
        final nearbyData = jsonDecode(nearbyResponse.body);
        nearbyRides = parseRides(nearbyData['rides'] ?? nearbyData['data']);

        if (currentUserId != null) {
          nearbyRides.removeWhere((ride) =>
          ride['userId'] == currentUserId ||
              ride['driverId']?['_id'] == currentUserId);
        }

        nearbyRides.sort((a, b) {
          final aDateTime =
              DateTime.tryParse("${a['date']} ${a['time']}") ?? DateTime.now();
          final bDateTime =
              DateTime.tryParse("${b['date']} ${b['time']}") ?? DateTime.now();
          return bDateTime.compareTo(aDateTime);
        });
      }

      setState(() => loading = false);
    } catch (e) {
      debugPrint("Ride Fetch Error: $e");
      setState(() => loading = false);
    }
  }

  void _goToRideDetails(Map<String, dynamic> ride) {
    if (currentUserId == null) return;

    Map<String, dynamic> rideWithDefaults = {
      ...ride,
      'carDetails': {
        'name': ride['carDetails']?['name'] ?? 'Car',
        'number': ride['carDetails']?['number'] ?? 'XXX-000',
        'color': ride['carDetails']?['color'] ?? 'Black',
      },
      'driverImage': ride['driverImage'] ?? '',
      'driverName': ride['driverName'] ?? 'Driver',
      'rating': ride['rating'] ?? 4.0,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideDetailsScreen(
          rideData: rideWithDefaults,
          currentUserId: currentUserId!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6fb),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xff113F67),
        title: Text("Rides",
            style: GoogleFonts.lato(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: loading
          ? _buildShimmerScreen()
          : (myRides.isEmpty && nearbyRides.isEmpty)
          ? _emptyView()
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (myRides.isNotEmpty) _myRidesSection(),
          Expanded(child: _nearbyRidesList()),
        ],
      ),
    );
  }

  // ================= SHIMMER =================

  Widget _buildShimmerScreen() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => _shimmerRideCard(),
    );
  }

  Widget _shimmerRideCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 30, backgroundColor: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 14, color: Colors.white)),
                const SizedBox(width: 10),
                Container(height: 24, width: 50, color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 14, width: double.infinity, color: Colors.white),
            const SizedBox(height: 10),
            Container(height: 14, width: double.infinity, color: Colors.white),
            const SizedBox(height: 16),
            Container(height: 45, width: double.infinity, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ================= EXISTING UI =================

  Widget _myRidesSection() {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: myRides.length,
        itemBuilder: (_, i) => _myRideCard(myRides[i]),
      ),
    );
  }

  Widget _nearbyRidesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: nearbyRides.length,
      itemBuilder: (_, i) => _rideCard(nearbyRides[i]),
    );
  }

  // (Your existing _myRideCard, _rideCard, and _emptyView remain unchanged)


  Widget _myRideCard(Map<String, dynamic> ride) {
    final car = ride['carDetails'] ?? {
      'name': 'Car',
      'number': 'XXX-000',
      'color': 'Black',
    };

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("${ride['from']} → ${ride['to']}",
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold)),
          Text("${ride['availableSeats'] ?? "N/A"} seats • ₹${ride['amount']}",
              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.green.shade800)),
          Text("${car['name']} • ${car['number']} • ${car['color']}",
              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54)),
          ElevatedButton(
            onPressed: () => _goToRideDetails(ride),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff113F67),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("View Details", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // Widget _nearbyRidesList() {
  //   return ListView.builder(
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //     itemCount: nearbyRides.length,
  //     itemBuilder: (_, i) => _rideCard(nearbyRides[i]),
  //   );
  // }

  Widget _rideCard(Map<String, dynamic> ride) {
    final car = ride['carDetails'] ?? {'name': 'Car', 'number': 'XXX-000', 'color': 'Black'};
    final driverImage = ride['driverImage'] != null && ride['driverImage'].isNotEmpty
        ? ride['driverImage']
        : 'https://www.pngall.com/wp-content/uploads/5/User-Profile-PNG.png';
    final rating = ride['rating'] ?? 0.0;
    final driverName = ride["driverId"]["name"] ?? 'Driver';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DRIVER INFO + FARE
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(driverImage),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff09205f),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${car['name']} • ${car['number']} • ${car['color']} • ${ride['availableSeats']} seats",
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xffFFE5B4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "₹${ride['amount'].toStringAsFixed(0)}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xffFF6F00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ROUTE INFO
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ride['from'] ?? "",
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14),
              Expanded(
                child: Text(
                  ride['to'] ?? "",
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // VIEW DETAILS BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _goToRideDetails(ride),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff113F67),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              child: Text(
                "View Details",
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled, size: 90, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text("No rides found",
              style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("Please try again later.",
              style: GoogleFonts.dmSans(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
