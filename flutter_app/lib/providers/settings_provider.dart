import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyLang       = 'locale_code';
  static const _keyCamType    = 'cam_type';
  static const _keyContactName  = 'contact_name';
  static const _keyContactPhone = 'contact_phone';

  String _localeCode   = 'ko';
  String _cameraType   = 'front';
  String _contactName  = '';
  String _contactPhone = '';

  int _zonesVersion = 0;

  String get localeCode   => _localeCode;
  String get cameraType   => _cameraType;
  String get contactName  => _contactName;
  String get contactPhone => _contactPhone;
  int get zonesVersion => _zonesVersion;

  void bumpZonesVersion() {
    _zonesVersion++;
    notifyListeners();
  }

  Locale get locale => Locale(_localeCode);

  // Supported languages
  static const languages = [
    {'code': 'ko', 'label': '한국어'},
    {'code': 'en', 'label': 'English'},
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _localeCode   = prefs.getString(_keyLang)         ?? 'ko';
    _cameraType   = prefs.getString(_keyCamType)      ?? 'front';
    _contactName  = prefs.getString(_keyContactName)  ?? '';
    _contactPhone = prefs.getString(_keyContactPhone) ?? '';
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    _localeCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLang, code);
    notifyListeners();
  }

  Future<void> setCameraType(String type) async {
    _cameraType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCamType, type);
    notifyListeners();
  }

  Future<void> setContact(String name, String phone) async {
    _contactName  = name;
    _contactPhone = phone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyContactName, name);
    await prefs.setString(_keyContactPhone, phone);
    notifyListeners();
  }
}
