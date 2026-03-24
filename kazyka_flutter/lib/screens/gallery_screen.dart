import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'drawing_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<File>> _drawingsFuture;

  @override
  void initState() {
    super.initState();
    _drawingsFuture = StorageService.listDrawings();
  }

  void _refresh() {
    setState(() {
      _drawingsFuture = StorageService.listDrawings();
    });
  }

  void _openDrawing(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingViewerScreen(
          path: path,
          onDeleted: _refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Drawings',
            style: TextStyle(fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<File>>(
        future: _drawingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.black));
          }
          final drawings = snapshot.data ?? [];
          if (drawings.isEmpty) {
            return const Center(
              child: Text(
                'No drawings yet — go draw something!',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${drawings.length} drawing${drawings.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: drawings.length,
                  itemBuilder: (context, index) {
                    final file = drawings[index];
                    return GestureDetector(
                      onTap: () => _openDrawing(file.path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image,
                                color: Colors.black38),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
