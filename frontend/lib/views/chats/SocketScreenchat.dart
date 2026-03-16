import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';

enum ChatPermissionStatus { checking, pending, accepted, rejected }

class ChatScreen extends StatefulWidget {
  final String senderId;
  final String receiverId;
  final ChatPermissionStatus? initialPermissionStatus;

  const ChatScreen({
    super.key,
    required this.senderId,
    required this.receiverId,
    this.initialPermissionStatus,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  IO.Socket? socket;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  String receiverName = "Person";
  String receiverAvatar = AppConstant.defaultChatAvatar;
  String receiverPhone = '';

  ChatPermissionStatus permissionStatus = ChatPermissionStatus.checking;
  bool get canChat => permissionStatus == ChatPermissionStatus.accepted;

  String? token;
  bool socketConnected = false;

  bool _loadingMessages = true;
  bool _loadingReceiver = true;

  @override
  void initState() {
    super.initState();
    permissionStatus =
        widget.initialPermissionStatus ?? ChatPermissionStatus.checking;
    initChat();
  }

  Future<void> initChat() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    await fetchReceiverInfo();
    await checkChatPermission();
    await fetchMessages();
  }

  Future<void> checkChatPermission() async {
    try {
      final url = AppApi.uri(
        AppEndpoints.chatPermission(widget.senderId, widget.receiverId),
      );

      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final status = (data['status'] ?? '').toString().toLowerCase();

        setState(() {
          permissionStatus = status == "accepted"
              ? ChatPermissionStatus.accepted
              : status == "rejected"
              ? ChatPermissionStatus.rejected
              : ChatPermissionStatus.pending;
        });

        if (status == "accepted" && !socketConnected) {
          connectSocket();
        }
      } else {
        setState(() => permissionStatus = ChatPermissionStatus.pending);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => permissionStatus = ChatPermissionStatus.pending);
    }
  }

  void connectSocket() {
    if (socketConnected) return;

    socket = IO.io(
      AppApi.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      socketConnected = true;
      socket!.emit('register', widget.senderId);
    });

    socket!.on('receiveMessage', (data) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'senderId': data['senderId'],
          'message': data['message'],
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        });
      });

      _scrollToBottom();
    });

    socket!.on('chatPermissionUpdated', (data) {
      if (!mounted) return;

      if (data['senderId'] == widget.senderId &&
          data['receiverId'] == widget.receiverId) {
        final status = (data['status'] ?? '').toString().toLowerCase();
        setState(() {
          permissionStatus = status == "accepted"
              ? ChatPermissionStatus.accepted
              : status == "rejected"
              ? ChatPermissionStatus.rejected
              : ChatPermissionStatus.pending;
        });

        if (status == "accepted" && !socketConnected) connectSocket();
        if (status == "rejected") socket?.disconnect();
      }
    });
  }

  Future<void> fetchReceiverInfo() async {
    setState(() => _loadingReceiver = true);
    try {
      final url = AppApi.uri(AppEndpoints.userById(widget.receiverId));
      final res = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          receiverName = data['name'] ?? "User";
          receiverAvatar =
              data['profileImage'] ?? AppConstant.defaultChatAvatar;
          receiverPhone = (data['phone'] ?? '').toString();
        });
      }
    } catch (_) {}
    setState(() => _loadingReceiver = false);
  }

  Future<void> fetchMessages() async {
    setState(() => _loadingMessages = true);
    try {
      final url = AppApi.uri(
        AppEndpoints.messages(widget.senderId, widget.receiverId),
      );

      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          messages = List<Map<String, dynamic>>.from(
            data.map(
              (m) => {
                'senderId': m['senderId'],
                'receiverId': m['receiverId'],
                'message': m['message'],
                'timestamp': m['createdAt'] ?? DateTime.now().toIso8601String(),
                'senderName': m['senderName'] ?? 'User',
                'receiverName': m['receiverName'] ?? 'User',
              },
            ),
          );
        });

        _scrollToBottom();
      }
    } catch (_) {}
    setState(() => _loadingMessages = false);
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (!canChat || text.isEmpty) return;

    // Clear input immediately for smooth typing
    _controller.clear();
    _scrollToBottom();

    final url = AppApi.uri(AppEndpoints.messageSend);
    final body = jsonEncode({
      'senderId': widget.senderId,
      'receiverId': widget.receiverId,
      'message': text,
      'type': 'text',
    });

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newMsg = data['data'];

        if (!mounted) return;
        setState(() {
          messages.add({
            'senderId': newMsg['senderId'],
            'receiverId': newMsg['receiverId'],
            'message': newMsg['message'],
            'timestamp':
                newMsg['createdAt'] ?? DateTime.now().toIso8601String(),
            'senderName': newMsg['senderName'] ?? 'You',
            'receiverName': newMsg['receiverName'] ?? 'User',
          });
        });

        _scrollToBottom();
      } else {
        print("Failed to send message: ${res.body}");
      }
    } catch (e) {
      print("Send message error: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xff113F67),
        title: _loadingReceiver
            ? _buildShimmerReceiver()
            : _buildReceiverInfo(),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: receiverPhone.isEmpty
                ? null
                : () async {
                    final uri = Uri(scheme: 'tel', path: receiverPhone);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
          ),
        ],
      ),
      body: permissionStatus == ChatPermissionStatus.checking
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!canChat) _buildPermissionBanner(),
                Expanded(
                  child: _loadingMessages
                      ? _buildShimmerMessages()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final msg = messages[i];
                            final isMe = msg['senderId'] == widget.senderId;
                            return _buildMessage(msg, isMe, key: ValueKey(i));
                          },
                        ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildShimmerReceiver() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Row(
        children: [
          const CircleAvatar(radius: 18, backgroundColor: Colors.white),
          const SizedBox(width: 10),
          Container(height: 16, width: 120, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildShimmerMessages() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Align(
            alignment: __ % 2 == 0
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiverInfo() {
    return Row(
      children: [
        CircleAvatar(backgroundImage: NetworkImage(receiverAvatar)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            receiverName,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionBanner() {
    final rejected = permissionStatus == ChatPermissionStatus.rejected;
    return Container(
      width: double.infinity,
      color: rejected ? Colors.red.shade100 : Colors.orange.shade100,
      padding: const EdgeInsets.all(12),
      child: Text(
        rejected
            ? "Ride request rejected. Chat disabled."
            : "Chat will unlock after ride acceptance.",
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          color: rejected ? Colors.red.shade900 : Colors.orange.shade900,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, bool isMe, {Key? key}) {
    DateTime time;
    try {
      final timestamp =
          msg['timestamp'] ??
          msg['createdAt'] ??
          DateTime.now().toIso8601String();
      time = DateTime.parse(timestamp).toLocal();
    } catch (_) {
      time = DateTime.now();
    }

    final formattedTime =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

    return Align(
      key: key,
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xff113F67), Color(0xff15518A)],
                )
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg['message'] ?? '',
              style: GoogleFonts.dmSans(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedTime,
              style: GoogleFonts.dmSans(
                color: isMe ? Colors.white70 : Colors.black45,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    // Enable as soon as permission is accepted, regardless of loading
    final enabled = canChat;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (enabled) sendMessage();
              },
              decoration: InputDecoration(
                hintText: enabled
                    ? "Type a message..."
                    : permissionStatus == ChatPermissionStatus.accepted
                    ? "Chat disabled"
                    : "Waiting for acceptance...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: enabled ? sendMessage : null,
            backgroundColor: enabled ? const Color(0xff113F67) : Colors.grey,
            mini: true,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
