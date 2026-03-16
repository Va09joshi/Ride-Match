import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:ridematch/views/chats/SocketScreenchat.dart';
import 'package:ridematch/views/ride_detail/ridedetails.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  List<Map<String, dynamic>> _nearbyRides = [];
  List<Map<String, dynamic>> _myActiveRides = [];
  List<Map<String, dynamic>> _myBookedRides = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _rideHistory = [];
  bool _loading = true;
  bool _refreshing = false;

  String? currentUserId;
  String? _token;

  String _profileName = 'User';
  String _profileEmail = '';
  String? _profileImage;

  Position? _currentPosition;
  int _selectedTabIndex = 0;

  static const double _nearbyDistanceMeters = 25000;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _loading || _refreshing) return;
      _fetchRides(isRefresh: true);
    });
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('userId');
    _token = prefs.getString('token');

    if (currentUserId == null ||
        currentUserId!.trim().isEmpty ||
        currentUserId == 'null') {
      currentUserId = null;
    }

    await Future.wait([_fetchCurrentPosition(), _fetchProfile()]);

    await _fetchRides();
  }

  List<Map<String, dynamic>> _parseRides(dynamic data) {
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [];
  }

  DateTime? _departureDate(Map<String, dynamic> ride) {
    final rawDate = (ride['date'] ?? '').toString().trim();
    final rawTime = (ride['time'] ?? '').toString().trim();
    if (rawDate.isEmpty || rawTime.isEmpty) return null;

    final dateParts = rawDate.split(RegExp(r'[-/]'));
    if (dateParts.length != 3) return null;

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    final timeParts = rawTime.split(':');
    final hour = int.tryParse(timeParts[0]);
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;

    if ([year, month, day, hour, minute].contains(null)) return null;
    return DateTime(year!, month!, day!, hour!, minute!);
  }

  bool _isPastRide(Map<String, dynamic> ride) {
    final departure = _departureDate(ride);
    if (departure == null) return false;
    return departure.isBefore(DateTime.now());
  }

  String _rideStatus(Map<String, dynamic> ride) {
    return (ride['status'] ?? 'created').toString().toLowerCase();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'created':
        return 'Created';
      case 'active':
        return 'Active';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'created':
        return Colors.blueGrey;
      case 'active':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _isLiveStatus(String status) {
    return status == 'created' || status == 'active' || status == 'in_progress';
  }

  LatLng? _extractRideLatLng(Map<String, dynamic> ride) {
    final location = ride['location'];
    if (location is Map && location['coordinates'] is List) {
      final coords = location['coordinates'] as List;
      if (coords.length >= 2) {
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        return LatLng(lat, lng);
      }
    }

    final fromLat = double.tryParse((ride['fromLat'] ?? '').toString());
    final fromLng = double.tryParse((ride['fromLong'] ?? '').toString());
    if (fromLat != null && fromLng != null) {
      return LatLng(fromLat, fromLng);
    }
    return null;
  }

  double? _distanceKm(Map<String, dynamic> ride) {
    if (_currentPosition == null) return null;
    final latLng = _extractRideLatLng(ride);
    if (latLng == null) return null;

    final meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latLng.latitude,
      latLng.longitude,
    );
    return meters / 1000;
  }

  Future<void> _fetchCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {}
  }

  Future<void> _fetchProfile() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        AppApi.uri('/api/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        final user = payload['user'] ?? {};
        if (!mounted) return;
        setState(() {
          _profileName = (user['name'] ?? _profileName).toString();
          _profileEmail = (user['email'] ?? '').toString();
          _profileImage = (user['profileImage'] ?? '').toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchRides({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
    });

    try {
      List<Map<String, dynamic>> myRides = [];
      List<Map<String, dynamic>> bookedRides = [];
      List<Map<String, dynamic>> incomingRequests = [];
      if (currentUserId != null) {
        final myResponse = await http.get(
          AppApi.uri('/api/rides/user/$currentUserId'),
        );
        if (myResponse.statusCode == 200) {
          final myData = jsonDecode(myResponse.body);
          myRides = _parseRides(myData['rides']);
        }

        if (_token != null) {
          final incomingResponse = await http.get(
            AppApi.uri(AppEndpoints.rideIncoming(currentUserId!)),
            headers: {'Authorization': 'Bearer $_token'},
          );

          if (incomingResponse.statusCode == 200) {
            final incomingPayload = jsonDecode(incomingResponse.body);
            incomingRequests = _parseRides(incomingPayload['requests']);
          }
        }
      }

      if (_token != null) {
        final bookingResponse = await http.get(
          AppApi.uri(AppEndpoints.bookingsMe),
          headers: {'Authorization': 'Bearer $_token'},
        );

        if (bookingResponse.statusCode == 200) {
          final bookingPayload = jsonDecode(bookingResponse.body);
          final bookingList = _parseRides(bookingPayload['bookings']);
          bookedRides = bookingList
              .map((booking) {
                final ride = booking['ride'];
                if (ride is Map) {
                  final rideMap = Map<String, dynamic>.from(ride);
                  return {
                    ...rideMap,
                    'bookingId': booking['bookingId'],
                    'bookingStatus': booking['status'],
                    'driverId': booking['driver'] ?? rideMap['driverId'],
                  };
                }
                return <String, dynamic>{};
              })
              .where((ride) => ride.isNotEmpty)
              .toList();
        }
      }

      final Uri nearbyUri = _currentPosition == null
          ? AppApi.uri(
              '/api/rides',
              queryParameters: {'excludeUserId': currentUserId ?? ''},
            )
          : AppApi.uri(
              '/api/rides/nearby',
              queryParameters: {
                'longitude': _currentPosition!.longitude,
                'latitude': _currentPosition!.latitude,
                'maxDistance': _nearbyDistanceMeters,
                'excludeUserId': currentUserId ?? '',
              },
            );

      final nearbyResponse = await http.get(nearbyUri);

      List<Map<String, dynamic>> nearbyRides = [];
      if (nearbyResponse.statusCode == 200) {
        final nearbyData = jsonDecode(nearbyResponse.body);
        nearbyRides = _parseRides(nearbyData['rides'] ?? nearbyData['data']);
      }

      if (currentUserId != null) {
        nearbyRides.removeWhere((ride) {
          final driver = ride['driverId'];
          final driverId = driver is Map ? driver['_id'] : driver;
          return driverId?.toString() == currentUserId;
        });
      }

      nearbyRides = nearbyRides.where((ride) {
        final status = _rideStatus(ride);
        if (!(status == 'created' || status == 'active')) return false;
        if (_isPastRide(ride)) return false;
        final seats =
            int.tryParse((ride['availableSeats'] ?? '0').toString()) ?? 0;
        if (seats <= 0) return false;
        final distance = _distanceKm(ride);
        if (distance == null) return true;
        return distance <= (_nearbyDistanceMeters / 1000);
      }).toList();

      nearbyRides.sort((a, b) {
        final aDistance = _distanceKm(a) ?? 9999;
        final bDistance = _distanceKm(b) ?? 9999;
        return aDistance.compareTo(bDistance);
      });

      final activeMyRides = myRides.where((ride) {
        final status = _rideStatus(ride);
        return _isLiveStatus(status) && !_isPastRide(ride);
      }).toList();

      final activeBooked = bookedRides.where((ride) {
        final status = _rideStatus(ride);
        return _isLiveStatus(status) && !_isPastRide(ride);
      }).toList();

      final history = myRides.where((ride) {
        final status = _rideStatus(ride);
        return status == 'cancelled' ||
            status == 'completed' ||
            _isPastRide(ride);
      }).toList();

      history.addAll(
        bookedRides.where((ride) {
          final status = _rideStatus(ride);
          return status == 'cancelled' ||
              status == 'completed' ||
              _isPastRide(ride);
        }),
      );

      history.sort((a, b) {
        final aDate =
            _departureDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            _departureDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _myActiveRides = activeMyRides;
        _myBookedRides = activeBooked;
        _incomingRequests = incomingRequests;
        _rideHistory = history;
        _nearbyRides = nearbyRides;
      });
    } catch (e) {
      debugPrint('Ride Fetch Error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _cancelRide(String rideId) async {
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to continue.')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.patch(
        AppApi.uri('/api/rides/$rideId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      final payload = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          payload['success'] == true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (payload['message'] ??
                    (success ? 'Ride cancelled.' : 'Failed to cancel ride'))
                .toString(),
          ),
        ),
      );

      if (success) {
        await _fetchRides(isRefresh: true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to cancel ride right now.')),
      );
    }
  }

  Future<void> _respondToRequest(
    Map<String, dynamic> request,
    String action,
  ) async {
    if (_token == null || _token!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to continue.')),
      );
      return;
    }

    final rideId = (request['rideId'] is Map)
        ? (request['rideId']['_id'] ?? '').toString()
        : (request['rideId'] ?? '').toString();
    final requesterId = (request['userId'] is Map)
        ? (request['userId']['_id'] ?? '').toString()
        : (request['userId'] ?? '').toString();

    if (rideId.isEmpty || requesterId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid request data.')));
      return;
    }

    try {
      final response = await http.patch(
        AppApi.uri(AppEndpoints.rideRespond(rideId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'userId': requesterId, 'status': action}),
      );

      final payload = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok || payload['success'] != true) {
        throw Exception(
          (payload['message'] ?? 'Unable to update request').toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        final requestId = (request['_id'] ?? '').toString();
        _incomingRequests.removeWhere(
          (item) => (item['_id'] ?? '').toString() == requestId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((payload['message'] ?? 'Updated').toString())),
      );

      if (action == 'accepted') {
        await _openChatWithRequester(request);
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openChatWithRequester(Map<String, dynamic> request) async {
    if (currentUserId == null || currentUserId!.isEmpty) return;

    final requesterId = (request['userId'] is Map)
        ? (request['userId']['_id'] ?? '').toString()
        : (request['userId'] ?? '').toString();

    if (requesterId.isEmpty || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          senderId: currentUserId!,
          receiverId: requesterId,
          initialPermissionStatus: ChatPermissionStatus.accepted,
        ),
      ),
    );
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
      'driverImage':
          ride['driverImage'] ?? ride['driverId']?['profileImage'] ?? '',
      'driverName': ride['driverName'] ?? ride['driverId']?['name'] ?? 'Driver',
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
        title: Text(
          "Rides",
          style: GoogleFonts.lato(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? _buildShimmerScreen()
          : (_myActiveRides.isEmpty &&
                _myBookedRides.isEmpty &&
                _rideHistory.isEmpty &&
                _nearbyRides.isEmpty)
          ? _emptyView()
          : RefreshIndicator(
              onRefresh: () => _fetchRides(isRefresh: true),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                children: [
                  _profileCard(),
                  const SizedBox(height: 14),
                  _rideTabs(),
                  const SizedBox(height: 12),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  _tabContent(),
                ],
              ),
            ),
    );
  }

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff113F67), Color(0xff34699A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            backgroundImage:
                (_profileImage != null && _profileImage!.isNotEmpty)
                ? NetworkImage(_profileImage!)
                : null,
            child: (_profileImage != null && _profileImage!.isNotEmpty)
                ? null
                : Text(
                    _profileName.isNotEmpty
                        ? _profileName[0].toUpperCase()
                        : 'U',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileName,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _profileEmail.isEmpty
                      ? 'Manage your rides and requests'
                      : _profileEmail,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideTabs() {
    final tabs = ['My Rides', 'Booked', 'Nearby Rides', 'Ride History'];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(
          tabs.length,
          (index) => Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == index
                      ? const Color(0xff113F67)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: _selectedTabIndex == index
                        ? Colors.white
                        : const Color(0xff113F67),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabContent() {
    if (_selectedTabIndex == 0) {
      final hasNoMyRideData = _myActiveRides.isEmpty;
      if (hasNoMyRideData) {
        return _sectionEmpty('No created/active rides by you.');
      }

      return Column(children: _myActiveRides.map(_myRideCard).toList());
    }

    if (_selectedTabIndex == 1) {
      return _myBookedRides.isEmpty
          ? _sectionEmpty('No active booked rides yet.')
          : Column(children: _myBookedRides.map(_bookedRideCard).toList());
    }

    if (_selectedTabIndex == 2) {
      return _nearbyRides.isEmpty
          ? _sectionEmpty('No nearby rides available right now.')
          : Column(children: _nearbyRides.map(_rideCard).toList());
    }

    return _rideHistory.isEmpty
        ? _sectionEmpty('No completed or past rides yet.')
        : Column(children: _rideHistory.map(_historyCard).toList());
  }

  Widget _sectionEmpty(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _incomingRequestCard(Map<String, dynamic> request) {
    final ride = request['rideId'] is Map
        ? Map<String, dynamic>.from(request['rideId'])
        : <String, dynamic>{};
    final user = request['userId'] is Map
        ? Map<String, dynamic>.from(request['userId'])
        : <String, dynamic>{};

    final riderName = (user['name'] ?? 'Rider').toString();
    final riderEmail = (user['email'] ?? '').toString();
    final riderPhone = (user['phone'] ?? '').toString();
    final routeFrom = (request['from'] ?? ride['from'] ?? '').toString();
    final routeTo = (request['to'] ?? ride['to'] ?? '').toString();
    final note = (request['note'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  (user['profileImage'] ?? '').toString().trim().isEmpty
                      ? AppConstant.defaultProfileImage
                      : user['profileImage'].toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riderName,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (riderEmail.isNotEmpty)
                      Text(
                        riderEmail,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'REQUESTED',
                  style: GoogleFonts.dmSans(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$routeFrom → $routeTo',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Preferred: ${request['date'] ?? '-'}  ${request['time'] ?? '-'}',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
          ),
          if (riderPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Phone: $riderPhone',
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Note: $note',
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black87),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToRequest(request, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: GoogleFonts.dmSans(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToRequest(request, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff113F67),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
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

  Widget _myRideCard(Map<String, dynamic> ride) {
    final car =
        ride['carDetails'] ??
        {'name': 'Car', 'number': 'XXX-000', 'color': 'Black'};
    final departure = _departureDate(ride);
    final status = _rideStatus(ride);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${ride['from']} → ${ride['to']}",
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: GoogleFonts.dmSans(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            departure == null
                ? 'Departure not set'
                : 'Departure: ${departure.day.toString().padLeft(2, '0')}-${departure.month.toString().padLeft(2, '0')}-${departure.year} ${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            "${ride['availableSeats'] ?? "N/A"} seats • ₹${ride['amount']}",
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${car['name']} • ${car['number']} • ${car['color']}",
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _goToRideDetails(ride),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff113F67),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _cancelRide((ride['_id'] ?? '').toString()),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel Ride',
                    style: GoogleFonts.dmSans(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bookedRideCard(Map<String, dynamic> ride) {
    final status = _rideStatus(ride);
    final departure = _departureDate(ride);
    final driverName = ride['driverId'] is Map
        ? (ride['driverId']['name'] ?? 'Driver')
        : 'Driver';
    final bookingId = (ride['bookingId'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${ride['from']} → ${ride['to']}",
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: GoogleFonts.dmSans(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            bookingId.isEmpty
                ? 'Booking ID unavailable'
                : 'Booking ID: $bookingId',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Driver: $driverName • Seats left: ${ride['availableSeats'] ?? 0}',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            departure == null
                ? 'Departure not set'
                : 'Departure: ${departure.day.toString().padLeft(2, '0')}-${departure.month.toString().padLeft(2, '0')}-${departure.year} ${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _goToRideDetails(ride),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff113F67),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideCard(Map<String, dynamic> ride) {
    final car =
        ride['carDetails'] ??
        {'name': 'Car', 'number': 'XXX-000', 'color': 'Black'};
    final driverImage =
        ride['driverImage'] != null && ride['driverImage'].isNotEmpty
        ? ride['driverImage']
        : AppConstant.defaultProfileImage;
    final rating = (ride['rating'] is num)
        ? (ride['rating'] as num).toDouble()
        : double.tryParse((ride['rating'] ?? '0').toString()) ?? 0.0;
    final driverName = ride["driverId"]?["name"] ?? 'Driver';
    final departure = _departureDate(ride);
    final distance = _distanceKm(ride);

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
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${car['name']} • ${car['number']} • ${car['color']} • ${ride['availableSeats']} seats",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffFFE5B4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "₹${(ride['amount'] is num ? ride['amount'] : num.tryParse((ride['amount'] ?? '0').toString()) ?? 0).toStringAsFixed(0)}",
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
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14),
              Expanded(
                child: Text(
                  ride['to'] ?? "",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(
                Icons.schedule,
                departure == null
                    ? 'Time N/A'
                    : '${departure.day.toString().padLeft(2, '0')}-${departure.month.toString().padLeft(2, '0')} ${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}',
              ),
              _metaChip(
                Icons.event_seat_rounded,
                '${ride['availableSeats'] ?? 0} seats',
              ),
              if (distance != null)
                _metaChip(Icons.near_me, '${distance.toStringAsFixed(1)} km'),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              child: Text(
                "View Details",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Widget _historyCard(Map<String, dynamic> ride) {
    final status = _rideStatus(ride);
    final departure = _departureDate(ride);
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.dmSans(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ride['from']} → ${ride['to']}',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  departure == null
                      ? 'Departure not available'
                      : 'Departed on ${departure.day.toString().padLeft(2, '0')}-${departure.month.toString().padLeft(2, '0')}-${departure.year}',
                  style: GoogleFonts.dmSans(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _goToRideDetails(ride),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xff113F67)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.dmSans(
              color: const Color(0xff113F67),
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
          Icon(
            Icons.directions_car_filled,
            size: 90,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            "No rides found",
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Please try again later.",
            style: GoogleFonts.dmSans(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
