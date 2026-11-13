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
            ? const Color(0xFF059669)
            : (isCheckedIn
                ? const Color(0xFF0284C7)
                : (isNext ? const Color(0xFFF59E0B) : const Color(0xFFDC2626))),
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
      size: 84,
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
      size: 88,
    );
    _cache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> getRepBlueDot({required bool withHeadingCone}) async {
    final key = withHeadingCone ? 'rep_heading' : 'rep_dot';
    if (_cache.containsKey(key)) return _cache[key]!;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double size = 96.0;
    const center = Offset(size / 2, size / 2);

    if (withHeadingCone) {
      final conePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(size / 2, 6),
          center,
          [const Color(0x001A73E8), const Color(0x881A73E8)],
        );
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx - 22, 10)
        ..quadraticBezierTo(center.dx, 2, center.dx + 22, 10)
        ..close();
      canvas.drawPath(path, conePaint);
    }

    // Soft outer glow
    canvas.drawCircle(
      center,
      26,
      Paint()
        ..color = const Color(0x381A73E8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Crisp white ring
    canvas.drawCircle(center, 18, Paint()..color = Colors.white);
    // Royal blue core
    canvas.drawCircle(center, 13, Paint()..color = const Color(0xFF1A73E8));
    // Inner white dot
    canvas.drawCircle(center, 3.5, Paint()..color = Colors.white);

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
    const double width = 84.0;
    const double height = 98.0;
    const center = Offset(width / 2, 38);

    if (hasHighlightRing) {
      canvas.drawCircle(
        center,
        35,
        Paint()..color = fillColor.withValues(alpha: 0.28),
      );
    }

    // Drop shadow
    canvas.drawCircle(
      const Offset(width / 2, 41),
      26,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Pointer triangle
    final pointer = Path()
      ..moveTo(center.dx - 11, 56)
      ..lineTo(center.dx + 11, 56)
      ..lineTo(center.dx, 88)
      ..close();
    canvas.drawPath(pointer, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 8, 55)
        ..lineTo(center.dx + 8, 55)
        ..lineTo(center.dx, 83)
        ..close(),
      Paint()..color = fillColor,
    );

    // White border circle
    canvas.drawCircle(center, 27, Paint()..color = Colors.white);
    // Colored circle
    canvas.drawCircle(center, 23, Paint()..color = fillColor);

    // Stop number text
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: label.length > 2 ? 19 : 23,
          fontWeight: FontWeight.w900,
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
      center,
      size * 0.42,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, size * 0.38, Paint()..color = ringColor);
    canvas.drawCircle(center, size * 0.32, Paint()..color = fillColor);

    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.28,
          fontWeight: FontWeight.w900,
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
