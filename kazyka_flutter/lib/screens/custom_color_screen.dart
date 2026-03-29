import 'package:flutter/material.dart';

/// Quantize a color to Kaleido 3's 4-bit-per-channel (16 levels).
Color _quantize(Color c) {
  int q(double v) => ((v * 255 / 17).round() * 17).clamp(0, 255);
  return Color.fromARGB(255, q(c.r), q(c.g), q(c.b));
}

/// Convert HSV to a Kaleido 3 safe Color.
Color _hsvToSafe(double hue, double saturation, double value) {
  final hsv = HSVColor.fromAHSV(1.0, hue, saturation, value);
  return _quantize(hsv.toColor());
}

class CustomColorScreen extends StatefulWidget {
  final Color? initialColor;

  const CustomColorScreen({super.key, this.initialColor});

  @override
  State<CustomColorScreen> createState() => _CustomColorScreenState();
}

class _CustomColorScreenState extends State<CustomColorScreen> {
  // 16 hue stops
  static const _hueSteps = [
    0.0, 22.5, 45.0, 67.5, 90.0, 112.5, 135.0, 157.5,
    180.0, 202.5, 225.0, 247.5, 270.0, 292.5, 315.0, 337.5,
  ];

  // 4 saturation stops
  static const _satSteps = [1.0, 0.75, 0.5, 0.25];

  // 4 value/brightness stops
  static const _valSteps = [1.0, 0.75, 0.5, 0.25];

  double _hue = 0;
  double _saturation = 1.0;
  double _value = 1.0;

  Color get _currentColor => _hsvToSafe(_hue, _saturation, _value);

  @override
  void initState() {
    super.initState();
    if (widget.initialColor != null) {
      final hsv = HSVColor.fromColor(widget.initialColor!);
      // Snap to nearest stops
      _hue = _hueSteps.reduce((a, b) =>
          (a - hsv.hue).abs() < (b - hsv.hue).abs() ? a : b);
      _saturation = _satSteps.reduce((a, b) =>
          (a - hsv.saturation).abs() < (b - hsv.saturation).abs() ? a : b);
      _value = _valSteps.reduce((a, b) =>
          (a - hsv.value).abs() < (b - hsv.value).abs() ? a : b);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pick a Color',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Color preview
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Hue row
              const Text(
                'Color',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _hueSteps.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final h = _hueSteps[i];
                    final color = _hsvToSafe(h, 1.0, 1.0);
                    final selected = _hue == h;
                    return GestureDetector(
                      onTap: () => setState(() => _hue = h),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? Colors.black : const Color(0xFF999999),
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Saturation row
              const Text(
                'Brightness',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _satSteps.map((s) {
                  final color = _hsvToSafe(_hue, s, _value);
                  final selected = _saturation == s;
                  return GestureDetector(
                    onTap: () => setState(() => _saturation = s),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? Colors.black : const Color(0xFF999999),
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Value/shade row
              const Text(
                'Shade',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _valSteps.map((v) {
                  final color = _hsvToSafe(_hue, _saturation, v);
                  final selected = _value == v;
                  return GestureDetector(
                    onTap: () => setState(() => _value = v),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? Colors.black : const Color(0xFF999999),
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Use button
              GestureDetector(
                onTap: () => Navigator.pop(context, _currentColor),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Use This Color',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
