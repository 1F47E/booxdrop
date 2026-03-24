import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _kName = 'artist_name';

  String _name = '';

  String get name => _name;

  SettingsService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString(_kName) ?? '';
    notifyListeners();
  }

  Future<void> setName(String value) async {
    _name = value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, _name);
  }
}
