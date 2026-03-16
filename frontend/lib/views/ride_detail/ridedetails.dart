import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:ridematch/views/dashboard/Screens/Dashboard.dart';
import 'package:ridematch/views/home/Screens/homeScreen.dart';
import 'package:url_launcher/url_launcher.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String currentUserId;

  const RideDetailsScreen({
    super.key,
    required this.rideData,
    required this.currentUserId,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  late LatLng pickup;
  late LatLng drop;

  String distanceText = "0 km";
  String etaText = "0 mins";
  String fareText = "₹0";


  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();

    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Default pickup/drop
    pickup = widget.rideData['pickupLocation'] != null
        ? LatLng(widget.rideData['pickupLocation']['lat'], widget.rideData['pickupLocation']['lng'])
        : const LatLng(28.6139, 77.2090); // Default Delhi
    drop = widget.rideData['dropLocation'] != null
        ? LatLng(widget.rideData['dropLocation']['lat'], widget.rideData['dropLocation']['lng'])
        : const LatLng(28.7041, 77.1025);

    fareText = "₹${widget.rideData['amount'] ?? 0}";

    _calculateDistanceETA();
    _prepareMapElements();
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear(); // Clear Razorpay listeners
  }

  void _calculateDistanceETA() {
    double dist = _haversineDistance(
      pickup.latitude,
      pickup.longitude,
      drop.latitude,
      drop.longitude,
    );

    setState(() {
      distanceText = "${dist.toStringAsFixed(1)} km";
      etaText = "${(dist * 2).round()} mins"; // Rough ETA
    });
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * pi / 180;

  void _prepareMapElements() {
    _markers.clear();
    _polylines.clear();

    _markers.addAll([
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Pickup"),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: drop,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Drop"),
      ),
    ]);

    _polylines.add(Polyline(
      polylineId: const PolylineId("route"),
      points: [pickup, drop],
      width: 5,
      color: Colors.orangeAccent,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCameraToRoute());
  }

  Future<void> _fitCameraToRoute() async {
    if (_mapController == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(min(pickup.latitude, drop.latitude), min(pickup.longitude, drop.longitude)),
      northeast: LatLng(max(pickup.latitude, drop.latitude), max(pickup.longitude, drop.longitude)),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    });
  }

  Future<void> _launchCaller(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri uri = Uri(scheme: "tel", path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  // Razorpay payment integration
  void _openRazorpayCheckout() {
    int amountInPaise = ((widget.rideData['amount'] ?? 0) * 100).toInt();

    var options = {
      'key': 'rzp_test_7efDroWAFlHu1z', // Replace with your Razorpay key
      'amount': amountInPaise, // amount in paise
      'name': 'RideMatch',
      'description': 'Ride Payment',
      'prefill': {
        'contact': widget.rideData['driverPhone'] ?? '',
        'email': widget.rideData['driverEmail'] ?? '',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print(e.toString());
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 15),

                // Title
                Text(
                  "Ride Booked!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                // Message
                const Text(
                  "Your ride is on the way.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                // Button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );


    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(),
        ),
      );
    });
  }




  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet selected: ${response.walletName}")),
    );
  }

  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Confirm Ride Payment",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _paymentBtn(Icons.account_balance_wallet, "Pay via Razorpay", onTap: () {
              Navigator.pop(context);
              _openRazorpayCheckout();
            }),
            const SizedBox(height: 12),
            _paymentBtn(Icons.money, "Pay with Cash", onTap: () {
              Navigator.pop(context);
              _showRideStartedPopup();
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _paymentBtn(IconData icon, String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff113F67)),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.rideData;
    final car = ride['carDetails'] ?? {'name': 'Car', 'number': 'XXX-000', 'color': 'Black'};
    final driverImage = ride['driverImage'] ??
        'https://www.pngall.com/wp-content/uploads/5/User-Profile-PNG.png';
    final rating = ride['rating'] ?? 4.0;
    final driverName = ride["driverId"]["name"] ?? 'Driver';
    final driverPhone = ride['driverPhone'] ?? '';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: pickup, zoom: 12),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) {
                _mapController = c;
                _prepareMapElements();
              },
              zoomControlsEnabled: false,
              myLocationEnabled: false,
            ),
          ),
          SafeArea(
            child: Container(
              margin: const EdgeInsets.only(left: 12, top: 12),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _bottomDetails(
                ride,
                car,
                driverName,
                driverPhone,
                driverImage,
                rating,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomDetails(
      Map<String, dynamic> ride,
      Map<String, dynamic> car,
      String driverName,
      String driverPhone,
      String driverImage,
      double rating,
      ) {
    // Correct way to get driverId
    final driverId = ride['driverId'] is Map ? ride['driverId']['_id'] : ride['driverId'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              blurRadius: 20, color: Colors.black26.withOpacity(0.2), offset: const Offset(0, -4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 60,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(50)),
            ),
            const SizedBox(height: 20),
            _driverCard(driverName, driverPhone, driverImage, rating),
            const SizedBox(height: 20),
            _tripDetailsSection(
              pickup: ride['from'] ?? "Unknown",
              drop: ride['to'] ?? "Unknown",
              distance: distanceText,
              eta: etaText,
              fare: fareText,
              date: ride['date'],
              time: ride['time'],
              seats: ride['seats'],
            ),
            const SizedBox(height: 15),
            // Use the correctly extracted driverId
            if (driverId != widget.currentUserId)
              ElevatedButton(
                onPressed: _showPaymentSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0A2647),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  "ACCEPT & PAY",
                  style: GoogleFonts.dmSans(
                      fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _driverCard(String name, String phone, String image, double rating) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black12.withOpacity(0.08),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundImage: NetworkImage(image),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff09205f),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchCaller(phone),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text("Call"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff113F67),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Add chat functionality
                        },
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text("Chat"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0A2647),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripDetailsSection({
    required String pickup,
    required String drop,
    required String distance,
    required String eta,
    required String fare,
    String? date,
    String? time,
    int? seats,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xffF4F6FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Trip Details", style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _infoRow(Icons.location_on, "Pickup", pickup),
          const SizedBox(height: 10),
          _infoRow(Icons.flag, "Destination", drop),
          const SizedBox(height: 10),
          _infoRow(Icons.straight, "Distance", distance),
          const SizedBox(height: 10),
          _infoRow(Icons.timer, "Estimated Time", eta),
          const SizedBox(height: 10),
          _infoRow(Icons.currency_rupee, "Fare", fare),
          if (date != null && time != null) ...[
            const SizedBox(height: 10),
            _infoRow(Icons.calendar_month, "Date", date),
            const SizedBox(height: 10),
            _infoRow(Icons.access_time, "Time", time),
          ],
          if (seats != null) ...[
            const SizedBox(height: 10),
            _infoRow(Icons.event_seat, "Seats", seats.toString()),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  void _showRideStartedPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false, // prevent swipe down dismissal
      builder: (_) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car, color: Color(0xff0A2647), size: 28),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Ride Started",
                    style: GoogleFonts.dmSans(
                      color: const Color(0xff0A2647),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Happy Journey!",
                    style: GoogleFonts.dmSans(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    // Close popup after 2 seconds and navigate
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // close popup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
    });
  }





}
