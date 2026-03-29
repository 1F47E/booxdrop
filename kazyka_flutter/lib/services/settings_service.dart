import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _kName = 'artist_name';
  static const _kCanvasSize = 'canvas_size';
  static const canvasSizeOptions = [1024, 2048, 4096];

  String _name = '';
  int _defaultCanvasSize = 2048;

  String get name => _name;
  int get defaultCanvasSize => _defaultCanvasSize;

  SettingsService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString(_kName) ?? '';
    _defaultCanvasSize = prefs.getInt(_kCanvasSize) ?? 2048;
    notifyListeners();
  }

  Future<void> setName(String value) async {
    _name = value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, _name);
  }

  Future<void> setDefaultCanvasSize(int value) async {
    _defaultCanvasSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCanvasSize, value);
  }
}
