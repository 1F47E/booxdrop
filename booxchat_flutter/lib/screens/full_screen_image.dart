import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../services/storage_service.dart';

class FullScreenImage extends StatelessWidget {
  final String path;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;
  const FullScreenImage({super.key, required this.path, this.onDelete, this.onChat});

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final result = await ImageGallerySaverPlus.saveFile(path);
      if (!context.mounted) return;
      final ok = result['isSuccess'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Saved to gallery' : 'Failed to save'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete image?'),
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
    if (confirmed != true || !context.mounted) return;
    await StorageService.deleteImage(path);
    onDelete?.call();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 8;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('[Image not found]'),
            ),
          ),
          Positioned(
            top: topPad,
            left: 8,
            child: Material(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _saveToGallery(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.save_alt, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: topPad,
              left: 56,
              child: Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _confirmDelete(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          if (onChat != null)
            Positioned(
              top: topPad,
              left: 104,
              child: Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    onChat!.call();
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          Positioned(
            top: topPad,
            right: 8,
            child: Material(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
