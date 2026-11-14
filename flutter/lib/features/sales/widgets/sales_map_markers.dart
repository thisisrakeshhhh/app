import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Efficiently renders and caches custom numbered shop markers,
/// warehouse/godown marker, directional GPS marker, and cluster badges.
class SalesMapMarkerCache {
  final Map<String, BitmapDescriptor> _cache = {};
  final Set<String> _inFlight = {};

  BitmapDescriptor? getCached(String key) => _cache[key];

  Future<void> prewarmShopMarkers({
    required int count,
    required VoidCallback onUpdated,
    int? nextPendingIndex,
    Set<int> visitedIndices = const {},
    Set<int> checkedInIndices = const {},
  }) async {
    bool anyNew = false;
    for (int i = 0; i < count; i++) {
      final stopNum = i + 1;
      final isVisited = visitedIndices.contains(i);
      final isCheckedIn = !isVisited && checkedInIndices.contains(i);
      final isNext = !isVisited && !isCheckedIn && nextPendingIndex == i;
      final key = _shopKey(
        stopNum,
        isVisited: isVisited,
        isCheckedIn: isCheckedIn,
        isNext: isNext,
      );
      if (_cache.containsKey(key) || _inFlight.contains(key)) continue;
      _inFlight.add(key);
      final icon = await _renderNumberedPin(
        label: '$stopNum',
        fillColor: isVisited
            ? const Color(0xFF059669) // Emerald Green
            : (isCheckedIn
                ? const Color(0xFF0284C7) // Sky Blue
                : (isNext ? const Color(0xFFF59E0B) : const Color(0xFFDC2626))), // Amber / Rose Red
        hasHighlightRing: isCheckedIn || isNext,
      );
      _cache[key] = icon;
      _inFlight.remove(key);
      anyNew = true;
    }
    if (anyNew) onUpdated();
  }

  Future<BitmapDescriptor> getGodownMarker() async {
    const key = 'godown_hub';
    if (_cache.containsKey(key)) return _cache[key]!;
    final icon = await _renderBadgeIcon(
      fillColor: const Color(0xFF0F172A),
      ringColor: Colors.white,
      glyph: 'G',
      size: 40,
    );
    _cache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> getClusterMarker(int count) async {
    final key = 'cluster_$count';
    if (_cache.containsKey(key)) return _cache[key]!;
    final icon = await _renderBadgeIcon(
      fillColor: const Color(0xFF1D4ED8),
      ringColor: Colors.white,
      glyph: '$count',
      size: 40,
    );
    _cache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> getRepBlueDot({required bool withHeadingCone}) async {
    final key = withHeadingCone ? 'rep_heading' : 'rep_dot';
    if (_cache.containsKey(key)) return _cache[key]!;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double size = 48.0;
    const center = Offset(size / 2, size / 2);

    if (withHeadingCone) {
      final conePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(size / 2, 4),
          center,
          [const Color(0x001A73E8), const Color(0x881A73E8)],
        );
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx - 12, 5)
        ..quadraticBezierTo(center.dx, 1, center.dx + 12, 5)
        ..close();
      canvas.drawPath(path, conePaint);
    }

    // Soft outer glow
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = const Color(0x381A73E8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Crisp white ring
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    // Royal blue core
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF1A73E8));
    // Inner white dot
    canvas.drawCircle(center, 2.0, Paint()..color = Colors.white);

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.bytes(data!.buffer.asUint8List());
    _cache[key] = icon;
    return icon;
  }

  static String shopKey(
    int stopNumber, {
    required bool isVisited,
    bool isCheckedIn = false,
    required bool isNext,
  }) =>
      _shopKey(
        stopNumber,
        isVisited: isVisited,
        isCheckedIn: isCheckedIn,
        isNext: isNext,
      );

  static String _shopKey(
    int stopNumber, {
    required bool isVisited,
    bool isCheckedIn = false,
    required bool isNext,
  }) {
    final state = isVisited ? 'v' : (isCheckedIn ? 'c' : (isNext ? 'n' : 'p'));
    return 'shop_${stopNumber}_$state';
  }

  Future<BitmapDescriptor> _renderNumberedPin({
    required String label,
    required Color fillColor,
    bool hasHighlightRing = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 36.0;
    const double height = 46.0;
    const center = Offset(width / 2, 15.0);
    const double r = 12.0;
    const tip = Offset(width / 2, 41.0);

    // 1. Next-Stop Glowing Pulse Ring
    if (hasHighlightRing) {
      canvas.drawCircle(
        center,
        r + 4.5,
        Paint()..color = fillColor.withValues(alpha: 0.20),
      );
      canvas.drawCircle(
        center,
        r + 2.0,
        Paint()..color = fillColor.withValues(alpha: 0.35),
      );
    }

    // 2. Ground Shadow under tip
    canvas.drawOval(
      Rect.fromCenter(center: Offset(tip.dx, tip.dy + 1.5), width: 12, height: 3.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 3. Smooth Seamless Teardrop Vector
    final pinPath = Path();
    const double tangentAngle = 0.65; // radians below horizontal
    final double rightTangX = center.dx + r * math.cos(tangentAngle);
    final double rightTangY = center.dy + r * math.sin(tangentAngle);
    final double leftTangX = center.dx - r * math.cos(tangentAngle);
    final double leftTangY = center.dy + r * math.sin(tangentAngle);

    pinPath.moveTo(center.dx, center.dy - r);
    pinPath.arcToPoint(
      Offset(rightTangX, rightTangY),
      radius: const Radius.circular(r),
      largeArc: false,
    );
    pinPath.cubicTo(
      rightTangX - 1.0, rightTangY + 7.0,
      tip.dx + 3.5, tip.dy - 4.5,
      tip.dx, tip.dy,
    );
    pinPath.cubicTo(
      tip.dx - 3.5, tip.dy - 4.5,
      leftTangX + 1.0, leftTangY + 7.0,
      leftTangX, leftTangY,
    );
    pinPath.arcToPoint(
      Offset(center.dx, center.dy - r),
      radius: const Radius.circular(r),
      largeArc: false,
    );
    pinPath.close();

    // 4. Subtle Pin Shadow
    canvas.drawPath(
      pinPath.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 5. Pin Fill with subtle gradient
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - r),
        tip,
        [
          fillColor,
          Color.lerp(fillColor, Colors.black, 0.15)!,
        ],
      );
    canvas.drawPath(pinPath, fillPaint);

    // 6. Crisp White Outer Stroke (1.5px)
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 7. Pure White Circular Inset Disc for Sequence Number
    const double innerR = 7.5;
    canvas.drawCircle(
      center,
      innerR,
      Paint()..color = Colors.white,
    );

    // 8. Stop Number Text in Small, Sleek, Refined Typography
    final textColor = Color.lerp(fillColor, Colors.black, 0.40)!;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: label.length > 2 ? 6.5 : (label.length == 2 ? 7.5 : 8.5),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final img = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _renderBadgeIcon({
    required Color fillColor,
    required Color ringColor,
    required String glyph,
    required double size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      Offset(center.dx, center.dy + 2),
      size * 0.44,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, size * 0.40, Paint()..color = ringColor);
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - size * 0.34),
        Offset(center.dx, center.dy + size * 0.34),
        [fillColor, Color.lerp(fillColor, Colors.black, 0.22)!],
      );
    canvas.drawCircle(center, size * 0.34, fillPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }
}
