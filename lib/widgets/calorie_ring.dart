import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Anello calorie ridisegnato sul mockup Home Final: stroke arrotondato,
/// centro con kcal rimanenti/in eccesso. CustomPainter invece di
/// CircularProgressIndicator per il "cap" arrotondato che l'indicator di
/// Material non offre.
class CalorieRing extends StatelessWidget {
  final double fraction; // 0..1, gia' clampata dal chiamante
  final bool isOverGoal;
  final String centerValue;
  final String centerLabel;
  final double size;

  const CalorieRing({
    super.key,
    required this.fraction,
    required this.isOverGoal,
    required this.centerValue,
    required this.centerLabel,
    this.size = 104,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color trackColor = scheme.surfaceContainerHighest;
    final Color fillColor = isOverGoal ? scheme.error : scheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              fraction: isOverGoal ? 1.0 : fraction,
              trackColor: trackColor,
              fillColor: fillColor,
              strokeWidth: size * 0.086,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                centerValue,
                style: TextStyle(
                  fontSize: size * 0.26,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size * 0.1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  _RingPainter({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (fraction <= 0) return;
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fillColor != fillColor;
}
