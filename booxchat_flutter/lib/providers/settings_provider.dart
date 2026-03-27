import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tts_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const chatModelNames = {
    'gpt-5.4-mini': 'GPT-5.4 Mini',
    'gpt-5.4': 'GPT-5.4',
  };
  static const reasoningLevels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
  };
  static const imageProviderNames = {
    'nano_banana': 'Nano Banana',
    'openai': 'OpenAI',
    'grok': 'Grok',
  };
  static const ttsProviderNames = {
    'openai': 'OpenAI',
    'elevenlabs': 'ElevenLabs',
  };
  static const nanoBananaModelNames = {
    'gemini-3.1-flash-image-preview': 'Nano Banana 2',
    'nano-banana-pro-preview': 'Nano Banana Pro',
  };
  static const nanoBananaModelPrices = {
    'gemini-3.1-flash-image-preview': '~\$0.07/img',
    'nano-banana-pro-preview': '~\$0.10/img',
  };
  static const grokModelNames = {
    'grok-imagine-image': 'Standard',
    'grok-imagine-image-pro': 'Pro',
  };
  static const grokModelPrices = {
    'grok-imagine-image': '~\$0.02/img',
    'grok-imagine-image-pro': '~\$0.07/img',
  };

  static bool get hasGoogleKey =>
      (dotenv.env['GOOGLE_AI_API_KEY'] ?? '').isNotEmpty;
  static bool get hasOpenAIKey =>
      (dotenv.env['OPENAI_API_KEY'] ?? '').isNotEmpty;
  static bool get hasElevenLabsKey =>
      (dotenv.env['ELEVENLABS_API_KEY'] ?? '').isNotEmpty;
  static bool get hasXAIKey =>
      (dotenv.env['XAI_API_KEY'] ?? '').isNotEmpty;

  List<String> get availableImageProviders => [
        if (hasGoogleKey) 'nano_banana',
        if (hasOpenAIKey) 'openai',
        if (hasXAIKey) 'grok',
      ];

  List<String> get availableTtsProviders => [
        if (hasOpenAIKey) 'openai',
        if (hasElevenLabsKey) 'elevenlabs',
      ];

  static const _kChatModel = 'settings_chat_model';
  static const _kKidsMode = 'settings_kids_mode';
  static const _kKidsAge = 'settings_kids_age';
  static const _kFontSize = 'settings_font_size';
  static const _kImageProvider = 'settings_image_provider';
  static const _kNanoBananaModel = 'settings_nano_banana_model';
  static const _kGrokModel = 'settings_grok_model';
  static const _kTtsProvider = 'settings_tts_provider';
  static const _kTtsVoice = 'settings_tts_voice';
  static const _kReasoning = 'settings_reasoning';

  String _chatModel = 'gpt-5.4-mini';
  String _reasoning = 'low';
  bool _kidsMode = true;
  int _kidsAge = 7;
  double _fontSize = 23;
  String _imageProvider = 'nano_banana';
  String _nanoBananaModel = 'gemini-3.1-flash-image-preview';
  String _grokModel = 'grok-imagine-image';
  String _ttsProvider = 'elevenlabs';
  String _ttsVoice = 'nova';

  String get chatModel => _chatModel;
  String get reasoning => _reasoning;
  bool get kidsMode => _kidsMode;
  int get kidsAge => _kidsAge;
  double get fontSize => _kidsMode ? (_fontSize + 5) : _fontSize;
  double get rawFontSize => _fontSize;
  String get imageProvider {
    if (availableImageProviders.contains(_imageProvider)) return _imageProvider;
    return availableImageProviders.isNotEmpty
        ? availableImageProviders.first
        : 'nano_banana';
  }
  String get nanoBananaModel => _nanoBananaModel;
  String get grokModel => _grokModel;
  String get ttsProvider {
    if (availableTtsProviders.contains(_ttsProvider)) return _ttsProvider;
    return availableTtsProviders.isNotEmpty
        ? availableTtsProviders.first
        : 'openai';
  }

  String get ttsVoice {
    final provider = TtsService.getProvider(this);
    if (provider.availableVoices.containsKey(_ttsVoice)) return _ttsVoice;
    return provider.availableVoices.keys.first;
  }

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _chatModel = prefs.getString(_kChatModel) ?? 'gpt-5.4-mini';
    _reasoning = prefs.getString(_kReasoning) ?? 'low';
    _kidsMode = prefs.getBool(_kKidsMode) ?? true;
    _kidsAge = prefs.getInt(_kKidsAge) ?? 7;
    _fontSize = prefs.getDouble(_kFontSize) ?? 23;
    _imageProvider = prefs.getString(_kImageProvider) ?? 'nano_banana';
    _nanoBananaModel = prefs.getString(_kNanoBananaModel) ??
        'gemini-3.1-flash-image-preview';
    _grokModel = prefs.getString(_kGrokModel) ?? 'grok-imagine-image';
    _ttsProvider = prefs.getString(_kTtsProvider) ?? 'elevenlabs';
    _ttsVoice = prefs.getString(_kTtsVoice) ?? 'nova';
    notifyListeners();
  }

  Future<void> setChatModel(String model) async {
    _chatModel = model;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kChatModel, model);
  }

  Future<void> setReasoning(String value) async {
    _reasoning = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReasoning, value);
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

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(12, 28);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, _fontSize);
  }

  Future<void> setImageProvider(String value) async {
    _imageProvider = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kImageProvider, value);
  }

  Future<void> setNanoBananaModel(String model) async {
    _nanoBananaModel = model;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNanoBananaModel, model);
  }

  Future<void> setGrokModel(String model) async {
    _grokModel = model;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGrokModel, model);
  }

  Future<void> setTtsProvider(String value) async {
    _ttsProvider = value;
    // Auto-reset voice to first available for the new provider
    final provider = TtsService.getProvider(this);
    _ttsVoice = provider.availableVoices.keys.first;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTtsProvider, value);
    await prefs.setString(_kTtsVoice, _ttsVoice);
  }

  Future<void> setTtsVoice(String voice) async {
    _ttsVoice = voice;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTtsVoice, voice);
  }

  Future<void> saveAll({
    required String chatModel,
    required String reasoning,
    required bool kidsMode,
    required int kidsAge,
    required double fontSize,
    required String imageProvider,
    required String nanoBananaModel,
    required String grokModel,
    required String ttsProvider,
    required String ttsVoice,
  }) async {
    _chatModel = chatModel;
    _reasoning = reasoning;
    _kidsMode = kidsMode;
    _kidsAge = kidsAge;
    _fontSize = fontSize;
    _imageProvider = imageProvider;
    _nanoBananaModel = nanoBananaModel;
    _grokModel = grokModel;
    _ttsProvider = ttsProvider;
    _ttsVoice = ttsVoice;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kChatModel, chatModel);
    await prefs.setString(_kReasoning, reasoning);
    await prefs.setBool(_kKidsMode, kidsMode);
    await prefs.setInt(_kKidsAge, kidsAge);
    await prefs.setDouble(_kFontSize, fontSize);
    await prefs.setString(_kImageProvider, imageProvider);
    await prefs.setString(_kNanoBananaModel, nanoBananaModel);
    await prefs.setString(_kGrokModel, grokModel);
    await prefs.setString(_kTtsProvider, ttsProvider);
    await prefs.setString(_kTtsVoice, ttsVoice);
  }
}
