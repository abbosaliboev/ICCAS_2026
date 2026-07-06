import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/fall_event.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl;
  final String edgeUrl;
  final String? token;

  ApiService({required this.baseUrl, required this.edgeUrl, this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Never _timeout() => throw ApiException(0, '서버에 연결할 수 없습니다.\n설정에서 서버 IP를 확인하세요.\n(현재: $baseUrl)');

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response res;
    try {
      res = await http.post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _timeout();
    } on Exception {
      throw ApiException(0, '서버에 연결할 수 없습니다.\n설정에서 서버 IP를 확인하세요.\n(현재: $baseUrl)');
    }
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, data['detail'] ?? '요청 실패');
    }
    return data;
  }

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response res;
    try {
      res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _timeout();
    } on Exception {
      throw ApiException(0, '서버에 연결할 수 없습니다.\n설정에서 서버 IP를 확인하세요.\n(현재: $baseUrl)');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body);
      throw ApiException(res.statusCode, data['detail'] ?? '요청 실패');
    }
    return jsonDecode(res.body);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response res;
    try {
      res = await http.put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _timeout();
    } on Exception {
      throw ApiException(0, '서버에 연결할 수 없습니다.\n설정에서 서버 IP를 확인하세요.\n(현재: $baseUrl)');
    }
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, data['detail'] ?? '요청 실패');
    }
    return data;
  }

  Future<dynamic> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response res;
    try {
      res = await http.delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _timeout();
    } on Exception {
      throw ApiException(0, '서버에 연결할 수 없습니다.\n설정에서 서버 IP를 확인하세요.\n(현재: $baseUrl)');
    }
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body);
      throw ApiException(res.statusCode, data['detail'] ?? '요청 실패');
    }
    return jsonDecode(res.body);
  }

  // ── auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) =>
      _post('/api/auth/login', {'username': username, 'password': password});

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String role,
    String displayName = '',
    int? age,
    String phone = '',
    String address = '',
    int? height,
    int? weight,
    String gender = '',
  }) =>
      _post('/api/auth/register', {
        'username': username,
        'password': password,
        'role': role,
        'display_name': displayName,
        if (age != null) 'age': age,
        'phone': phone,
        'address': address,
        if (height != null) 'height': height,
        if (weight != null) 'weight': weight,
        'gender': gender,
      });

  // ── users ─────────────────────────────────────────────────────────────────

  Future<User> getMe() async {
    final data = await _get('/api/users/me');
    return User.fromJson(data);
  }

  Future<User> updateProfile({
    String displayName = '',
    int? age,
    int? height,
    int? weight,
    String gender = '',
    String phone = '',
    String address = '',
  }) async {
    final data = await _put('/api/users/me', {
      'display_name': displayName,
      if (age != null) 'age': age,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      'gender': gender,
      'phone': phone,
      'address': address,
    });
    return User.fromJson(data);
  }

  Future<void> linkGuardian(String guardianUsername) =>
      _post('/api/users/link-guardian', {'guardian_username': guardianUsername});

  Future<List<User>> getMonitoredUsers() async {
    final data = await _get('/api/users/monitored') as List;
    return data.map((e) => User.fromJson(e)).toList();
  }

  // ── fall events ───────────────────────────────────────────────────────────

  Future<List<FallEvent>> getFallEvents() async {
    final data = await _get('/api/fall-events') as List;
    return data.map((e) => FallEvent.fromJson(e)).toList();
  }

  Future<FallEvent?> getFallEvent(String eventId) async {
    final data = await _get('/api/fall-events/$eventId');
    return data == null ? null : FallEvent.fromJson(data);
  }

  Future<void> acknowledgeEvent(String eventId) =>
      _post('/api/fall-events/$eventId/acknowledge', {});

  Future<void> deleteEvent(String eventId) => _delete('/api/fall-events/$eventId');

  Future<Map<String, dynamic>> getEmergencyReport(String eventId) =>
      _get('/api/fall-events/$eventId/emergency-report') as Future<Map<String, dynamic>>;

  Future<Map<String, dynamic>> notifyGuardianSms(String eventId) =>
      _post('/api/fall-events/$eventId/notify-guardian-sms', {});

  Future<Map<String, dynamic>> notifyEmergencySms(String eventId) =>
      _post('/api/fall-events/$eventId/notify-emergency-sms', {});

  // ── safe zone ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSafeZone() async {
    final data = await _get('/api/safe-zone');
    return (data as Map<String, dynamic>?) ?? {'zones': []};
  }

  Future<void> setSafeZone(List<Map<String, dynamic>> zones) =>
      _post('/api/safe-zone', {'zones': zones});

  Future<void> clearSafeZone() => _delete('/api/safe-zone');

  Future<void> setCameraType(String cameraType) =>
      _post('/api/safe-zone/camera-type', {'camera_type': cameraType});

  // ── stream ────────────────────────────────────────────────────────────────

  String snapshotUrl() => '$baseUrl/api/stream/snapshot';

  String videoUrl(String eventId) =>
      '$baseUrl/api/fall-events/$eventId/video/file?token=$token';

  String screenshotUrl(String eventId) =>
      '$baseUrl/api/fall-events/$eventId/screenshot?token=$token';
}
