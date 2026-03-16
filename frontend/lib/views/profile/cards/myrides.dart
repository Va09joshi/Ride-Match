import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/custom/widget/circularbar.dart';
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRide.dart';
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRequest.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  List ridesCreated = [];
  List rideRequests = [];
  bool isLoadingRides = false;
  bool isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _fetchRidesCreated();
    _fetchRideRequests();
  }

  Future<void> _fetchRidesCreated() async {
    setState(() => isLoadingRides = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');
      String? token = prefs.getString('token');

      if (userId == null || token == null) {
        _showError("User not logged in.");
        return;
      }

      final response = await http.get(
        AppApi.uri(AppEndpoints.rideByUser(userId)),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() => ridesCreated = data['rides'] ?? []);
        }
      } else {
        _showError(
          "Failed to fetch rides: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      _showError("Error fetching rides: $e");
    } finally {
      if (mounted) setState(() => isLoadingRides = false);
    }
  }

  Future<void> _fetchRideRequests() async {
    setState(() => isLoadingRequests = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');
      String? token = prefs.getString('token');

      if (userId == null || token == null) {
        _showError("User not logged in.");
        return;
      }

      final response = await http.get(
        AppApi.uri(AppEndpoints.rideRequestsByUser(userId)),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() => rideRequests = data['requests'] ?? []);
        }
      } else {
        _showError(
          "Failed to fetch ride requests: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      _showError("Error fetching ride requests: $e");
    } finally {
      if (mounted) setState(() => isLoadingRequests = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ---------- Ride Details Bottomsheet ----------
  void _showRideDetails(dynamic ride) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "${ride['from']} → ${ride['to']}",
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff113F67),
                ),
              ),
              const SizedBox(height: 16),
              _detailTile(Icons.calendar_today, "Date", ride['date']),
              _detailTile(Icons.access_time, "Time", ride['time']),
              _detailTile(
                Icons.event_seat,
                "Seats",
                "${ride['availableSeats']}",
              ),
              _detailTile(
                Icons.directions_car,
                "Car",
                "${ride['carDetails']?['name'] ?? 'Car'}",
              ),
              _detailTile(
                Icons.person,
                "Driver",
                "${ride['driverName'] ?? 'Driver'}",
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 16),
          Text(
            "$title:",
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 15))),
        ],
      ),
    );
  }

  // ---------- Ride Card ----------
  Widget _buildRideCard(dynamic ride) {
    return GestureDetector(
      onTap: () => _showRideDetails(ride),
      child: Container(
        width: 400,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${ride['from']} → ${ride['to']}",
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "₹${ride['amount'] ?? 0}",
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Request Card ----------
  Widget _buildRequestCard(dynamic request) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${request['from']} → ${request['to']}",
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "${request['date']}",
                style: GoogleFonts.dmSans(fontSize: 14),
              ),
              const SizedBox(width: 14),
              Icon(Icons.access_time, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "${request['time']}",
                style: GoogleFonts.dmSans(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Note: ${request['note']}",
            style: GoogleFonts.dmSans(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  //                     MAIN UI
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF2F6FB),
      appBar: AppBar(
        backgroundColor: Color(0xff113F67),
        title: Text("My Rides", style: GoogleFonts.dmSans(color: Colors.white)),
        centerTitle: true,
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            backgroundColor: Color(0xff113F67),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text("Add Ride", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final newRide = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateRideScreen()),
              );
              if (newRide != null)
                setState(() => ridesCreated.insert(0, newRide));
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            backgroundColor: Color(0xff0A2A66),
            icon: Icon(Icons.add_task, color: Colors.white),
            label: Text("Add Request", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (ridesCreated.isEmpty) {
                _showError("Please create a ride first!");
                return;
              }
              final rideId = ridesCreated.first['_id'];
              final newRequest = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateLocationRequestScreen(rideId: rideId),
                ),
              );
              if (newRequest != null)
                setState(() => rideRequests.insert(0, newRequest));
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchRidesCreated();
          await _fetchRideRequests();
        },
        child: ListView(
          physics: BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 16),

            // ---------- Rides Created ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Rides Created",
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            isLoadingRides
                ? Column(children: List.generate(3, (_) => _shimmerRideCard()))
                : ridesCreated.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No rides created",
                        style: GoogleFonts.dmSans(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: ridesCreated
                        .map((ride) => _buildRideCard(ride))
                        .toList(),
                  ),

            const SizedBox(height: 24),

            // ---------- Ride Requests ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Ride Requests",
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            isLoadingRequests
                ? Column(
                    children: List.generate(3, (_) => _shimmerRequestCard()),
                  )
                : rideRequests.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No ride requests",
                        style: GoogleFonts.dmSans(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: rideRequests
                        .map((r) => _buildRequestCard(r))
                        .toList(),
                  ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _shimmerRideCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: 400,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: 180, color: Colors.white),
            const SizedBox(height: 10),
            Container(height: 14, width: 80, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _shimmerRequestCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: 200, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 14, width: 140, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 14, width: double.infinity, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
