import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:ridematch/services/notification_service.dart';

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

    final url = AppApi.uri(AppEndpoints.notifications(userId!));

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
        List<dynamic> list =
            data['notifications'] ?? data['notification'] ?? data['data'] ?? [];

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

  Future<void> _markRead(String notificationId, int index) async {
    if (notificationId.isEmpty) return;
    if (index < 0 || index >= notifications.length) return;
    if (notifications[index]['isRead'] == true) return;

    await NotificationService.instance.markRead(notificationId);
    if (!mounted) return;
    setState(() {
      notifications[index] = {...notifications[index], 'isRead': true};
    });
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
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No Notifications",
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final isRead = item['isRead'] == true;
                        final notifId = (item['_id'] ?? '').toString();

                        final sender = item["senderId"];
                        final senderName = (sender is Map)
                            ? (sender["name"] ?? "Someone").toString()
                            : "Someone";
                        final senderImage = (sender is Map)
                            ? (sender["profileImage"] ?? "").toString()
                            : "";

                        return GestureDetector(
                          onTap: () => _markRead(notifId, index),
                          child: _buildNotificationItem(
                            image: senderImage,
                            name: senderName,
                            type: (item["type"] ?? "info").toString(),
                            message: (item["message"] ?? "").toString(),
                            time: item["createdAt"] != null
                                ? timeAgo(item["createdAt"].toString())
                                : "",
                            isRead: isRead,
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _notifIcon(String type) {
    switch (type) {
      case 'ride_created':
        return '🚗';
      case 'ride_booked':
        return '✅';
      case 'ride_cancelled':
        return '❌';
      case 'ride_request_accepted':
        return '🎉';
      case 'ride_request_declined':
        return '😔';
      case 'message_received':
        return '💬';
      case 'like':
        return '❤️';
      default:
        return '🔔';
    }
  }

  String _notifTitle(String type) {
    switch (type) {
      case 'ride_created':
        return 'Ride Posted';
      case 'ride_booked':
        return 'Booking Update';
      case 'ride_cancelled':
        return 'Ride Cancelled';
      case 'ride_request_accepted':
        return 'Request Accepted';
      case 'ride_request_declined':
        return 'Request Declined';
      case 'message_received':
        return 'New Message';
      case 'like':
        return 'New Like';
      default:
        return 'Notification';
    }
  }

  Widget _buildNotificationItem({
    required String image,
    required String name,
    required String type,
    required String message,
    required String time,
    required bool isRead,
  }) {
    final displayMessage = message.isNotEmpty
        ? message
        : '$name sent you a notification.';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xffEAF1FB),
        borderRadius: BorderRadius.circular(16),
        border: isRead
            ? null
            : Border.all(color: const Color(0xff4A70A9).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon bubble
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xff113F67).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(_notifIcon(type), style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _notifTitle(type),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff113F67),
                      ),
                    ),
                    const Spacer(),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  displayMessage,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  time,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
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
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
            ),
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
                  child: Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(height: 10, width: 80, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
