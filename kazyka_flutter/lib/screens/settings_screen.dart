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
            style: TextStyle(fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
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
                borderSide: const BorderSide(color: Color(0xFF888888)),
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
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Kazyka v${AppVersion.version}${AppVersion.buildDate.isNotEmpty ? ' \u00b7 ${AppVersion.buildDate}' : ''}',
              style: const TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}
