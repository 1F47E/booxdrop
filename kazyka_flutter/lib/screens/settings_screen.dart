import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_version.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _nameController = TextEditingController(text: settings.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Your Name',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter your name...',
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF444444)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 18),
            onChanged: (value) {
              context.read<SettingsService>().setName(value);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'This name appears on the drawing screen',
            style: TextStyle(fontSize: 16, color: const Color(0xFF444444)),
          ),
          const SizedBox(height: 32),

          // Canvas size
          const Text(
            'Canvas Size',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Consumer<SettingsService>(
            builder: (_, settings, _) {
              const labels = {1024: 'Small', 2048: 'Medium', 4096: 'Large'};
              return Row(
                children: SettingsService.canvasSizeOptions.map((size) {
                  final selected = settings.defaultCanvasSize == size;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => settings.setDefaultCanvasSize(size),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected ? Colors.black : Colors.white,
                            border: Border.all(
                              color: Colors.black,
                              width: selected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${labels[size]}\n$size',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Default size for new drawings',
            style: TextStyle(fontSize: 16, color: Color(0xFF444444)),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Kazyka v${AppVersion.version}${AppVersion.buildDate.isNotEmpty ? ' \u00b7 ${AppVersion.buildDate}' : ''}',
              style: const TextStyle(fontSize: 16, color: const Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }
}
