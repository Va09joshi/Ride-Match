import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ridematch/views/chats/SocketScreenchat.dart';

class ChatHistoryScreen extends StatefulWidget {
  final String userId;

  const ChatHistoryScreen({super.key, required this.userId});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<Map<String, dynamic>> chatList = [];
  bool isLoading = true;

  String _formatTime(dynamic rawTime) {
    if (rawTime == null || rawTime.toString().isEmpty) return "";
    try {
      final dt = DateTime.parse(rawTime.toString()).toLocal();
      final now = DateTime.now();
      final isToday =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
      if (isToday) {
        final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final m = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $period';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return "";
    }
  }

  @override
  void initState() {
    super.initState();
    fetchChatHistory();
  }

  Future<void> fetchChatHistory() async {
    final url = AppApi.uri(AppEndpoints.chatHistory(widget.userId));
    try {
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        chatList = data.map((chat) {
          return {
            "chatId": chat["_id"],
            "name": chat["receiverName"] ?? "Unknown",
            "lastMessage": chat["lastMessage"] ?? "Start conversation",
            "time": _formatTime(chat["lastMessageTime"]),
            "unread": chat["unreadCount"] ?? 0,
            "profile": chat["receiverProfile"] ?? AppConstant.defaultChatAvatar,
            "receiverId": chat["receiverId"],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching chat history: $e");
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Chats",
          style: GoogleFonts.poppins(
            color: const Color(0xff09205f),
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        actions: const [
          Icon(Icons.search_rounded, color: Color(0xff09205f)),
          SizedBox(width: 12),
          Icon(Icons.more_vert_rounded, color: Color(0xff09205f)),
          SizedBox(width: 12),
        ],
      ),
      body: isLoading
          ? _buildShimmerList()
          : chatList.isEmpty
          ? const Center(
              child: Text(
                "No chats available",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: chatList.length,
              itemBuilder: (context, index) {
                final chat = chatList[index];
                return _chatTile(chat);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xff09205f),
        child: const Icon(Icons.message_rounded, color: Colors.white),
      ),
    );
  }

  Widget _chatTile(Map<String, dynamic> chat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xffE8EEF9),
              child: ClipOval(
                child: Image.network(
                  chat["profile"],
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    color: Color(0xff09205f),
                    size: 26,
                  ),
                ),
              ),
            ),
            if (chat["unread"] > 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          chat["name"],
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xff09205f),
          ),
        ),
        subtitle: Text(
          chat["lastMessage"],
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if ((chat["time"] ?? '').toString().isNotEmpty)
              Text(
                chat["time"],
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            if (chat["unread"] > 0)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff09205f),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  chat["unread"].toString(),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                senderId: widget.userId,
                receiverId: chat["receiverId"],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 🔹 Shimmer Loading List
  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 120, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
