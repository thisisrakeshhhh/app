import 'polyline_decoder.dart';
import 'route_models.dart';

/// In-memory and persistent-ready route leg cache.
class RouteCacheRepository {
  final Map<String, RouteLeg> _memoryCache = {};

  /// Generates a normalized leg cache key.
  static String makeKey(double origLat, double origLng, double destLat, double destLng) {
    // 4 decimals precision (~11 meters)
    final olat = origLat.toStringAsFixed(4);
    final olng = origLng.toStringAsFixed(4);
    final dlat = destLat.toStringAsFixed(4);
    final dlng = destLng.toStringAsFixed(4);
    return 'leg_${olat}_${olng}__${dlat}_$dlng';
  }

  /// Looks up a cached leg matching coordinates within ~50 meters.
  RouteLeg? getLeg(double origLat, double origLng, double destLat, double destLng) {
    final exactKey = makeKey(origLat, origLng, destLat, destLng);
    final cached = _memoryCache[exactKey];
    if (cached != null) return cached;

    // Proximity search within 60 meters
    for (final leg in _memoryCache.values) {
      final dOrig = PolylineDecoder.distanceMeters(
        origLat,
        origLng,
        leg.origin.latitude,
        leg.origin.longitude,
      );
      final dDest = PolylineDecoder.distanceMeters(
        destLat,
        destLng,
        leg.destination.latitude,
        leg.destination.longitude,
      );
      if (dOrig <= 60.0 && dDest <= 60.0) {
        return leg;
      }
    }
    return null;
  }

  /// Stores a successfully calculated road leg in cache.
  /// Approximate fallback legs are never stored in the road geometry cache.
  void putLeg(RouteLeg leg) {
    if (!leg.isRoadFollowing) return;
    final key = makeKey(
      leg.origin.latitude,
      leg.origin.longitude,
      leg.destination.latitude,
      leg.destination.longitude,
    );
    // Mark as cached status if it came from provider success
    final storedLeg = RouteLeg(
      origin: leg.origin,
      destination: leg.destination,
      originId: leg.originId,
      destinationId: leg.destinationId,
      destinationName: leg.destinationName,
      geometry: leg.geometry,
      distanceMeters: leg.distanceMeters,
      durationSeconds: leg.durationSeconds,
      status: RouteLegStatus.cached,
      provider: leg.provider,
      calculatedAt: leg.calculatedAt,
    );
    _memoryCache[key] = storedLeg;
  }

  void clear() => _memoryCache.clear();
  int get count => _memoryCache.length;
}
