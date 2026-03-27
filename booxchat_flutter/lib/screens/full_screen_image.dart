import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../services/storage_service.dart';

class FullScreenImage extends StatefulWidget {
  /// List of image paths for swipe navigation.
  final List<String> paths;
  final int initialIndex;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;

  const FullScreenImage({
    super.key,
    required this.paths,
    this.initialIndex = 0,
    this.onDelete,
    this.onChat,
  });

  /// Convenience: single image (backwards compatible with gallery).
  factory FullScreenImage.single({
    Key? key,
    required String path,
    VoidCallback? onDelete,
    VoidCallback? onChat,
  }) =>
      FullScreenImage(
        key: key,
        paths: [path],
        initialIndex: 0,
        onDelete: onDelete,
        onChat: onChat,
      );

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentPath => widget.paths[_currentIndex];

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final result = await ImageGallerySaverPlus.saveFile(_currentPath);
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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await StorageService.deleteImage(_currentPath);
    widget.onDelete?.call();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 8;
    final hasMultiple = widget.paths.length > 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Swipeable images
          PageView.builder(
            controller: _pageController,
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return Center(
                child: Image.file(
                  File(widget.paths[index]),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('[Image not found]'),
                ),
              );
            },
          ),

          // Page indicator
          if (hasMultiple)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.paths.length}',
                  style: const TextStyle(
                      fontSize: 15, color: const Color(0xFF444444)),
                ),
              ),
            ),

          // Top buttons
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
                  child:
                      Icon(Icons.save_alt, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          if (widget.onDelete != null)
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
                    child: Icon(Icons.delete_outline,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          if (widget.onChat != null)
            Positioned(
              top: topPad,
              left: 104,
              child: Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    widget.onChat!.call();
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.chat_bubble_outline,
                        color: Colors.white, size: 24),
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
                  child:
                      Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
