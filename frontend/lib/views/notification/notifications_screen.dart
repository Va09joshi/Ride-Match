import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridematch/services/API.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    if (userId != null) {
      await _fetchNotifications();
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _fetchNotifications() async {
    if (userId == null) return;

    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final url = Uri.parse("$baseurl/api/notifications/$userId");

    try {
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<dynamic> list = data['notifications'] ??
            data['notification'] ??
            data['data'] ??
            [];

        setState(() {
          notifications = List<Map<String, dynamic>>.from(list);
          loading = false;
        });
      } else {
        setState(() {
          notifications = [];
          loading = false;
        });
      }
    } catch (e) {
      print("ERROR fetching notifications → $e");
      setState(() {
        notifications = [];
        loading = false;
      });
    }
  }

  String timeAgo(String isoString) {
    try {
      final time = DateTime.parse(isoString);
      final diff = DateTime.now().difference(time);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
      if (diff.inHours < 24) return "${diff.inHours} hrs ago";
      return "${diff.inDays} days ago";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xff113F67),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 6,
        itemBuilder: (_, __) => _buildShimmerItem(),
      )
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: notifications.isEmpty
            ? Center(
          child: Text(
            "No Notifications",
            style: GoogleFonts.dmSans(fontSize: 16),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final item = notifications[index];

            // Safely handle sender
            final sender = item["senderId"];
            final senderName = (sender is Map)
                ? sender["name"] ?? "Someone"
                : "Someone";
            final senderImage = (sender is Map)
                ? sender["profileImage"] ?? ""
                : "";

            return _buildNotificationItem(
              image: senderImage,
              name: senderName,
              type: item["type"] ?? "info",
              time: item["createdAt"] != null
                  ? timeAgo(item["createdAt"])
                  : "",
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String image,
    required String name,
    required String type,
    required String time,
  }) {
    String message;

    switch (type) {
      case "like":
        message = "$name liked your request post ❤️";
        break;
      case "comment":
        message = "$name commented on your request post 💬";
        break;
      default:
        message = "$name sent you a notification.";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: image.isNotEmpty
                ? NetworkImage(image)
                : const NetworkImage(
                "https://www.pngall.com/wp-content/uploads/5/User-Profile-PNG.png"),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "New Notification",
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: const CircleAvatar(radius: 24, backgroundColor: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(height: 14, width: 120, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(height: 12, width: double.infinity, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(height: 10, width: 80, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

}
