import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changelog',
            style: TextStyle(fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('CHANGELOG.md'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.black));
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load changelog',
                    style: TextStyle(color: const Color(0xFF444444))));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              snapshot.data ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          );
        },
      ),
    );
  }
}
