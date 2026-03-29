import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'drawing_screen.dart';

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

  void _onEditCopy(BuildContext context) async {
    // Try to load the editable sidecar
    final doc = await StorageService.loadDocument(path);

    if (!context.mounted) return;

    if (doc != null) {
      // v2 drawing with sidecar — reopen fully editable
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DrawingScreen(initialDocument: doc),
        ),
      );
    } else {
      // Legacy PNG-only — open as background reference
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DrawingScreen(backgroundImagePath: path),
        ),
      );
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
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () => _onEditCopy(context),
            tooltip: 'Edit copy',
          ),
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
            style: TextStyle(color: Color(0xFF444444), fontSize: 16),
          ),
        ),
      ),
    );
  }
}
