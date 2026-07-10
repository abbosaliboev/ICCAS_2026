import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/guard_service.dart';
import '../services/notification_service.dart';
import '../services/ws_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _keyToken = 'token';
  static const _keyBaseUrl = 'base_url';
  static const _keyEdgeUrl = 'edge_url';
  static const _keyOnboardingPending = 'onboarding_pending';
  static const _defaultUrl = 'http://192.168.0.57:8000';
  static const _defaultEdgeUrl = 'http://192.168.0.53:8000';

  String _baseUrl = _defaultUrl;
  String _edgeUrl = _defaultEdgeUrl;
  String? _token;
  User? _user;
  WsService? _ws;
  bool _loading = false;
  bool _onboardingPending = false;

  String get baseUrl => _baseUrl;
  String get edgeUrl => _edgeUrl;
  String? get token => _token;
  User? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;
  bool get loading => _loading;
  bool get onboardingPending => _onboardingPending;
  WsService? get ws => _ws;

  ApiService get api => ApiService(baseUrl: _baseUrl, edgeUrl: _edgeUrl, token: _token);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyBaseUrl) ?? _defaultUrl;
    _edgeUrl = prefs.getString(_keyEdgeUrl) ?? _defaultEdgeUrl;
    _token = prefs.getString(_keyToken);
    _onboardingPending = prefs.getBool(_keyOnboardingPending) ?? false;
    await _persistConnectionSettings(prefs);
    if (_token != null) {
      try {
        _user = await api.getMe();
        _startWs();
      } catch (_) {
        _token = null;
        await prefs.remove(_keyToken);
      }
    }
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = _defaultUrl;
    final prefs = await SharedPreferences.getInstance();
    await _persistConnectionSettings(prefs);
    notifyListeners();
  }

  Future<void> setEdgeUrl(String url) async {
    _edgeUrl = _defaultEdgeUrl;
    final prefs = await SharedPreferences.getInstance();
    await _persistConnectionSettings(prefs);
    notifyListeners();
  }

  Future<void> _persistConnectionSettings([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_keyBaseUrl, _baseUrl);
    await p.setString(_keyEdgeUrl, _edgeUrl);
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await api.login(username, password);
      _token = data['token'];
      _user = User.fromJson(data['user']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, _token!);
      await _persistConnectionSettings(prefs);
      _startWs();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register({
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
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await api.register(
        username: username,
        password: password,
        role: role,
        displayName: displayName,
        age: age,
        phone: phone,
        address: address,
        height: height,
        weight: weight,
        gender: gender,
      );
      _token = data['token'];
      _user = await api.getMe();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, _token!);
      await _persistConnectionSettings(prefs);
      _onboardingPending = true;
      await prefs.setBool(_keyOnboardingPending, true);
      _startWs();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    _onboardingPending = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingPending, false);
    notifyListeners();
  }

  Future<void> logout() async {
    _ws?.dispose();
    _ws = null;
    _token = null;
    _user = null;
    _onboardingPending = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.setBool(_keyOnboardingPending, false);
    await GuardService.stop();
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token == null) return;
    _user = await api.getMe();
    notifyListeners();
  }

  void _startWs() {
    _ws?.dispose();
    _ws = WsService(baseUrl: _baseUrl, token: _token!);
    _ws!.connect();
    _startGuard();
  }

  // Background fall alerts: notification permission + foreground service that
  // keeps its own WebSocket alive when the app UI is gone.
  Future<void> _startGuard() async {
    try {
      await NotificationService.init();
      await NotificationService.requestPermission();
      final prefs = await SharedPreferences.getInstance();
      final korean = (prefs.getString('locale_code') ?? 'ko') == 'ko';
      await GuardService.start(korean: korean);
    } catch (_) {
      // guard service is best-effort — in-app alerts still work without it
    }
  }
}

