import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// High-priority local notifications for guardian fall alerts.
class NotificationService {
  static const _channelId = 'fall_alerts';
  static const actionEmergency = 'fall_emergency';
  static const actionOk = 'fall_ok';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  /// Safe to call from both the UI isolate and the foreground-service isolate.
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _handleAction,
      onDidReceiveBackgroundNotificationResponse: notificationActionHandler,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Fall alerts',
          description: 'Immediate alerts when a fall is detected',
          importance: Importance.max,
        ));
  }

  /// Ask for POST_NOTIFICATIONS (no-op below Android 13). UI isolate only.
  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _handleAction(NotificationResponse r) {
    notificationActionHandler(r);
  }

  static Future<void> showFallAlert({
    required String eventId,
    required bool korean,
    String? who,
  }) async {
    await init();
    final title = korean ? '낙상 감지' : 'Fall Detected';
    final body = who != null && who.isNotEmpty
        ? (korean ? '$who님의 낙상이 감지되었습니다' : '$who fall detected')
        : (korean ? '낙상이 감지되었습니다' : 'Fall detected');

    final details = AndroidNotificationDetails(
      _channelId,
      'Fall alerts',
      channelDescription: 'Immediate alerts when a fall is detected',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      autoCancel: true,
    );

    await _plugin.show(
      eventId.hashCode,
      title,
      body,
      NotificationDetails(android: details),
      payload: eventId,
    );
  }
}

/// Runs in a background isolate when an action button is tapped while the app
/// is not in the foreground — talks to the backend directly over HTTP using
/// the credentials persisted by AuthProvider.
@pragma('vm:entry-point')
Future<void> notificationActionHandler(NotificationResponse r) async {
  final eventId = r.payload;
  if (eventId == null || eventId.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final base = prefs.getString('base_url') ?? 'http://192.168.0.57:8000';
  final token = prefs.getString('token');
  if (token == null || token.isEmpty) return;
  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  try {
    if (r.actionId == NotificationService.actionEmergency) {
      await http.post(
          Uri.parse('$base/api/fall-events/$eventId/notify-guardian-sms'),
          headers: headers);
      await http.post(
          Uri.parse('$base/api/fall-events/$eventId/notify-emergency-sms'),
          headers: headers);
    } else if (r.actionId == NotificationService.actionOk) {
      await http.post(Uri.parse('$base/api/fall-events/$eventId/acknowledge'),
          headers: headers);
    }
  } catch (_) {
    // network failure — nothing actionable from a background isolate
  }
}
