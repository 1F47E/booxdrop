import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kKidsMode = 'settings_kids_mode';
  static const _kKidsAge = 'settings_kids_age';

  bool _kidsMode = false;
  int _kidsAge = 7;

  bool get kidsMode => _kidsMode;
  int get kidsAge => _kidsAge;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _kidsMode = prefs.getBool(_kKidsMode) ?? false;
    _kidsAge = prefs.getInt(_kKidsAge) ?? 7;
    notifyListeners();
  }

  Future<void> setKidsMode(bool value) async {
    _kidsMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKidsMode, value);
  }

  Future<void> setKidsAge(int age) async {
    _kidsAge = age.clamp(3, 12);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKidsAge, _kidsAge);
  }
}
