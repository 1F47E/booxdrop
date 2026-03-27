import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_playback_controller.dart';

class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AudioPlaybackController>();
    if (!controller.hasActiveTrack &&
        !controller.isLoading &&
        controller.error == null) {
      return const SizedBox.shrink();
    }

    // Error-only bar (no active track)
    if (!controller.hasActiveTrack) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.isLoading
                    ? 'Loading audio...'
                    : (controller.error ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: controller.stopAndClear,
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      );
    }

    // Normal bar with active track
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: const Text(
                'Loading audio...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Text(
                controller.error!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: controller.isLoading
                      ? null
                      : (controller.isPlaying
                          ? controller.pause
                          : controller.resume),
                  icon: Icon(
                    controller.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.currentLabel ?? 'Audio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: controller.stopAndClear,
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
