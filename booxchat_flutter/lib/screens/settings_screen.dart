import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/eink_service.dart';
import '../services/tts_service.dart';
import '../config/app_version.dart';
import 'changelog_screen.dart';
import 'audio_gallery_screen.dart';
import 'image_gallery_screen.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Draft state
  String _chatModel = 'gpt-5.4-mini';
  String _reasoning = 'low';
  bool _kidsMode = false;
  int _kidsAge = 7;
  double _fontSize = 17;
  String _imageProvider = 'nano_banana';
  String _nanoBananaModel = 'gemini-3.1-flash-image-preview';
  String _grokModel = 'grok-imagine-image';
  String _ttsProvider = 'openai';
  String _ttsVoice = 'nova';
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _syncFromProvider();
    // Re-sync when provider finishes async _load()
    context.read<SettingsProvider>().addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    // May already be disposed if navigated away after provider gone
    try {
      context.read<SettingsProvider>().removeListener(_onProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onProviderChanged() {
    // Only re-sync if the user hasn't made local changes
    if (!_dirty && mounted) {
      setState(() => _syncFromProvider());
    }
  }

  void _syncFromProvider() {
    final s = context.read<SettingsProvider>();
    _chatModel = s.chatModel;
    _reasoning = s.reasoning;
    _kidsMode = s.kidsMode;
    _kidsAge = s.kidsAge;
    _fontSize = s.rawFontSize;
    _imageProvider = s.imageProvider;
    _nanoBananaModel = s.nanoBananaModel;
    _grokModel = s.grokModel;
    _ttsProvider = s.ttsProvider;
    _ttsVoice = s.ttsVoice;
  }

  String? get _validationError {
    final imgOk = switch (_imageProvider) {
      'nano_banana' => SettingsProvider.hasGoogleKey,
      'openai' => SettingsProvider.hasOpenAIKey,
      'grok' => SettingsProvider.hasXAIKey,
      _ => false,
    };
    if (!imgOk) {
      return 'API key missing for ${SettingsProvider.imageProviderNames[_imageProvider]}';
    }
    final ttsOk = switch (_ttsProvider) {
      'openai' => SettingsProvider.hasOpenAIKey,
      'elevenlabs' => SettingsProvider.hasElevenLabsKey,
      _ => true,
    };
    if (!ttsOk) {
      return 'API key missing for ${SettingsProvider.ttsProviderNames[_ttsProvider]}';
    }
    return null;
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _save() async {
    final s = context.read<SettingsProvider>();
    await s.saveAll(
      chatModel: _chatModel,
      reasoning: _reasoning,
      kidsMode: _kidsMode,
      kidsAge: _kidsAge,
      fontSize: _fontSize,
      imageProvider: _imageProvider,
      nanoBananaModel: _nanoBananaModel,
      grokModel: _grokModel,
      ttsProvider: _ttsProvider,
      ttsVoice: _ttsVoice,
    );
    EinkService.requestFullRefresh();
    setState(() => _dirty = false);
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // Reusable segmented button style
  static final _segmentStyle = ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(Colors.black),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? Colors.black12
          : Colors.transparent;
    }),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.read<SettingsProvider>();
    final error = _validationError;
    final canSave = _dirty && error == null;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings',
              style: TextStyle(fontSize: 18, color: Colors.white)),
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // --- Chat Model ---
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Chat Model',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButton<String>(
                      value: _chatModel,
                      isExpanded: true,
                      underline: Container(height: 1, color: Colors.black26),
                      items: SettingsProvider.chatModelNames.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value,
                                    style: const TextStyle(fontSize: 15)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _chatModel = v);
                          _markDirty();
                        }
                      },
                    ),
                  ),

                  // --- Reasoning ---
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Reasoning',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButton<String>(
                      value: _reasoning,
                      isExpanded: true,
                      underline: Container(height: 1, color: Colors.black26),
                      items: SettingsProvider.reasoningLevels.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value,
                                    style: const TextStyle(fontSize: 15)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _reasoning = v);
                          _markDirty();
                        }
                      },
                    ),
                  ),

                  // --- Kids Mode ---
                  const Divider(height: 1, color: Colors.black26),
                  SwitchListTile(
                    title: const Text('Kids Mode',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Simpler answers with emojis'),
                    value: _kidsMode,
                    activeTrackColor: Colors.black54,
                    thumbColor:
                        const WidgetStatePropertyAll(Colors.black),
                    onChanged: (v) {
                      setState(() => _kidsMode = v);
                      _markDirty();
                    },
                  ),
                  if (_kidsMode) ...[
                    const Divider(height: 1, color: Colors.black26),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text('Age: $_kidsAge',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Slider(
                        value: _kidsAge.toDouble(),
                        min: 3,
                        max: 12,
                        divisions: 9,
                        label: '$_kidsAge',
                        activeColor: Colors.black,
                        inactiveColor: Colors.black26,
                        onChanged: (v) {
                          setState(() => _kidsAge = v.round());
                          _markDirty();
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('3',
                              style: TextStyle(color: Colors.black54)),
                          Text('12',
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],

                  // --- Text Size ---
                  const Divider(height: 1, color: Colors.black26),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text('Text Size: ${_fontSize.round()}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 28,
                      divisions: 16,
                      label: '${_fontSize.round()}',
                      activeColor: Colors.black,
                      inactiveColor: Colors.black26,
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        _markDirty();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Preview',
                        style: TextStyle(
                          fontSize:
                              _kidsMode ? (_fontSize + 5) : _fontSize,
                          color: Colors.black,
                        )),
                  ),

                  // --- Image Provider ---
                  if (s.availableImageProviders.length > 1) ...[
                    const Divider(height: 1, color: Colors.black26),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Image Provider',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<String>(
                        segments: s.availableImageProviders
                            .map((p) => ButtonSegment(
                                  value: p,
                                  label: Text(
                                      SettingsProvider
                                              .imageProviderNames[p] ??
                                          p),
                                ))
                            .toList(),
                        selected: {_imageProvider},
                        onSelectionChanged: (v) {
                          setState(() => _imageProvider = v.first);
                          _markDirty();
                        },
                        style: _segmentStyle,
                      ),
                    ),
                  ],

                  // --- Nano Banana Model ---
                  if (_imageProvider == 'nano_banana') ...[
                    const Divider(height: 1, color: Colors.black26),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Model',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<String>(
                        segments: SettingsProvider
                            .nanoBananaModelNames.entries
                            .map((e) => ButtonSegment(
                                  value: e.key,
                                  label: Text(
                                    '${e.value} ${SettingsProvider.nanoBananaModelPrices[e.key]}',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ))
                            .toList(),
                        selected: {_nanoBananaModel},
                        onSelectionChanged: (v) {
                          setState(() => _nanoBananaModel = v.first);
                          _markDirty();
                        },
                        style: _segmentStyle,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // --- Grok Model ---
                  if (_imageProvider == 'grok') ...[
                    const Divider(height: 1, color: Colors.black26),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Model',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<String>(
                        segments:
                            SettingsProvider.grokModelNames.entries
                                .map((e) => ButtonSegment(
                                      value: e.key,
                                      label: Text(
                                        '${e.value} ${SettingsProvider.grokModelPrices[e.key]}',
                                        style:
                                            const TextStyle(fontSize: 15),
                                      ),
                                    ))
                                .toList(),
                        selected: {_grokModel},
                        onSelectionChanged: (v) {
                          setState(() => _grokModel = v.first);
                          _markDirty();
                        },
                        style: _segmentStyle,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // --- TTS Provider ---
                  if (s.availableTtsProviders.isNotEmpty) ...[
                    const Divider(height: 1, color: Colors.black26),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('TTS Provider',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    if (s.availableTtsProviders.length > 1)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: SegmentedButton<String>(
                          segments: s.availableTtsProviders
                              .map((p) => ButtonSegment(
                                    value: p,
                                    label: Text(
                                        SettingsProvider
                                                .ttsProviderNames[p] ??
                                            p),
                                  ))
                              .toList(),
                          selected: {_ttsProvider},
                          onSelectionChanged: (v) {
                            setState(() {
                              _ttsProvider = v.first;
                              // Reset voice to first available for NEW provider
                              final prov =
                                  TtsService.getProviderByKey(v.first);
                              _ttsVoice =
                                  prov.availableVoices.keys.first;
                            });
                            _markDirty();
                          },
                          style: _segmentStyle,
                        ),
                      ),
                    if (s.availableTtsProviders.length == 1)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          SettingsProvider
                                  .ttsProviderNames[_ttsProvider] ??
                              _ttsProvider,
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black54),
                        ),
                      ),

                    // --- Voice ---
                    const Divider(height: 1, color: Colors.black26),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('Voice',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    ...() {
                      final provider =
                          TtsService.getProviderByKey(_ttsProvider);
                      return provider.availableVoices.entries.map((e) {
                        final isSelected = e.key == _ttsVoice;
                        return ListTile(
                          dense: true,
                          title: Text(e.value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.black,
                              )),
                          trailing: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.black, size: 20)
                              : null,
                          selected: isSelected,
                          selectedTileColor:
                              Colors.black.withValues(alpha: 0.05),
                          onTap: () {
                            setState(() => _ttsVoice = e.key);
                            _markDirty();
                          },
                        );
                      }).toList();
                    }(),
                    const SizedBox(height: 8),
                  ],

                  // --- Gallery links ---
                  const Divider(height: 1, color: Colors.black26),
                  ListTile(
                    leading: const Icon(Icons.photo_library,
                        color: Colors.black),
                    title: const Text('Images',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                    subtitle: const Text('View all generated images'),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.black54),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ImageGalleryScreen())),
                  ),
                  if (s.availableTtsProviders.isNotEmpty) ...[
                    const Divider(height: 1, color: Colors.black26),
                    ListTile(
                      leading: const Icon(Icons.audiotrack,
                          color: Colors.black),
                      title: const Text('Audio',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w500)),
                      subtitle:
                          const Text('View all generated audio'),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.black54),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AudioGalleryScreen())),
                    ),
                  ],
                  const Divider(height: 1, color: Colors.black26),
                  ListTile(
                    leading: const Icon(Icons.article_outlined,
                        color: Colors.black),
                    title: const Text('Logs',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                    subtitle: const Text('View app activity log'),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.black54),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LogsScreen())),
                  ),
                  const Divider(height: 1, color: Colors.black26),
                  ListTile(
                    leading: const Icon(Icons.history,
                        color: Colors.black),
                    title: const Text('Changelog',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Version history'),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.black54),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ChangelogScreen())),
                  ),

                  // --- Version info ---
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'v${AppVersion.version}${AppVersion.buildDate.isNotEmpty ? ' \u00b7 ${AppVersion.buildDate}' : ''}',
                      style: const TextStyle(
                          fontSize: 15, color: Colors.black38),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Built with \u2764\ufe0f for Mia and Iva',
                      style: TextStyle(
                          fontSize: 15, color: Colors.black38),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // --- Save button + validation warning ---
            if (error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(error,
                    style:
                        const TextStyle(fontSize: 15, color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
