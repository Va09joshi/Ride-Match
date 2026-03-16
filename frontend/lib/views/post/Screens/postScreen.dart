import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/views/chats/SocketScreenchat.dart';
import 'package:ridematch/views/chats/chatHistory/chathistoryScreen.dart';
import 'package:shimmer/shimmer.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  String? senderId;
  List<Map<String, dynamic>> myRequests = [];
  List<Map<String, dynamic>> otherRequests = [];
  bool _loading = true;
  Map<String, String> decisionStatus =
      {}; // requestId : accepted | rejected | pending
  Set<String> rejectedLocally = {}; // permanently hidden
  Map<String, bool> liked = {};

  @override
  void initState() {
    super.initState();
    _loadSenderId();
  }

  Future<void> _loadSenderId() async {
    final prefs = await SharedPreferences.getInstance();
    senderId = prefs.getString('userId');
    rejectedLocally = prefs.getStringList('rejectedRequests')?.toSet() ?? {};
    await _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      List<Map<String, dynamic>> myReqList = [];
      List<Map<String, dynamic>> others = [];

      if (senderId != null) {
        final myResp = await http.get(
          AppApi.uri(AppEndpoints.rideRequestsByUser(senderId!)),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        if (myResp.statusCode == 200) {
          final data = jsonDecode(myResp.body);
          myReqList = List<Map<String, dynamic>>.from(data['requests']);
          for (var req in myReqList) {
            final likedBy = req['likedBy'] ?? [];
            liked[req['_id']] = likedBy.contains(senderId);
          }
        }

        double latitude = 22.97882;
        double longitude = 76.06698;

        final nearbyResp = await http.get(
          AppApi.uri(
            AppEndpoints.rideRequestsNearby,
            queryParameters: {'longitude': longitude, 'latitude': latitude},
          ),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        if (nearbyResp.statusCode == 200) {
          final data = jsonDecode(nearbyResp.body);
          others = List<Map<String, dynamic>>.from(data['requests']);

          for (var req in others) {
            final likedBy = req['likedBy'] ?? [];
            liked[req['_id']] = likedBy.contains(senderId);
          }

          others.removeWhere((req) {
            final uid = req['userId'] is Map
                ? req['userId']['_id']
                : req['userId'];
            return uid == senderId || rejectedLocally.contains(req['_id']);
          });

          for (var req in others) {
            decisionStatus[req['_id']] = "pending";
          }
        }
      }

      if (mounted) {
        setState(() {
          myRequests = myReqList;
          otherRequests = others;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          myRequests = [];
          otherRequests = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _respondToRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final requestId = request['_id'];
    final receiver = request['userId'] is Map
        ? request['userId']['_id']
        : request['userId'];

    // Disable button immediately
    setState(() {
      decisionStatus[requestId] = status;
    });

    if (status == "rejected") {
      rejectedLocally.add(requestId);
      prefs.setStringList('rejectedRequests', rejectedLocally.toList());
      setState(() {
        otherRequests.removeWhere((r) => r['_id'] == requestId);
      });
    }

    if (status == "accepted" && mounted) {
      // ⚡ Optimistic UI: force accepted
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            senderId: senderId!,
            receiverId: receiver,
            initialPermissionStatus: ChatPermissionStatus.accepted, // pass this
          ),
        ),
      );

      final autoMessage =
          "Hi, I'm interested in your ride from ${request['from']} to ${request['to']}.";
      _sendAutoIntroMessage(receiver, autoMessage);
    }

    // Make API call in background
    final rideId = request['rideId'] ?? request['_id'];
    final url = AppApi.uri(AppEndpoints.rideRespond(rideId.toString()));

    try {
      String? token = prefs.getString('token');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"userId": senderId, "status": status}),
      );
    } catch (e) {
      debugPrint("Respond API error: $e");
    }
  }

  Future<String?> _sendAutoIntroMessage(
    String receiverId,
    String autoMessage,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final url = AppApi.uri(AppEndpoints.messageSend);

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "senderId": senderId,
          "receiverId": receiverId,
          "message": autoMessage,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data']?['_id']?.toString();
      } else {
        debugPrint("Auto intro failed: ${res.body}");
      }
    } catch (e) {
      debugPrint("Auto intro error: $e");
    }
    return null;
  }

  Future<void> _sendLikeNotification(
    String receiverId,
    String requestId,
    bool isLiked,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    final url = AppApi.uri(AppEndpoints.notificationsLike);

    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "senderId": senderId,
          "receiverId": receiverId,
          "requestId": requestId,
          "type": isLiked ? "like" : "unlike",
        }),
      );
    } catch (e) {
      setState(() => liked[requestId] = !isLiked);
    }
  }

  String _getUserProfileImage(dynamic user) {
    if (user is Map && user['profileImage']?.toString().isNotEmpty == true) {
      return user['profileImage'];
    }
    return AppConstant.defaultProfileImage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xff113F67),
        title: Text(
          "Posts",
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? _buildShimmerFeed()
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: _buildRequestList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (senderId == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatHistoryScreen(userId: senderId!),
            ),
          );
        },
        backgroundColor: const Color(0xff113F67),
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildShimmerFeed() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 28, backgroundColor: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 14, color: Colors.white)),
                const SizedBox(width: 12),
                const Icon(Icons.favorite_border, color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 60, width: double.infinity, color: Colors.white),
            const SizedBox(height: 12),
            Container(height: 14, width: double.infinity, color: Colors.white),
            const SizedBox(height: 16),
            Container(height: 40, width: double.infinity, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (myRequests.isNotEmpty)
          Text(
            "Your Requests",
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ...myRequests.map(_buildMyRequestCard),
        const SizedBox(height: 10),
        Text(
          "Nearby Requests",
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        ...otherRequests.map(_buildRequestCard),
      ],
    );
  }

  Widget _buildMyRequestCard(Map<String, dynamic> req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "${req['from']} → ${req['to']}  •  ${req['date']}",
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            "Your Post",
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final user = request['userId'];
    final userId = user is Map ? user['_id'] : user;
    final userName = user is Map ? user['name'] : 'Unknown';
    final userImage = _getUserProfileImage(user);
    final requestId = request['_id'];
    liked.putIfAbsent(requestId, () => false);
    // Persist liked state locally
    Future<void> _persistLike(String reqId) async {
      final prefs = await SharedPreferences.getInstance();
      final likedList = prefs.getStringList('likedRequests') ?? [];
      if (!likedList.contains(reqId)) {
        likedList.add(reqId);
        await prefs.setStringList('likedRequests', likedList);
      }
    }

    Future<bool> _isLikedPersisted(String reqId) async {
      final prefs = await SharedPreferences.getInstance();
      final likedList = prefs.getStringList('likedRequests') ?? [];
      return likedList.contains(reqId);
    }

    return FutureBuilder<bool>(
      future: _isLikedPersisted(requestId),
      builder: (context, snapshot) {
        final isLikedPersisted = snapshot.data ?? liked[requestId]!;
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(userImage),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        "${request['date']} • ${request['time']}",
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: isLikedPersisted
                        ? null
                        : () async {
                            setState(() => liked[requestId] = true);
                            await _sendLikeNotification(
                              userId,
                              requestId,
                              true,
                            );
                            await _persistLike(requestId);
                          },
                    child: Icon(
                      (isLikedPersisted || liked[requestId]!)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: (isLikedPersisted || liked[requestId]!)
                          ? Colors.red
                          : Colors.grey,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _locationBox(request),
              const SizedBox(height: 10),
              Text(
                request['note'] ?? '',
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              // Modern UI divider
              Divider(color: Colors.grey.shade300, thickness: 1),
              // 🔹 CHAT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff113F67),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (senderId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(senderId: senderId!, receiverId: userId),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                  ),
                  label: Text(
                    "Chat",
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 🔹 ACCEPT / REJECT BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: decisionStatus[requestId] == "pending"
                          ? () => _respondToRequest(request, "rejected")
                          : null,
                      child: Text(
                        "Reject",
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: decisionStatus[requestId] == "pending"
                          ? () => _respondToRequest(request, "accepted")
                          : null,
                      child: Text(
                        "Accept",
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _locationBox(Map<String, dynamic> req) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff113F67).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xff113F67)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  req["from"] ?? "",
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag, color: Color(0xff113F67)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  req["to"] ?? "",
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
