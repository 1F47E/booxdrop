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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings',
                style: TextStyle(fontSize: 18, color: Colors.white)),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: ListView(
            children: [
              SwitchListTile(
                title: const Text('Kids Mode',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                subtitle: const Text('Simpler answers with emojis'),
                value: settings.kidsMode,
                activeTrackColor: Colors.black54,
                thumbColor: const WidgetStatePropertyAll(Colors.black),
                onChanged: (value) {
                  settings.setKidsMode(value);
                  EinkService.requestFullRefresh();
                },
              ),
              if (settings.kidsMode) ...[
                const Divider(height: 1, color: Colors.black26),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Age: ${settings.kidsAge}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Slider(
                    value: settings.kidsAge.toDouble(),
                    min: 3,
                    max: 12,
                    divisions: 9,
                    label: '${settings.kidsAge}',
                    activeColor: Colors.black,
                    inactiveColor: Colors.black26,
                    onChanged: (value) {
                      settings.setKidsAge(value.round());
                      EinkService.requestFullRefresh();
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('3', style: TextStyle(color: Colors.black54)),
                      Text('12', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
              const Divider(height: 1, color: Colors.black26),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Text Size: ${settings.rawFontSize.round()}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Slider(
                  value: settings.rawFontSize,
                  min: 12,
                  max: 28,
                  divisions: 16,
                  label: '${settings.rawFontSize.round()}',
                  activeColor: Colors.black,
                  inactiveColor: Colors.black26,
                  onChanged: (value) {
                    settings.setFontSize(value);
                    EinkService.requestFullRefresh();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: settings.fontSize,
                    color: Colors.black,
                  ),
                ),
              ),
              if (settings.availableImageProviders.length > 1) ...[
                const Divider(height: 1, color: Colors.black26),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Text(
                    'Image Provider',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    segments: settings.availableImageProviders
                        .map((p) => ButtonSegment(
                              value: p,
                              label: Text(
                                  SettingsProvider.imageProviderNames[p] ?? p),
                            ))
                        .toList(),
                    selected: {settings.imageProvider},
                    onSelectionChanged: (v) {
                      settings.setImageProvider(v.first);
                      EinkService.requestFullRefresh();
                    },
                    style: ButtonStyle(
                      foregroundColor:
                          WidgetStatePropertyAll(Colors.black),
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected)
                            ? Colors.black12
                            : Colors.transparent;
                      }),
                    ),
                  ),
                ),
              ],
              if (settings.imageProvider == 'nano_banana') ...[
                const Divider(height: 1, color: Colors.black26),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Text(
                    'Model',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    segments:
                        SettingsProvider.nanoBananaModelNames.entries
                            .map((e) => ButtonSegment(
                                  value: e.key,
                                  label: Text(
                                    '${e.value} ${SettingsProvider.nanoBananaModelPrices[e.key]}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ))
                            .toList(),
                    selected: {settings.nanoBananaModel},
                    onSelectionChanged: (v) {
                      settings.setNanoBananaModel(v.first);
                      EinkService.requestFullRefresh();
                    },
                    style: ButtonStyle(
                      foregroundColor:
                          WidgetStatePropertyAll(Colors.black),
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected)
                            ? Colors.black12
                            : Colors.transparent;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (settings.availableTtsProviders.isNotEmpty) ...[
                const Divider(height: 1, color: Colors.black26),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Text(
                    'TTS Provider',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                if (settings.availableTtsProviders.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<String>(
                      segments: settings.availableTtsProviders
                          .map((p) => ButtonSegment(
                                value: p,
                                label: Text(
                                    SettingsProvider.ttsProviderNames[p] ?? p),
                              ))
                          .toList(),
                      selected: {settings.ttsProvider},
                      onSelectionChanged: (v) {
                        settings.setTtsProvider(v.first);
                        EinkService.requestFullRefresh();
                      },
                      style: ButtonStyle(
                        foregroundColor:
                            WidgetStatePropertyAll(Colors.black),
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          return states.contains(WidgetState.selected)
                              ? Colors.black12
                              : Colors.transparent;
                        }),
                      ),
                    ),
                  ),
                if (settings.availableTtsProviders.length == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      SettingsProvider.ttsProviderNames[settings.ttsProvider] ??
                          settings.ttsProvider,
                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                  ),
                const Divider(height: 1, color: Colors.black26),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Text(
                    'Voice',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                ...() {
                  final provider = TtsService.getProvider(settings);
                  return provider.availableVoices.entries.map((e) {
                    final isSelected = e.key == settings.ttsVoice;
                    return ListTile(
                      dense: true,
                      title: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.black, size: 20)
                          : null,
                      selected: isSelected,
                      selectedTileColor: Colors.black.withValues(alpha: 0.05),
                      onTap: () {
                        settings.setTtsVoice(e.key);
                        EinkService.requestFullRefresh();
                      },
                    );
                  }).toList();
                }(),
                const SizedBox(height: 8),
              ],
              const Divider(height: 1, color: Colors.black26),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black),
                title: const Text('Images',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                subtitle: const Text('View all generated images'),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ImageGalleryScreen()),
                  );
                },
              ),
              const Divider(height: 1, color: Colors.black26),
              ListTile(
                leading:
                    const Icon(Icons.article_outlined, color: Colors.black),
                title: const Text('Logs',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                subtitle: const Text('View app activity log'),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogsScreen()),
                  );
                },
              ),
              const Divider(height: 1, color: Colors.black26),
              ListTile(
                leading:
                    const Icon(Icons.history, color: Colors.black),
                title: const Text('Changelog',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                subtitle: const Text('Version history'),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChangelogScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'v${AppVersion.version}${AppVersion.buildDate.isNotEmpty ? ' \u00b7 ${AppVersion.buildDate}' : ''}',
                  style: const TextStyle(fontSize: 13, color: Colors.black38),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Built with \u2764\ufe0f for Mia and Iva',
                  style: TextStyle(fontSize: 13, color: Colors.black38),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
