import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatService {
  late IO.Socket socket;
  final String userId;

  ChatService(this.userId) {
    initSocket();
  }

  void initSocket() {
    socket = IO.io('http://192.168.29.206:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to WebSocket');
      socket.emit('register', userId);
    });

    socket.on('receiveMessage', (data) {
      print("📩 Message received: ${data['message']} from ${data['senderId']}");
      // You can add logic to display in UI or save in local database
    });
  }

  void sendMessage(String receiverId, String message) {
    socket.emit('sendMessage', {
      'senderId': userId,
      'receiverId': receiverId,
      'message': message,
    });
  }

  void dispose() {
    socket.disconnect();
  }
}
