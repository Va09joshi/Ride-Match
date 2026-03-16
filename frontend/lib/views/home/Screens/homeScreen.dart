import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRequest.dart';
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRide.dart';
import 'package:ridematch/views/home/widgets/map_shimmer.dart';
import 'package:ridematch/views/notification/notifications_screen.dart';
import 'package:ridematch/views/ride_detail/ridedetails.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? bookedRide;

  const HomeScreen({super.key, this.bookedRide});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  bool isLoading = false;
  BitmapDescriptor? rideMarkerIcon;
  Timer? _rideExpiryTimer;

  bool hasNewNotification = false;

  List<dynamic> ridePosts = [];
  String? userName;
  String? fullAddress;
  String? currentUserId;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  // marker selection state for top ride sheet
  Map<String, dynamic>? _selectedMarkerData;
  bool _showPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initialize();
    _loadMarkerIcon();
    _startRideExpiryWatcher();

    fromController.addListener(_filterRides);
    toController.addListener(_filterRides);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkNotifications();
    }
  }

  // Load custom marker icon
  Future<void> _loadMarkerIcon() async {
    try {
      rideMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/ride_marker.png',
      );
    } catch (e) {
      // fallback silently
      rideMarkerIcon = null;
    }
  }

  // Initialization
  Future<void> _initialize() async {
    await _getUserLocation();
    await _loadUserData();
    await fetchUserData();
    await fetchRides();

    // Check notifications at launch
    await checkNotifications();

    if (widget.bookedRide != null) {
      _addBookedRideMarker(widget.bookedRide!);
    }
  }

  void _startRideExpiryWatcher() {
    _rideExpiryTimer?.cancel();
    _rideExpiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _addRideMarkers();
    });
  }

  // Get current user location
  Future<void> _getUserLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      fullAddress =
          "${placemarks.first.locality ?? ''}, ${placemarks.first.administrativeArea ?? ''}";
    });
  }

  // CHECK NOTIFICATION BADGE
  Future<void> checkNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userId = prefs.getString('userId');

    if (userId == null) return;

    final res = await http.get(
      Uri.parse("$baseurl/api/notifications/$userId"),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      final list = List<Map<String, dynamic>>.from(
        data['notifications'] ?? data['notification'] ?? data['data'] ?? [],
      );

      bool hasUnread = list.any((item) => item['read'] == false);

      setState(() {
        hasNewNotification = hasUnread;
      });
    }
  }

  // Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('username') ?? "User";
      currentUserId = prefs.getString('userId');
    });
  }

  // Fetch profile
  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('$baseurl/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final fetchedName = data['user']?['name'] ?? "User";

        await prefs.setString('username', fetchedName);

        setState(() => userName = fetchedName);
      }
    } catch (e) {
      print("❌ Error fetching user data: $e");
    }
  }

  // Fetch rides
  Future<void> fetchRides() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseurl/api/rides'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          ridePosts = data['rides'];
          _addRideMarkers();
        });
      }
    } catch (e) {
      print("Error fetching rides: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  DateTime? _departureDateTime(Map<String, dynamic> ride) {
    final rawDate = (ride['date'] ?? '').toString().trim();
    final rawTime = (ride['time'] ?? '').toString().trim();
    if (rawDate.isEmpty || rawTime.isEmpty) return null;

    final dateParts = rawDate.split(RegExp(r'[-/]'));
    if (dateParts.length != 3) return null;

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return null;

    final timeParts = rawTime.split(':');
    final hour = int.tryParse(timeParts[0]);
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;
    if (hour == null || minute == null) return null;

    return DateTime(year, month, day, hour, minute);
  }

  bool _isUpcomingRide(Map<String, dynamic> ride) {
    final departure = _departureDateTime(ride);
    if (departure == null) return true;
    return departure.isAfter(DateTime.now());
  }

  LatLng? _extractRideLocation(Map<String, dynamic> ride) {
    final fromLat = double.tryParse((ride['fromLat'] ?? '').toString());
    final fromLong = double.tryParse((ride['fromLong'] ?? '').toString());
    if (fromLat != null && fromLong != null) {
      return LatLng(fromLat, fromLong);
    }

    final pickupLat = ride['pickupLocation']?['lat'];
    final pickupLng = ride['pickupLocation']?['lng'];
    if (pickupLat != null && pickupLng != null) {
      return LatLng(
        (pickupLat as num).toDouble(),
        (pickupLng as num).toDouble(),
      );
    }

    final coordinates = ride['location']?['coordinates'];
    if (coordinates is List && coordinates.length >= 2) {
      final lng = (coordinates[0] as num).toDouble();
      final lat = (coordinates[1] as num).toDouble();
      return LatLng(lat, lng);
    }

    return null;
  }

  bool _isNearby(LatLng ridePos) {
    if (_currentPosition == null) return true;
    final distanceMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      ridePos.latitude,
      ridePos.longitude,
    );
    return distanceMeters <= 25000; // 25 km radius
  }

  // Add all ride markers for upcoming nearby rides
  void _addRideMarkers() {
    // remove only previous ride_* markers (keep booked markers)
    _markers.removeWhere((m) => m.markerId.value.startsWith('ride_'));

    final from = fromController.text.toLowerCase().trim();
    final to = toController.text.toLowerCase().trim();

    for (var ride in ridePosts) {
      String? driverId;

      if (ride['driverId'] is String) {
        driverId = ride['driverId'];
      } else if (ride['driverId'] is Map && ride['driverId']['_id'] != null) {
        driverId = ride['driverId']['_id'];
      }

      if (driverId == currentUserId) continue;
      if (!_isUpcomingRide(ride)) continue;

      final rideFrom = (ride['from'] ?? '').toString().toLowerCase();
      final rideTo = (ride['to'] ?? '').toString().toLowerCase();
      if ((from.isNotEmpty && !rideFrom.contains(from)) ||
          (to.isNotEmpty && !rideTo.contains(to))) {
        continue;
      }

      final ridePos = _extractRideLocation(ride);
      if (ridePos == null) continue;
      if (!_isNearby(ridePos)) continue;

      final markerId = MarkerId('ride_${ride['_id']}');

      _markers.add(
        Marker(
          markerId: markerId,
          position: ridePos,
          icon: rideMarkerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: "${ride['from']} → ${ride['to']}",
            snippet: "Rs ${ride['amount']}",
            onTap: () => _showRideDetail(ride),
          ),
          onTap: () => _onMarkerTap(ride),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 300), _zoomToFitMarkers);
    if (mounted) {
      setState(() {});
    }
  }

  // Called when marker is tapped to show top sheet
  void _onMarkerTap(Map<String, dynamic> rideData) {
    setState(() {
      _selectedMarkerData = rideData;
      _showPopup = true;
    });
  }

  // Filter rides by From/To
  void _filterRides() {
    _addRideMarkers();
  }

  // Zoom map to fit all markers
  void _zoomToFitMarkers() async {
    if (_markers.isEmpty || mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (var m in _markers) {
      minLat = m.position.latitude < minLat ? m.position.latitude : minLat;
      maxLat = m.position.latitude > maxLat ? m.position.latitude : maxLat;

      minLng = m.position.longitude < minLng ? m.position.longitude : minLng;
      maxLng = m.position.longitude > maxLng ? m.position.longitude : maxLng;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await mapController!.moveCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(center, 2));
    }
  }

  // Add booked ride markers
  void _addBookedRideMarker(Map<String, dynamic> ride) {
    if (ride['pickupLocation'] != null && ride['dropLocation'] != null) {
      final pickup = LatLng(
        ride['pickupLocation']['lat'],
        ride['pickupLocation']['lng'],
      );
      final drop = LatLng(
        ride['dropLocation']['lat'],
        ride['dropLocation']['lng'],
      );

      // remove old booked markers first
      _markers.removeWhere(
        (m) =>
            m.markerId.value == 'booked_pickup' ||
            m.markerId.value == 'booked_drop',
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('booked_pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: "Your Pickup"),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('booked_drop'),
          position: drop,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: "Your Drop"),
        ),
      );

      Future.delayed(const Duration(milliseconds: 200), _zoomToFitMarkers);
      setState(() {});
    }
  }

  // Show ride details
  void _showRideDetail(dynamic ride) {
    // hide popup when opening bottom sheet
    setState(() {
      _showPopup = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final driver = ride["driverId"];
        final driverName =
            driver?["name"] ?? ride["driver"] ?? "Unknown Driver";
        final bike = ride["bike"] ?? "Bike not listed";
        final price = ride["amount"] ?? "0";
        final seats = (ride["availableSeats"] ?? ride["seats"] ?? 1).toString();
        final departure = _departureDateTime(Map<String, dynamic>.from(ride));
        final departureText = departure == null
            ? "Not specified"
            : "${departure.day.toString().padLeft(2, '0')}-${departure.month.toString().padLeft(2, '0')}-${departure.year} ${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}";
        final description =
            (ride["description"] ??
                    ride["note"] ??
                    "Comfortable ride with verified driver")
                .toString();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                "${ride['from']} → ${ride['to']}",
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // Driver + bike info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(Icons.person, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 14),

                    // Driver info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: GoogleFonts.dmSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bike,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _infoTile("Ride summary", "${ride["from"]} → ${ride["to"]}"),
              const SizedBox(height: 10),
              _infoTile("Departure", departureText),
              const SizedBox(height: 10),
              _infoTile("Available seats", seats),
              const SizedBox(height: 10),
              _infoTile("Short description", description),

              const SizedBox(height: 28),

              // View full ride button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RideDetailsScreen(
                          rideData: ride,
                          currentUserId: currentUserId ?? '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff113F67),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "View Full Ride",
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Small info tile widget
  Widget _infoTile(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white54,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Wrap(
          runSpacing: 6,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 60,
                decoration: BoxDecoration(
                  color: const Color(0xff113F67),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Quick Actions",
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(thickness: 1, height: 20),
            _buildActionTile(
              icon: Icons.directions_car,
              title: "Create a Ride",
              iconBgColor: Colors.blue.shade50,
              iconColor: Colors.blue.shade700,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRideScreen()),
              ),
            ),
            _buildActionTile(
              icon: Icons.add_location_alt,
              title: "Create a Location Request",
              iconBgColor: Colors.green.shade50,
              iconColor: Colors.green.shade700,
              onTap: () {
                Navigator.pop(context);
                if (ridePosts.isNotEmpty) {
                  openCreateLocationRequest(ridePosts[0]['_id']);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("No rides available to request."),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void openCreateLocationRequest(String rideId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLocationRequestScreen(rideId: rideId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xff113F67),
        toolbarHeight: 75,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hey ${userName ?? 'User'} 👋",
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fullAddress ?? "Fetching location...",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: badges.Badge(
              showBadge: hasNewNotification,
              position: badges.BadgePosition.topEnd(top: -5, end: -5),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: Colors.red,
                elevation: 0,
                padding: EdgeInsets.all(5), // size of dot
              ),
              badgeContent: const SizedBox.shrink(),
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ).then((_) {
                setState(() {
                  hasNewNotification = false;
                });
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          _currentPosition == null
              ? const MapShimmerLoader(
                  showSearchBar: true,
                  showCenterButton: true,
                  markerCount: 0,
                )
              : GoogleMap(
                  onMapCreated: (controller) {
                    mapController = controller;
                    // hide popup if map is interacted with
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 14.5,
                  ),
                  myLocationEnabled: true,
                  markers: _markers,
                  onTap: (latlng) {
                    // hide custom popup when tapping map
                    setState(() {
                      _showPopup = false;
                    });
                  },
                ),

          // SEARCH BAR
          Positioned(
            top: 16,
            left: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fromController,
                      decoration: InputDecoration(
                        hintText: "From...",
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.dmSans(color: Colors.grey),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: toController,
                      decoration: InputDecoration(
                        hintText: "To...",
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.dmSans(color: Colors.grey),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.filter_alt_outlined,
                      color: Colors.blueAccent,
                    ),
                    onPressed: _filterRides,
                  ),
                ],
              ),
            ),
          ),

          // Top sheet preview shown after marker tap
          if (_showPopup && _selectedMarkerData != null)
            Positioned(
              top: 94,
              left: 14,
              right: 14,
              child: GestureDetector(
                onTap: () {
                  // step 2: open bottom sheet preview
                  _showRideDetail(_selectedMarkerData);
                },
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey[200],
                          child: _buildDriverAvatar(
                            _selectedMarkerData?['driver'] ??
                                _selectedMarkerData?['driverId']?['name'],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${_selectedMarkerData?['from']} → ${_selectedMarkerData?['to']}",
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedMarkerData?['driverId']?['name'] ??
                                    _selectedMarkerData?['driver'] ??
                                    'Driver',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Tap to preview",
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xff113F67),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          onPressed: _showQuickActions,
          backgroundColor: const Color(0xff113F67),
          label: Text(
            "Quick Actions",
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          elevation: 8,
        ),
      ),
    );
  }

  Widget _buildDriverAvatar(String? name) {
    if (name == null || name.isEmpty) {
      return const Icon(Icons.person, color: Colors.grey);
    }
    final parts = name.split(' ');
    String initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : parts[0][0];
    return Text(
      initials.toUpperCase(),
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  void dispose() {
    _rideExpiryTimer?.cancel();
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }
}
