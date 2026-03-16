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

  bool hasNewNotification = false;

  List<dynamic> ridePosts = [];
  String? userName;
  String? fullAddress;
  String? currentUserId;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  // =================== DEMO MARKERS (INDORE) =====================
  final List<Map<String, dynamic>> demoMarkers = [
    {
      "pos": LatLng(22.7196, 75.8577),
      "title": "Rajwada Palace",
      "driver": "Amit Sharma",
      "bike": "Activa 5G",
      "amount": 40
    },
    {
      "pos": LatLng(22.7533, 75.8937),
      "title": "Vijay Nagar",
      "driver": "Rohit Verma",
      "bike": "Honda Shine",
      "amount": 55
    },
    {
      "pos": LatLng(22.6900, 75.8765),
      "title": "Indore Junction",
      "driver": "Sandeep Patel",
      "bike": "Bajaj Pulsar",
      "amount": 60
    },
    {
      "pos": LatLng(22.7253, 75.8638),
      "title": "Lalbagh Palace",
      "driver": "Vikas Yadav",
      "bike": "TVS Apache",
      "amount": 45
    }
  ];

  // popup state
  Map<String, dynamic>? _selectedMarkerData;
  LatLng? _selectedMarkerLatLng;
  Offset? _popupOffset; // screen coordinates for popup
  bool _showPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initialize();
    _loadMarkerIcon();

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

    // Add demo markers (Indore)
    _ensureDemoMarkers();

    // Check notifications at launch
    await checkNotifications();

    if (widget.bookedRide != null) {
      _addBookedRideMarker(widget.bookedRide!);
    }
  }

  // Get current user location
  Future<void> _getUserLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    List<Placemark> placemarks =
    await placemarkFromCoordinates(position.latitude, position.longitude);

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
          data['notifications'] ?? data['notification'] ?? data['data'] ?? []);

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

  // Add all ride markers (keeps demo markers)
  void _addRideMarkers() {
    // remove only previous ride_* markers (keep demo_* and booked markers)
    _markers.removeWhere((m) =>
        m.markerId.value.startsWith('ride_')); // remove old ride markers

    for (var ride in ridePosts) {
      String? driverId;

      if (ride['driverId'] is String) {
        driverId = ride['driverId'];
      } else if (ride['driverId'] is Map &&
          ride['driverId']['_id'] != null) {
        driverId = ride['driverId']['_id'];
      }

      if (driverId == currentUserId) continue;

      double? lat = double.tryParse(ride['fromLat']?.toString() ?? '');
      double? lng = double.tryParse(ride['fromLong']?.toString() ?? '');

      lat ??= ride['pickupLocation']?['lat'];
      lng ??= ride['pickupLocation']?['lng'];

      if (lat == null || lng == null) continue;

      final markerId = MarkerId('ride_${ride['_id']}');

      _markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          icon: rideMarkerIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: "${ride['from']} → ${ride['to']}",
            snippet: "Rs ${ride['amount']}",
            onTap: () => _showRideDetail(ride),
          ),
          onTap: () => _onMarkerTap(ride, LatLng(lat!, lng!)),
        ),
      );
    }

    // ensure demo markers still present
    _ensureDemoMarkers();

    Future.delayed(const Duration(milliseconds: 300), _zoomToFitMarkers);
  }

  // Ensure demo markers exists (doesn't duplicate)
  void _ensureDemoMarkers() {
    // if demo markers already present, don't re-add duplicates
    final existingDemoIds =
    _markers.map((m) => m.markerId.value).where((id) => id.startsWith('demo_')).toSet();

    for (int i = 0; i < demoMarkers.length; i++) {
      if (existingDemoIds.contains('demo_$i')) continue;

      final d = demoMarkers[i];

      _markers.add(
        Marker(
          markerId: MarkerId('demo_$i'),
          position: d["pos"],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: d['title'],
            snippet: "${d['driver']} | ${d['bike']}",
            onTap: () {
              // open bottom sheet using same shape as server rides
              _showRideDetail({
                'from': d['title'],
                'to': d['title'],
                'driverId': {'name': d['driver']},
                'bike': d['bike'],
                'amount': d['amount'],
                'seats': 1
              });
            },
          ),
          onTap: () => _onMarkerTap({
            'from': d['title'],
            'to': d['title'],
            'driverId': {'name': d['driver']},
            'bike': d['bike'],
            'amount': d['amount'],
            'seats': 1
          }, d['pos']),
        ),
      );
    }

    setState(() {});
  }

  // Called when any marker is tapped to show custom popup
  Future<void> _onMarkerTap(Map<String, dynamic> rideData, LatLng pos) async {
    try {
      if (mapController == null) {
        // fallback: just open bottom sheet
        _showRideDetail(rideData);
        return;
      }

      // get screen coordinate of the LatLng
      ScreenCoordinate sc = await mapController!.getScreenCoordinate(pos);

      // convert device pixels to logical pixels
      final dp = MediaQuery.of(context).devicePixelRatio;
      final logicalX = sc.x / dp;
      final logicalY = sc.y / dp;

      // offset the popup so it appears above the marker
      // we will center horizontally (subtract half popup width)
      // and move up by popup height
      const popupWidth = 220.0;
      const popupHeight = 110.0;

      final left = logicalX - (popupWidth / 2);
      final top = logicalY - popupHeight - 20; // 20 px gap above marker

      setState(() {
        _selectedMarkerData = rideData;
        _selectedMarkerLatLng = pos;
        _popupOffset = Offset(left, top);
        _showPopup = true;
      });
    } catch (e) {
      // if anything fails, just open bottom sheet
      _showRideDetail(rideData);
    }
  }

  // Filter rides by From/To
  void _filterRides() {
    String from = fromController.text.toLowerCase();
    String to = toController.text.toLowerCase();

    // clear only ride_* markers so demo markers remain
    _markers.removeWhere((m) => m.markerId.value.startsWith('ride_'));

    for (var ride in ridePosts) {
      final driver = ride['driverId'];
      final driverId = driver is String ? driver : driver['_id'];

      if (driverId == currentUserId) continue;

      String rideFrom = (ride['from'] ?? '').toLowerCase();
      String rideTo = (ride['to'] ?? '').toLowerCase();

      if ((from.isEmpty || rideFrom.contains(from)) &&
          (to.isEmpty || rideTo.contains(to)) &&
          ride['fromLat'] != null &&
          ride['fromLong'] != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('ride_${ride['_id']}'),
            position: LatLng(
              double.parse(ride['fromLat'].toString()),
              double.parse(ride['fromLong'].toString()),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: "${ride['from']} → ${ride['to']}",
              snippet: "Rs ${ride['amount']}",
              onTap: () => _showRideDetail(ride),
            ),
            onTap: () => _onMarkerTap(ride, LatLng(double.parse(ride['fromLat'].toString()),
                double.parse(ride['fromLong'].toString()))),
          ),
        );
      }
    }

    // ensure demo markers still present (no duplicates)
    _ensureDemoMarkers();

    Future.delayed(const Duration(milliseconds: 300), _zoomToFitMarkers);
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
      await mapController!.moveCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      await mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } catch (e) {
      final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(center, 2));
    }
  }

  // Add booked ride markers
  void _addBookedRideMarker(Map<String, dynamic> ride) {
    if (ride['pickupLocation'] != null && ride['dropLocation'] != null) {
      final pickup = LatLng(ride['pickupLocation']['lat'], ride['pickupLocation']['lng']);
      final drop = LatLng(ride['dropLocation']['lat'], ride['dropLocation']['lng']);

      // remove old booked markers first
      _markers.removeWhere((m) => m.markerId.value == 'booked_pickup' || m.markerId.value == 'booked_drop');

      _markers.add(
        Marker(
          markerId: const MarkerId('booked_pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
        final driverName = driver?["name"] ?? ride["driver"] ?? "Unknown Driver";
        final bike = ride["bike"] ?? "Bike not listed";
        final price = ride["amount"] ?? "0";
        final seats = ride["seats"]?.toString() ?? "1";

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

              // Pricing + seats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoTile("Price", "₹$price"),
                  _infoTile("Seats", seats),
                  _infoTile("From", ride["from"]),
                  _infoTile("To", ride["to"]),
                ],
              ),

              const SizedBox(height: 28),

              // Join Ride Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RideDetailsScreen(rideData: ride, currentUserId: '',),
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
                    "Join Ride",
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
    return Column(
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
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
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(thickness: 1, height: 20),
            _buildActionTile(
              icon: Icons.directions_car,
              title: "Create a Ride",
              iconBgColor: Colors.blue.shade50,
              iconColor: Colors.blue.shade700,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRideScreen())),
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
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("No rides available to request.")));
                }
              },
            ),
            _buildActionTile(
              icon: Icons.people_alt,
              title: "Nearby Matches",
              iconBgColor: Colors.orange.shade50,
              iconColor: Colors.orange.shade700,
              onTap: () => Navigator.pop(context),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey[400]),
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
            Text("Hey ${userName ?? 'User'} 👋",
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(fullAddress ?? "Fetching location...",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400)),
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
          )
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
            initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14.5),
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
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 3))],
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
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
                  IconButton(icon: const Icon(Icons.filter_alt_outlined, color: Colors.blueAccent), onPressed: _filterRides),
                ],
              ),
            ),
          ),

          // Custom popup (Style 2: bigger card with photo)
          if (_showPopup && _selectedMarkerData != null && _popupOffset != null)
            Positioned(
              left: _popupOffset!.dx.clamp(8.0, MediaQuery.of(context).size.width - 228.0),
              top: _popupOffset!.dy.clamp(80.0, MediaQuery.of(context).size.height - 140.0),
              child: GestureDetector(
                onTap: () {
                  // open ride detail bottom sheet
                  _showRideDetail(_selectedMarkerData);
                },
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        // driver photo placeholder
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.grey[200],
                          child: _buildDriverAvatar(_selectedMarkerData?['driver'] ?? _selectedMarkerData?['driverId']?['name']),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedMarkerData?['driverId']?['name'] ??
                                    _selectedMarkerData?['driver'] ??
                                    'Driver',
                                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if ((_selectedMarkerData?['bike'] ?? '').isNotEmpty)
                                Text("${_selectedMarkerData?['bike']}",
                                    style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[700])),
                              const SizedBox(height: 6),
                              Text(
                                "${_selectedMarkerData?['from']} → ${_selectedMarkerData?['to']}",
                                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[800]),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("₹${_selectedMarkerData?['amount'] ?? 0}",
                                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
                                  GestureDetector(
                                    onTap: () {
                                      // explicitly open details (stop event propagation)
                                      _showRideDetail(_selectedMarkerData);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xff113F67),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text("View",
                                          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        )
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
          label: Text("Quick Actions", style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500)),
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
    String initials = parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}' : parts[0][0];
    return Text(initials.toUpperCase(), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700));
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }
}
