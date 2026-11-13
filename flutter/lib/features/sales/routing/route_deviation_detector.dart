import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'polyline_decoder.dart';

/// Detects meaningful route deviation and filters GPS drift.
class RouteDeviationDetector {
  /// Minimum distance in meters from active road polyline to trigger off-route evaluation.
  final double deviationThresholdMeters;

  /// Number of consecutive off-route readings required to confirm actual deviation.
  final int requiredConsecutiveObservations;

  /// Cooldown between reroute events to prevent request spamming.
  final Duration rerouteCooldown;

  int _consecutiveOffRouteCount = 0;
  DateTime? _lastRerouteTime;

  RouteDeviationDetector({
    this.deviationThresholdMeters = 60.0,
    this.requiredConsecutiveObservations = 2,
    this.rerouteCooldown = const Duration(seconds: 15),
  });

  /// Evaluates whether the GPS position is a reliable fix.
  static bool isReliableGps(Position pos) {
    // Prefer accuracy <= 35m
    if (pos.accuracy > 35.0) return false;
    // Discard zero/null coordinates
    if (pos.latitude == 0.0 && pos.longitude == 0.0) return false;
    return true;
  }

  /// Evaluates whether the device is moving fast enough for reliable directional heading.
  static bool isReliableMovement(Position pos) {
    // Minimum 1.2 m/s (~4.3 km/h) to filter compass drift/standing jitter
    return pos.speed >= 1.2;
  }

  /// Extracts reliable heading, or null if stationary / compass jittering.
  static double? extractReliableHeading(Position pos) {
    if (!isReliableMovement(pos)) return null;
    if (pos.heading >= 0 && pos.headingAccuracy > 0 && pos.headingAccuracy <= 45.0) {
      return pos.heading;
    }
    return null;
  }

  /// Checks if [pos] deviates from the active road [polyline].
  /// Returns `true` only when consecutive reliable deviations occur and cooldown has passed.
  bool checkDeviation({
    required Position pos,
    required List<LatLng> activePolyline,
  }) {
    if (activePolyline.isEmpty) return false;
    if (!isReliableGps(pos)) return false;

    // Check cooldown
    final now = DateTime.now();
    if (_lastRerouteTime != null && now.difference(_lastRerouteTime!) < rerouteCooldown) {
      return false;
    }

    final currentPoint = LatLng(pos.latitude, pos.longitude);
    final distanceToRoad = PolylineDecoder.distanceToPolyline(currentPoint, activePolyline);

    if (distanceToRoad >= deviationThresholdMeters) {
      _consecutiveOffRouteCount++;
      if (_consecutiveOffRouteCount >= requiredConsecutiveObservations) {
        _consecutiveOffRouteCount = 0;
        _lastRerouteTime = now;
        return true;
      }
    } else {
      // Back on route or close enough
      _consecutiveOffRouteCount = 0;
    }

    return false;
  }

  void reset() {
    _consecutiveOffRouteCount = 0;
    _lastRerouteTime = null;
  }
}
