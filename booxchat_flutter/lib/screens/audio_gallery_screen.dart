import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_playback_controller.dart';
import '../services/storage_service.dart';

class AudioGalleryScreen extends StatefulWidget {
  const AudioGalleryScreen({super.key});

  @override
  State<AudioGalleryScreen> createState() => _AudioGalleryScreenState();
}

class _AudioGalleryScreenState extends State<AudioGalleryScreen> {
  late Future<List<File>> _audioFuture;

  @override
  void initState() {
    super.initState();
    _audioFuture = StorageService.listAudio();
  }

  void _refresh() {
    setState(() {
      _audioFuture = StorageService.listAudio();
    });
  }

  Future<void> _deleteAudio(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete audio?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final controller = context.read<AudioPlaybackController>();
      if (controller.isCurrentTrack(path)) {
        await controller.stopAndClear();
      }
      await StorageService.deleteAudio(path);
      _refresh();
    }
  }

  String _formatName(File file) {
    final name = file.path.split('/').last.replaceAll('.mp3', '');
    return name;
  }

  String _formatDate(File file) {
    final dt = file.lastModifiedSync();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio',
            style: TextStyle(fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<File>>(
        future: _audioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.black));
          }
          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return const Center(
              child: Text(
                'No audio yet',
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
                    '${files.length} clip${files.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final controller = context.watch<AudioPlaybackController>();
                    final isPlaying = controller.isCurrentTrack(file.path) &&
                        controller.isPlaying;
                    final isCurrent = controller.isCurrentTrack(file.path);
                    return ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          onPressed: () {
                            context.read<AudioPlaybackController>().togglePlay(
                              path: file.path,
                              label: _formatName(file),
                            );
                          },
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.black,
                            size: 36,
                          ),
                        ),
                      ),
                      title: Text(
                        _formatName(file),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        _formatDate(file),
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.black54, size: 20),
                        onPressed: () => _deleteAudio(file.path),
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
