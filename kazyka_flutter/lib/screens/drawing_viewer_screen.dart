import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class DrawingViewerScreen extends StatelessWidget {
  final String path;
  final VoidCallback? onDeleted;

  const DrawingViewerScreen({
    super.key,
    required this.path,
    this.onDeleted,
  });

  void _onDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete drawing?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.deleteDrawing(path);
      onDeleted?.call();
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.black),
            onPressed: () => _onDelete(context),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text(
            'Image not found',
            style: TextStyle(color: const Color(0xFF444444), fontSize: 16),
          ),
        ),
      ),
    );
  }
}
