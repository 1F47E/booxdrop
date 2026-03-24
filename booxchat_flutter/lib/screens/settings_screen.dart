import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/eink_service.dart';

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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
