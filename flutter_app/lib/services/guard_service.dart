import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'notification_service.dart';

/// Keeps a WebSocket to the backend alive in an Android foreground service so
/// fall alerts arrive even when the app is minimized, backgrounded, or swiped
/// away. The service isolate owns its OWN connection — independent of the
/// in-app WsService, which dies with the UI.
class GuardService {
  static bool _inited = false;

  static void init() {
    if (_inited) return;
    _inited = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mobicare_guard',
        channelName: 'MobiCare protection',
        channelDescription: 'Keeps fall monitoring active in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start({required bool korean}) async {
    init();
    // MIUI & friends kill background work aggressively — ask once for the
    // battery exemption so the guard service survives.
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: korean ? 'MobiCare 보호 작동 중' : 'MobiCare protection active',
      notificationText: korean ? '낙상 알림을 기다리고 있습니다' : 'Listening for fall alerts',
      callback: guardTaskEntry,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

@pragma('vm:entry-point')
void guardTaskEntry() {
  FlutterForegroundTask.setTaskHandler(_GuardTaskHandler());
}

class _GuardTaskHandler extends TaskHandler {
  WebSocketChannel? _channel;
  Timer? _ping;
  Timer? _reconnect;
  bool _connected = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await NotificationService.init();
    await _connect();
  }

  Future<void> _connect() async {
    _reconnect?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // pick up token/url changes from the UI isolate
      final base = prefs.getString('base_url') ?? 'http://192.168.0.57:8000';
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        _scheduleReconnect();
        return;
      }
      final wsUrl = base
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws?token=$token'));
      _channel!.stream.listen(
        (msg) async {
          _connected = true;
          if (msg == 'pong') return;
          try {
            final j = jsonDecode(msg.toString()) as Map<String, dynamic>;
            if (j['type'] == 'fall_detected') {
              await prefs.reload();
              final demoTtsSttEnabled =
                  prefs.getBool('demo_tts_stt_enabled') ?? false;
              if (demoTtsSttEnabled) return;
              final ko = (prefs.getString('locale_code') ?? 'ko') == 'ko';
              await NotificationService.showFallAlert(
                eventId: (j['event_id'] ?? '') as String,
                korean: ko,
                who: j['monitored_user_name'] as String?,
              );
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 30), (_) {
        _channel?.sink.add('ping');
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _connected = false;
    _ping?.cancel();
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), _connect);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 60s heartbeat: if the socket silently died (WiFi roam, backend restart)
    // force a reconnect cycle.
    if (!_connected) _connect();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _ping?.cancel();
    _reconnect?.cancel();
    _channel?.sink.close();
  }
}



