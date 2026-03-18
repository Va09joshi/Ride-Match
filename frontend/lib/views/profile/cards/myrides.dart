import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
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

  String _safeText(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _fetchRidesCreated() async {
    setState(() => isLoadingRides = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');

      if (userId == null || token == null) {
        _showError('User not logged in.');
        return;
      }

      final response = await http.get(
        AppApi.uri(AppEndpoints.rideByUser(userId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() => ridesCreated = data['rides'] ?? []);
      } else {
        _showError(
          'Failed to fetch rides: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _showError('Error fetching rides: $e');
    } finally {
      if (mounted) setState(() => isLoadingRides = false);
    }
  }

  Future<void> _fetchRideRequests() async {
    setState(() => isLoadingRequests = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');

      if (userId == null || token == null) {
        _showError('User not logged in.');
        return;
      }

      final response = await http.get(
        AppApi.uri(AppEndpoints.rideRequestsByUser(userId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() => rideRequests = data['requests'] ?? []);
      } else {
        _showError(
          'Failed to fetch ride requests: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _showError('Error fetching ride requests: $e');
    } finally {
      if (mounted) setState(() => isLoadingRequests = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

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
                '${_safeText(ride['from'])} -> ${_safeText(ride['to'])}',
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff113F67),
                ),
              ),
              const SizedBox(height: 16),
              _detailTile(
                Icons.calendar_today,
                'Date',
                _safeText(ride['date']),
              ),
              _detailTile(Icons.access_time, 'Time', _safeText(ride['time'])),
              _detailTile(
                Icons.event_seat,
                'Seats',
                '${ride['availableSeats'] ?? 0}',
              ),
              _detailTile(
                Icons.currency_rupee,
                'Fare',
                '${ride['amount'] ?? 0}',
              ),
              _detailTile(
                Icons.directions_car,
                'Car',
                _safeText(ride['carDetails']?['name'], fallback: 'Car'),
              ),
              _detailTile(
                Icons.person,
                'Driver',
                _safeText(ride['driverName'], fallback: 'Driver'),
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
            '$title:',
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

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xffF5F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xff486581)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: const Color(0xff334E68),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(dynamic ride) {
    return GestureDetector(
      onTap: () => _showRideDetails(ride),
      child: Container(
        width: 400,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffE6EDF7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${_safeText(ride['from'])} -> ${_safeText(ride['to'])}',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff102A43),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffEBF4FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rs ${ride['amount'] ?? 0}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff0F4C81),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(Icons.calendar_today, _safeText(ride['date'])),
                _metaChip(Icons.access_time, _safeText(ride['time'])),
                _metaChip(
                  Icons.event_seat,
                  '${ride['availableSeats'] ?? 0} seats',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Color(0xff486581)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _safeText(ride['driverName'], fallback: 'Driver'),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: const Color(0xff486581),
                    ),
                  ),
                ),
                Text(
                  'View details',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xff0F4C81),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE6EDF7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_safeText(request['from'])} -> ${_safeText(request['to'])}',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xff102A43),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(Icons.calendar_today, _safeText(request['date'])),
              _metaChip(Icons.access_time, _safeText(request['time'])),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Note: ${_safeText(request['note'], fallback: 'No note added')}',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xff486581),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE6EDF7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: Color(0xff9FB3C8), size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xff243B53),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xff627D98),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xffEAF2FD),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xff113F67)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff102A43),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xff113F67),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF7FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff102A43),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xff627D98),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF2F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xff113F67),
        title: Text(
          'My Rides',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await _fetchRidesCreated();
              await _fetchRideRequests();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            backgroundColor: const Color(0xff113F67),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Ride',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              final newRide = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateRideScreen()),
              );
              if (newRide != null && mounted) {
                setState(() => ridesCreated.insert(0, newRide));
              }
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            backgroundColor: const Color(0xff0A2A66),
            icon: const Icon(Icons.add_task, color: Colors.white),
            label: const Text(
              'Add Request',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              if (ridesCreated.isEmpty) {
                _showError('Please create a ride first!');
                return;
              }
              final rideId = ridesCreated.first['_id'];
              final newRequest = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateLocationRequestScreen(rideId: rideId),
                ),
              );
              if (newRequest != null && mounted) {
                setState(() => rideRequests.insert(0, newRequest));
              }
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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE6EDF7)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Created',
                      ridesCreated.length,
                      Icons.route,
                      const Color(0xff113F67),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Requests',
                      rideRequests.length,
                      Icons.request_page,
                      const Color(0xff0A2A66),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionHeader('Rides Created', ridesCreated.length, Icons.route),
            const SizedBox(height: 12),
            if (isLoadingRides)
              Column(children: List.generate(3, (_) => _shimmerRideCard()))
            else if (ridesCreated.isEmpty)
              _emptyCard(
                'No rides created yet',
                'Tap Add Ride to post your first ride.',
              )
            else
              Column(children: ridesCreated.map(_buildRideCard).toList()),
            const SizedBox(height: 24),
            _sectionHeader(
              'Ride Requests',
              rideRequests.length,
              Icons.request_page,
            ),
            const SizedBox(height: 10),
            if (isLoadingRequests)
              Column(children: List.generate(3, (_) => _shimmerRequestCard()))
            else if (rideRequests.isEmpty)
              _emptyCard(
                'No ride requests yet',
                'Create a request and it will appear here.',
              )
            else
              Column(children: rideRequests.map(_buildRequestCard).toList()),
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
        margin: const EdgeInsets.symmetric(vertical: 8),
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
        margin: const EdgeInsets.symmetric(vertical: 8),
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
