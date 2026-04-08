import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/game_provider.dart';
import '../models/quest.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _controller;
  bool _globeReady = false;
  RoundResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0a1628))
      ..addJavaScriptChannel(
        'GlobeChannel',
        onMessageReceived: _onGlobeMessage,
      )
      ..loadFlutterAsset('assets/globe/index.html');
  }

  void _onGlobeMessage(JavaScriptMessage msg) {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    switch (data['type']) {
      case 'ready':
        setState(() => _globeReady = true);
        _startRound();
      case 'click':
        final lat = (data['lat'] as num).toDouble();
        final lng = (data['lng'] as num).toDouble();
        _onGlobeClick(lat, lng);
    }
  }

  void _startRound() {
    setState(() => _lastResult = null);
    _controller.runJavaScript('newRound()');
  }

  void _onGlobeClick(double lat, double lng) {
    final game = context.read<GameProvider>();
    if (game.flagPlaced) return;

    game.onGlobeClick(lat, lng);
    _controller.runJavaScript('placeFlag($lat, $lng)');
  }

  void _confirmGuess() {
    final game = context.read<GameProvider>();
    final result = game.confirmGuess();
    setState(() => _lastResult = result);

    final q = result.quest;
    _controller.runJavaScript(
      'showAnswer(${q.lat}, ${q.lng}, ${result.guessLat}, ${result.guessLng})',
    );
  }

  void _nextRound() {
    final game = context.read<GameProvider>();
    game.nextRound();
    if (game.phase == GamePhase.playing) {
      _startRound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final quest = game.currentQuest;
    final isFeedback = game.phase == GamePhase.feedback;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: round, score, question ──
            _buildTopBar(game, quest),

            // ── Globe WebView ──
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (!_globeReady)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF43A047),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading globe...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Bottom bar: actions + feedback ──
            _buildBottomBar(game, isFeedback),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(GameProvider game, Quest quest) {
    final modeLabel =
        game.mode == GameMode.countries ? 'Countries' : 'Capitals';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1B5E20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$modeLabel  ${game.roundNumber}/${GameProvider.roundCount}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${game.totalScore} pts',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Where is ${quest.flag} ${quest.name}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (quest.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                quest.hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(GameProvider game, bool isFeedback) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: isFeedback ? _buildFeedback() : _buildActions(game),
    );
  }

  Widget _buildActions(GameProvider game) {
    if (!game.flagPlaced) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: Text(
            'Tap the globe to place your flag!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: _confirmGuess,
        child: const Text('Lock In My Guess!'),
      ),
    );
  }

  Widget _buildFeedback() {
    final r = _lastResult;
    if (r == null) return const SizedBox.shrink();

    final stars = '\u{2B50}' * r.stars;
    final feedback = GameProvider.feedbackText(r.stars);
    final distText = r.distanceKm < 1
        ? 'Right on it!'
        : '${r.distanceKm.round()} km away';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stars,
          style: const TextStyle(fontSize: 36),
        ),
        const SizedBox(height: 4),
        Text(
          feedback,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        Text(
          '$distText  •  +${r.points} pts',
          style: const TextStyle(fontSize: 20, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _nextRound,
            child: Text(
              context.read<GameProvider>().currentIndex + 1 >=
                      GameProvider.roundCount
                  ? 'See Results!'
                  : 'Next',
            ),
          ),
        ),
      ],
    );
  }
}
