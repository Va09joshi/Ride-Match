import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/services/notification_service.dart';
import 'package:ridematch/utils/app_constant.dart';
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
  static const double _nearbyDistanceMeters = 50000; // 50 km boundary

  GoogleMapController? mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  bool isLoading = false;
  BitmapDescriptor? rideMarkerIcon;
  Timer? _rideExpiryTimer;

  // Notification badge driven by NotificationService stream
  int _unreadNotifCount = 0;
  StreamSubscription<int>? _unreadSub;

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

    // Connect notification service and listen to unread count
    NotificationService.instance.connect().then((_) {
      _unreadSub = NotificationService.instance.unreadStream.listen((count) {
        if (mounted) setState(() => _unreadNotifCount = count);
      });
      if (mounted) {
        setState(
          () => _unreadNotifCount = NotificationService.instance.unreadCount,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.refreshUnreadCount();
    }
  }

  // Load custom marker icon
  Future<void> _loadMarkerIcon() async {
    try {
      // Build a small marker bitmap so large source assets don't appear huge on map.
      // The source image includes a light checker background; clear those pixels.
      rideMarkerIcon = await _createMarkerFromAsset(
        'assets/images/ride_marker.png',
        size: 92,
      );
    } catch (e) {
      try {
        rideMarkerIcon = await _createMarkerFromAsset(
          'assets/images/car.png',
          size: 92,
        );
      } catch (_) {
        rideMarkerIcon = null;
      }
    }
  }

  Future<BitmapDescriptor> _createMarkerFromAsset(
    String assetPath, {
    int size = 92,
  }) async {
    final byteData = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw Exception('Unable to decode marker image: $assetPath');
      }
      return BitmapDescriptor.fromBytes(png.buffer.asUint8List());
    }

    final bytes = Uint8List.fromList(raw.buffer.asUint8List());

    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final a = bytes[i + 3];

      if (a == 0) continue;

      final isLight = r > 175 && g > 175 && b > 175;
      final isNeutral = (r - g).abs() <= 20 && (g - b).abs() <= 20;

      if (isLight && isNeutral) {
        bytes[i + 3] = 0;
      }
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: image.width,
      height: image.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final outCodec = await descriptor.instantiateCodec();
    final outFrame = await outCodec.getNextFrame();
    final pngData = await outFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (pngData == null) {
      throw Exception('Unable to create marker bytes from $assetPath');
    }

    return BitmapDescriptor.fromBytes(pngData.buffer.asUint8List());
  }

  // Initialization
  Future<void> _initialize() async {
    await _getUserLocation();
    await _loadUserData();
    await fetchUserData();
    await fetchRides();

    if (widget.bookedRide != null) {
      _addBookedRideMarker(widget.bookedRide!);
    }
  }

  void _startRideExpiryWatcher() {
    _rideExpiryTimer?.cancel();
    _rideExpiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      fetchRides();
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
        AppApi.uri(AppEndpoints.authMe),
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
      final Uri endpoint = _currentPosition == null
          ? AppApi.uri(
              AppEndpoints.rides,
              queryParameters: {
                if ((currentUserId ?? '').isNotEmpty)
                  'excludeUserId': currentUserId,
              },
            )
          : AppApi.uri(
              AppEndpoints.ridesNearby,
              queryParameters: {
                'longitude': _currentPosition!.longitude,
                'latitude': _currentPosition!.latitude,
                'maxDistance': _nearbyDistanceMeters,
                if ((currentUserId ?? '').isNotEmpty)
                  'excludeUserId': currentUserId,
              },
            );

      final response = await http.get(endpoint);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rides = (data['rides'] is List)
            ? data['rides'] as List
            : <dynamic>[];

        setState(() {
          ridePosts = rides;
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
    // 1. Prefer pickupLocation (from create ride form)
    final pickupLat = ride['pickupLocation']?['lat'];
    final pickupLng = ride['pickupLocation']?['lng'];
    if (pickupLat != null && pickupLng != null) {
      return LatLng(
        (pickupLat as num).toDouble(),
        (pickupLng as num).toDouble(),
      );
    }

    // 2. Fallback to location.coordinates (GeoJSON)
    final coordinates = ride['location']?['coordinates'];
    if (coordinates is List && coordinates.length >= 2) {
      final lng = (coordinates[0] as num).toDouble();
      final lat = (coordinates[1] as num).toDouble();
      return LatLng(lat, lng);
    }

    // 3. Fallback to fromLat/fromLong
    final fromLat = double.tryParse((ride['fromLat'] ?? '').toString());
    final fromLong = double.tryParse((ride['fromLong'] ?? '').toString());
    if (fromLat != null && fromLong != null) {
      return LatLng(fromLat, fromLong);
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
    return distanceMeters <= _nearbyDistanceMeters;
  }

  List<Map<String, dynamic>> _visibleNearbyRides() {
    final from = fromController.text.toLowerCase().trim();
    final to = toController.text.toLowerCase().trim();
    final List<Map<String, dynamic>> visible = [];

    for (final raw in ridePosts) {
      if (raw is! Map) continue;
      final ride = Map<String, dynamic>.from(raw as Map);

      String? driverId;
      if (ride['driverId'] is String) {
        driverId = ride['driverId'];
      } else if (ride['driverId'] is Map && ride['driverId']['_id'] != null) {
        driverId = ride['driverId']['_id'];
      }

      if (driverId == currentUserId) continue;
      if (!_isUpcomingRide(ride)) continue;

      final seats =
          int.tryParse((ride['availableSeats'] ?? '0').toString()) ?? 0;
      if (seats <= 0) continue;

      final rideFrom = (ride['from'] ?? '').toString().toLowerCase();
      final rideTo = (ride['to'] ?? '').toString().toLowerCase();
      if ((from.isNotEmpty && !rideFrom.contains(from)) ||
          (to.isNotEmpty && !rideTo.contains(to))) {
        continue;
      }

      final ridePos = _extractRideLocation(ride);
      if (ridePos == null) continue;
      if (!_isNearby(ridePos)) continue;

      visible.add(ride);
    }

    return visible;
  }

  // Add all ride markers for upcoming nearby rides
  void _addRideMarkers() {
    // remove only previous ride_* markers (keep booked markers)
    _markers.removeWhere((m) => m.markerId.value.startsWith('ride_'));

    final visibleRides = _visibleNearbyRides();
    for (final ride in visibleRides) {
      final ridePos = _extractRideLocation(ride);
      if (ridePos == null) continue;

      final markerId = MarkerId('ride_${ride['_id']}');

      _markers.add(
        Marker(
          markerId: markerId,
          position: ridePos,
          icon: rideMarkerIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: "${ride['from']} → ${ride['to']}",
            snippet:
                "₹${ride['amount']} • ${ride['availableSeats']} seats • ${ride['date']} ${ride['time']}",
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final driver = ride["driverId"];
        final driverName =
            driver?["name"] ?? ride["driver"] ?? "Unknown Driver";
        final driverPhone = (ride['driverPhone'] ?? driver?['phone'] ?? '')
            .toString()
            .trim();
        final driverImg = _rideDriverImage(ride);
        final hasProfileImg = driverImg != null && driverImg.trim().isNotEmpty;

        final carName = (ride['carDetails']?['name'] ?? '').toString().trim();
        final carNumber = (ride['carDetails']?['number'] ?? '')
            .toString()
            .trim();
        final carColor = (ride['carDetails']?['color'] ?? '').toString().trim();
        final vehicleInfo = [
          carName,
          carNumber,
          carColor,
        ].where((v) => v.isNotEmpty).join(' • ');

        final seats = (ride["availableSeats"] ?? ride["seats"] ?? 1).toString();
        final amount = (ride['amount'] ?? '0').toString();
        final rideStatus = (ride['status'] ?? 'created').toString();
        final statusLabel = rideStatus.replaceAll('_', ' ').toUpperCase();

        final departure = _departureDateTime(Map<String, dynamic>.from(ride));
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final departureText = departure == null
            ? "Not specified"
            : "${departure.day} ${months[departure.month - 1]} ${departure.year}, ${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}";

        final fromPlace = (ride['from'] ?? 'Pickup').toString();
        final toPlace = (ride['to'] ?? 'Drop').toString();

        Color statusColor;
        switch (rideStatus) {
          case 'active':
            statusColor = Colors.blue;
            break;
          case 'in_progress':
            statusColor = Colors.orange;
            break;
          case 'completed':
            statusColor = Colors.green;
            break;
          case 'cancelled':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.blueGrey;
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Route visualization
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        // Route dots + line
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 30,
                              color: Colors.grey.shade400,
                            ),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Place names
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fromPlace,
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                toPlace,
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Chips row: seats, price, status
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        Icons.event_seat_outlined,
                        '$seats seats',
                        Colors.indigo,
                      ),
                      _chip(
                        Icons.currency_rupee,
                        '₹$amount',
                        Colors.green.shade700,
                      ),
                      _chip(Icons.circle, statusLabel, statusColor),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Departure
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          departureText,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Driver card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: hasProfileImg
                              ? NetworkImage(driverImg!)
                              : null,
                          child: !hasProfileImg
                              ? Icon(
                                  Icons.person,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (vehicleInfo.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    vehicleInfo,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              if (driverPhone.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    driverPhone,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Open Ride button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
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
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff113F67),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      label: Text(
                        "Open Ride Details",
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
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
                final rides = _visibleNearbyRides();
                final String rideId = rides.isNotEmpty
                    ? (rides.first['_id'] ?? '').toString()
                    : '';

                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 120), () {
                  if (!mounted) return;
                  openCreateLocationRequest(rideId);
                });
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

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xff113F67)),
      title: Text(
        title,
        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
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

  void _showAllNearbyRidesSheet() {
    final rides = _visibleNearbyRides();
    if (rides.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nearby Ride Posts (${rides.length})',
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff113F67),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rides.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      final driverName = (ride['driverId'] is Map)
                          ? (ride['driverId']['name'] ?? 'Driver').toString()
                          : 'Driver';

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          _showRideDetail(ride);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xffF6FAFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffE1EAF5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ride['from']} -> ${ride['to']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xff102A43),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$driverName • ₹${ride['amount'] ?? 0} • ${ride['availableSeats'] ?? 0} seats',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xff486581),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ride['date'] ?? '-'} ${ride['time'] ?? '-'}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearbyVisibleRides = _visibleNearbyRides();

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                userName ?? "RideMatch User",
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                fullAddress ?? "Welcome to RideMatch",
                style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  userName != null && userName!.isNotEmpty
                      ? userName![0].toUpperCase()
                      : "U",
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff113F67),
                  ),
                ),
              ),
              decoration: const BoxDecoration(color: Color(0xff113F67)),
            ),
            _drawerTile(Icons.person_outline, "My Profile", () {
              Navigator.pop(context);
            }),
            _drawerTile(Icons.directions_car_outlined, "My Rides", () {
              Navigator.pop(context);
            }),
            _drawerTile(Icons.history, "Ride History", () {
              Navigator.pop(context);
            }),
            _drawerTile(Icons.payment_outlined, "Payments", () {
              Navigator.pop(context);
            }),
            _drawerTile(Icons.settings_outlined, "Settings", () {
              Navigator.pop(context);
            }),
            const Divider(height: 1),
            _drawerTile(Icons.info_outline, "About RideMatch", () {
              Navigator.pop(context);
            }),
            _drawerTile(Icons.description_outlined, "Terms & Privacy", () {
              Navigator.pop(context);
            }),
            _drawerTile(Icons.star_outline, "Rate Us", () {
              Navigator.pop(context);
            }),
            _drawerTile(Icons.help_outline, "Help & Support", () {
              Navigator.pop(context);
            }),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                'Logout',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Text(
                "RideMatch v1.0.0",
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xff113F67),
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 75,
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
              showBadge: _unreadNotifCount > 0,
              position: badges.BadgePosition.topEnd(top: -5, end: -5),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: Colors.red,
                elevation: 0,
                padding: EdgeInsets.all(5),
              ),
              badgeContent: _unreadNotifCount > 9
                  ? const Text(
                      '9+',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    )
                  : _unreadNotifCount > 0
                  ? Text(
                      _unreadNotifCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    )
                  : const SizedBox.shrink(),
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            onPressed: () {
              NotificationService.instance.markAllRead();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
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
                          backgroundImage: (() {
                            final img = _rideDriverImage(_selectedMarkerData);
                            if (img == null || img.isEmpty) return null;
                            return NetworkImage(img);
                          })(),
                          child:
                              (_rideDriverImage(_selectedMarkerData) == null ||
                                  _rideDriverImage(
                                    _selectedMarkerData,
                                  )!.isEmpty)
                              ? _buildDriverAvatar(
                                  _selectedMarkerData?['driver'] ??
                                      _selectedMarkerData?['driverId']?['name'],
                                )
                              : null,
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

      // Nearby rides indicator chip
      bottomNavigationBar: nearbyVisibleRides.isNotEmpty
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: GestureDetector(
                onTap: () {
                  _showAllNearbyRidesSheet();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff113F67),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${nearbyVisibleRides.length} ride${nearbyVisibleRides.length > 1 ? 's' : ''} nearby",
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "View All",
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
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

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String? _rideDriverImage(dynamic ride) {
    if (ride is! Map) return null;
    final direct = (ride['driverImage'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final driver = ride['driverId'];
    if (driver is Map) {
      final nested = (driver['profileImage'] ?? '').toString().trim();
      if (nested.isNotEmpty) return nested;
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rideExpiryTimer?.cancel();
    _unreadSub?.cancel();
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }
}
