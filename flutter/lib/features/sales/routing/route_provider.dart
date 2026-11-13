import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'polyline_decoder.dart';
import 'route_models.dart';

/// Abstract contract for calculating road-following routes.
abstract class RouteProvider {
  String get name;

  /// Calculates a single road leg from [origin] to [destination].
  Future<RouteLeg> calculateLeg({
    required LatLng origin,
    required LatLng destination,
    required String originId,
    required String destinationId,
    required String destinationName,
  });
}

/// Real road-following routing provider using Open Source Routing Machine (OSRM).
/// Fully free, no paid API keys required, works reliably across Indian roads.
class OsrmRouteProvider implements RouteProvider {
  final http.Client _client;
  final String baseUrl;

  OsrmRouteProvider({
    http.Client? client,
    this.baseUrl = 'https://router.project-osrm.org',
  })  : _client = client ?? http.Client();

  @override
  String get name => 'OSRM';

  @override
  Future<RouteLeg> calculateLeg({
    required LatLng origin,
    required LatLng destination,
    required String originId,
    required String destinationId,
    required String destinationName,
  }) async {
    // OSRM expects coordinates in lng,lat format
    final url = Uri.parse(
      '$baseUrl/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=polyline',
    );

    try {
      final response = await _client.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final geomStr = route['geometry'] as String;
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();
          final decodedGeometry = PolylineDecoder.decode(geomStr);

          return RouteLeg(
            origin: origin,
            destination: destination,
            originId: originId,
            destinationId: destinationId,
            destinationName: destinationName,
            geometry: decodedGeometry.isNotEmpty ? decodedGeometry : [origin, destination],
            distanceMeters: distance,
            durationSeconds: duration,
            status: RouteLegStatus.success,
            provider: name,
            calculatedAt: DateTime.now(),
          );
        }
      }
    } catch (_) {
      // Network failure, timeout, or unreachable
    }

    // Honest Approximate Fallback when server cannot be reached
    final straightDist = PolylineDecoder.distanceMeters(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    // Estimated road distance in city traffic: ~1.28x Manhattan factor, 22 km/h average speed
    final roadEstimateM = straightDist * 1.28;
    final durationEstimateS = (roadEstimateM / (22 * 1000 / 3600));

    return RouteLeg(
      origin: origin,
      destination: destination,
      originId: originId,
      destinationId: destinationId,
      destinationName: destinationName,
      geometry: [origin, destination],
      distanceMeters: roadEstimateM,
      durationSeconds: durationEstimateS,
      status: RouteLegStatus.approximateFallback,
      provider: 'ApproximateFallback',
      calculatedAt: DateTime.now(),
    );
  }
}
