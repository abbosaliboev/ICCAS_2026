import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsEvent {
  final String type;
  final String eventId;
  final String category;
  final String timestamp;
  final String? monitoredUserName;

  WsEvent({
    required this.type,
    required this.eventId,
    required this.category,
    required this.timestamp,
    this.monitoredUserName,
  });

  factory WsEvent.fromJson(Map<String, dynamic> j) => WsEvent(
        type: j['type'] ?? '',
        eventId: j['event_id'] ?? '',
        category: j['category'] ?? 'severe',
        timestamp: j['timestamp'] ?? '',
        monitoredUserName: j['monitored_user_name'],
      );

  bool get isFallDetected => type == 'fall_detected';
  bool get isFallResolved => type == 'fall_resolved';
}

class WsService {
  WebSocketChannel? _channel;
  StreamController<WsEvent>? _controller;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final String baseUrl;
  final String token;

  WsService({required this.baseUrl, required this.token});

  Stream<WsEvent> get events => _controller!.stream;

  void connect() {
    _controller ??= StreamController<WsEvent>.broadcast();
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws?token=$token'));
    _channel!.stream.listen(
      (msg) {
        if (msg == 'pong') return;
        try {
          final data = jsonDecode(msg.toString());
          _controller!.add(WsEvent.fromJson(data));
        } catch (_) {}
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _channel?.sink.add('ping');
    });
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
  }
}
