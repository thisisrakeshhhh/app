import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes Google/OSRM standard polyline strings into LatLng coordinates
/// with zero external package dependencies.
class PolylineDecoder {
  /// Decodes an encoded path string into a list of [LatLng].
  static List<LatLng> decode(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Calculates geodesic distance in meters between two coordinates (Haversine).
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Calculates the shortest perpendicular/segment distance from a point to a polyline.
  static double distanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return distanceMeters(
        point.latitude,
        point.longitude,
        polyline.first.latitude,
        polyline.first.longitude,
      );
    }

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];
      final d = _distanceToSegment(point, p1, p2);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  static double _distanceToSegment(LatLng p, LatLng v, LatLng w) {
    final l2 = (w.latitude - v.latitude) * (w.latitude - v.latitude) +
        (w.longitude - v.longitude) * (w.longitude - v.longitude);
    if (l2 == 0) {
      return distanceMeters(p.latitude, p.longitude, v.latitude, v.longitude);
    }
    // Projection factor t
    final t = math.max(
      0.0,
      math.min(
        1.0,
        ((p.latitude - v.latitude) * (w.latitude - v.latitude) +
                (p.longitude - v.longitude) * (w.longitude - v.longitude)) /
            l2,
      ),
    );
    final projLat = v.latitude + t * (w.latitude - v.latitude);
    final projLng = v.longitude + t * (w.longitude - v.longitude);
    return distanceMeters(p.latitude, p.longitude, projLat, projLng);
  }
}
