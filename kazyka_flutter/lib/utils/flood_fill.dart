import 'dart:typed_data';

/// Parameters for flood fill, safe to pass to compute() isolate.
class FloodFillParams {
  final Uint32List pixels;
  final int width;
  final int height;
  final int startX;
  final int startY;
  final int fillColor; // ARGB32
  final int tolerance;

  FloodFillParams({
    required this.pixels,
    required this.width,
    required this.height,
    required this.startX,
    required this.startY,
    required this.fillColor,
    this.tolerance = 30,
  });
}

/// Scanline flood fill on a pixel buffer. Runs in an isolate via compute().
Uint32List floodFill(FloodFillParams params) {
  final pixels = Uint32List.fromList(params.pixels); // copy
  final w = params.width;
  final h = params.height;
  final x = params.startX.clamp(0, w - 1);
  final y = params.startY.clamp(0, h - 1);
  final fillColor = params.fillColor;
  final tolerance = params.tolerance;

  final targetColor = pixels[y * w + x];
  if (_colorsMatch(targetColor, fillColor, 0)) return pixels; // already filled

  final queue = <int>[];
  queue.add(y * w + x);
  final visited = Uint8List(w * h);

  while (queue.isNotEmpty) {
    final idx = queue.removeLast();
    if (visited[idx] == 1) continue;

    final cy = idx ~/ w;
    var lx = idx % w;
    var rx = lx;

    // Scan left
    while (lx > 0 && visited[cy * w + lx - 1] == 0 &&
        _colorsMatch(pixels[cy * w + lx - 1], targetColor, tolerance)) {
      lx--;
    }
    // Scan right
    while (rx < w - 1 && visited[cy * w + rx + 1] == 0 &&
        _colorsMatch(pixels[cy * w + rx + 1], targetColor, tolerance)) {
      rx++;
    }

    // Fill the span
    for (var i = lx; i <= rx; i++) {
      pixels[cy * w + i] = fillColor;
      visited[cy * w + i] = 1;
    }

    // Add spans above and below
    for (var i = lx; i <= rx; i++) {
      if (cy > 0) {
        final above = (cy - 1) * w + i;
        if (visited[above] == 0 &&
            _colorsMatch(pixels[above], targetColor, tolerance)) {
          queue.add(above);
        }
      }
      if (cy < h - 1) {
        final below = (cy + 1) * w + i;
        if (visited[below] == 0 &&
            _colorsMatch(pixels[below], targetColor, tolerance)) {
          queue.add(below);
        }
      }
    }
  }

  return pixels;
}

bool _colorsMatch(int c1, int c2, int tolerance) {
  if (tolerance == 0) return c1 == c2;
  final a1 = (c1 >> 24) & 0xFF, r1 = (c1 >> 16) & 0xFF, g1 = (c1 >> 8) & 0xFF, b1 = c1 & 0xFF;
  final a2 = (c2 >> 24) & 0xFF, r2 = (c2 >> 16) & 0xFF, g2 = (c2 >> 8) & 0xFF, b2 = c2 & 0xFF;
  return (a1 - a2).abs() <= tolerance &&
      (r1 - r2).abs() <= tolerance &&
      (g1 - g2).abs() <= tolerance &&
      (b1 - b2).abs() <= tolerance;
}
