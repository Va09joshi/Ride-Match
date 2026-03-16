import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';

/// Singleton notification service.
///
/// Usage:
///   NotificationService.instance.onNewNotification = (notif) { ... };
///   await NotificationService.instance.connect();
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  IO.Socket? _socket;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _userId;
  bool _audioReady = false;

  // Reactive unread count — listen to this stream
  final StreamController<int> _unreadController =
      StreamController<int>.broadcast();
  Stream<int> get unreadStream => _unreadController.stream;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // Latest notification for in-app overlay (null when none pending)
  final StreamController<Map<String, dynamic>> _notifController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream =>
      _notifController.stream;

  // -------------------------------------------------------
  // Connect / Disconnect
  // -------------------------------------------------------

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId == null) return;

    // Fetch current unread count from REST
    await refreshUnreadCount();
    await _prepareAudio();

    // Open Socket.IO connection
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      AppApi.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('register', _userId);
    });

    _socket!.on('new_notification', (data) {
      _handleIncoming(data is String ? jsonDecode(data) : data as Map);
    });

    _socket!.onDisconnect((_) {});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // -------------------------------------------------------
  // Incoming notification handling
  // -------------------------------------------------------

  void _handleIncoming(Map<dynamic, dynamic> raw) {
    final notif = Map<String, dynamic>.from(raw);
    _unreadCount += 1;
    _unreadController.add(_unreadCount);
    _notifController.add(notif);
    _playSound();
  }

  // -------------------------------------------------------
  // Sound
  // -------------------------------------------------------

  Future<void> _playSound() async {
    try {
      if (!_audioReady) {
        await _prepareAudio();
      }
      // Try the bundled asset first; falls back silently if not found
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {
      // Fallback for devices where media playback is blocked.
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _prepareAudio() async {
    if (_audioReady) return;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      _audioReady = true;
    } catch (_) {
      _audioReady = false;
    }
  }

  // -------------------------------------------------------
  // REST helpers
  // -------------------------------------------------------

  Future<void> refreshUnreadCount() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await http.get(
        AppApi.uri(AppEndpoints.notificationsUnreadCount(_userId!)),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _unreadCount = (data['count'] ?? 0) as int;
        _unreadController.add(_unreadCount);
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await http.put(
        AppApi.uri(AppEndpoints.notificationsMarkAllRead(_userId!)),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      _unreadCount = 0;
      _unreadController.add(0);
    } catch (_) {}
  }

  Future<void> markRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await http.put(
        AppApi.uri(AppEndpoints.notificationMarkRead(notificationId)),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
  }

  void dispose() {
    disconnect();
    _unreadController.close();
    _notifController.close();
    _audioPlayer.dispose();
  }
}

// -------------------------------------------------------
// In-app notification overlay widget
// -------------------------------------------------------

/// Wraps a child widget and shows a slide-in banner at the top of the screen
/// whenever a new notification arrives via [NotificationService].
class NotificationOverlayWrapper extends StatefulWidget {
  final Widget child;
  const NotificationOverlayWrapper({super.key, required this.child});

  @override
  State<NotificationOverlayWrapper> createState() =>
      _NotificationOverlayWrapperState();
}

class _NotificationOverlayWrapperState extends State<NotificationOverlayWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;

  StreamSubscription<Map<String, dynamic>>? _sub;
  Map<String, dynamic>? _pending;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _sub = NotificationService.instance.notificationStream.listen((notif) {
      if (!mounted) return;
      setState(() => _pending = notif);
      _animController.forward(from: 0);

      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        _animController.reverse().then((_) {
          if (mounted) setState(() => _pending = null);
        });
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _notifIcon(String? type) {
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
      default:
        return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_pending != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideAnim,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    _animController.reverse().then((_) {
                      if (mounted) setState(() => _pending = null);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff113F67),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          _notifIcon(_pending?['type'] as String?),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (_pending?['message'] as String?) ??
                                'You have a new notification',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
