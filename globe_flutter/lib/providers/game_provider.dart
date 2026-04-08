import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest.dart';
import '../data/countries.dart' as country_data;
import '../data/capitals.dart' as capital_data;

enum GamePhase { home, playing, feedback, result }

enum GameMode { countries, capitals }

class GameProvider extends ChangeNotifier {
  GamePhase _phase = GamePhase.home;
  GameMode _mode = GameMode.countries;
  List<Quest> _quests = [];
  int _currentIndex = 0;
  int _totalScore = 0;
  final List<RoundResult> _results = [];
  bool _flagPlaced = false;
  double _guessLat = 0;
  double _guessLng = 0;

  // High scores
  int _highScoreCountries = 0;
  int _highScoreCapitals = 0;

  static const int roundCount = 10;

  GamePhase get phase => _phase;
  GameMode get mode => _mode;
  List<Quest> get quests => _quests;
  int get currentIndex => _currentIndex;
  int get totalScore => _totalScore;
  List<RoundResult> get results => List.unmodifiable(_results);
  bool get flagPlaced => _flagPlaced;
  Quest get currentQuest => _quests[_currentIndex];
  int get roundNumber => _currentIndex + 1;
  int get highScoreCountries => _highScoreCountries;
  int get highScoreCapitals => _highScoreCapitals;

  GameProvider() {
    _loadHighScores();
  }

  Future<void> _loadHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    _highScoreCountries = prefs.getInt('high_countries') ?? 0;
    _highScoreCapitals = prefs.getInt('high_capitals') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (_mode == GameMode.countries && _totalScore > _highScoreCountries) {
      _highScoreCountries = _totalScore;
      await prefs.setInt('high_countries', _totalScore);
    } else if (_mode == GameMode.capitals && _totalScore > _highScoreCapitals) {
      _highScoreCapitals = _totalScore;
      await prefs.setInt('high_capitals', _totalScore);
    }
  }

  void startGame(GameMode mode) {
    _mode = mode;
    final source = mode == GameMode.countries
        ? country_data.countries
        : capital_data.capitals;
    _quests = List<Quest>.from(source)..shuffle(Random());
    _quests = _quests.take(roundCount).toList();
    _currentIndex = 0;
    _totalScore = 0;
    _results.clear();
    _flagPlaced = false;
    _phase = GamePhase.playing;
    notifyListeners();
  }

  void onGlobeClick(double lat, double lng) {
    if (_phase != GamePhase.playing || _flagPlaced) return;
    _guessLat = lat;
    _guessLng = lng;
    _flagPlaced = true;
    notifyListeners();
  }

  RoundResult confirmGuess() {
    final quest = currentQuest;
    final dist = _haversine(quest.lat, quest.lng, _guessLat, _guessLng);
    final (pts, stars) = _score(dist);
    _totalScore += pts;

    final result = RoundResult(
      quest: quest,
      guessLat: _guessLat,
      guessLng: _guessLng,
      distanceKm: dist,
      points: pts,
      stars: stars,
    );
    _results.add(result);
    _phase = GamePhase.feedback;
    notifyListeners();
    return result;
  }

  void nextRound() {
    _flagPlaced = false;
    if (_currentIndex + 1 >= _quests.length) {
      _saveHighScore();
      _phase = GamePhase.result;
    } else {
      _currentIndex++;
      _phase = GamePhase.playing;
    }
    notifyListeners();
  }

  void goHome() {
    _phase = GamePhase.home;
    notifyListeners();
  }

  // ── Scoring ──────────────────────────────────────────────────

  static (int points, int stars) _score(double km) {
    if (km < 200) return (1000, 3);
    if (km < 500) return (750, 3);
    if (km < 1000) return (500, 2);
    if (km < 2000) return (300, 2);
    if (km < 3000) return (200, 1);
    return (100, 1);
  }

  static String feedbackText(int stars) {
    return switch (stars) {
      3 => 'Amazing!',
      2 => 'Great job!',
      _ => 'Keep exploring!',
    };
  }

  // ── Haversine ────────────────────────────────────────────────

  static double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // Earth radius km
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  // total stars across all rounds
  int get totalStars => _results.fold(0, (sum, r) => sum + r.stars);
  int get maxStars => roundCount * 3;
}
