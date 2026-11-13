import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Calculation status for an individual route leg.
enum RouteLegStatus {
  success,
  cached,
  approximateFallback,
  failed,
}

/// Represents a single road leg connecting an origin to a destination.
class RouteLeg {
  final LatLng origin;
  final LatLng destination;
  final String originId;
  final String destinationId;
  final String destinationName;
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final RouteLegStatus status;
  final String provider;
  final DateTime calculatedAt;

  const RouteLeg({
    required this.origin,
    required this.destination,
    required this.originId,
    required this.destinationId,
    required this.destinationName,
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.status,
    required this.provider,
    required this.calculatedAt,
  });

  bool get isRoadFollowing => status == RouteLegStatus.success || status == RouteLegStatus.cached;
  bool get isApproximate => status == RouteLegStatus.approximateFallback;

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final mins = (durationSeconds / 60).round();
    if (mins < 1) return '< 1 min';
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '${hours}h ${remMins}m';
  }

  Map<String, dynamic> toJson() => {
    'originLat': origin.latitude,
    'originLng': origin.longitude,
    'destLat': destination.latitude,
    'destLng': destination.longitude,
    'originId': originId,
    'destinationId': destinationId,
    'destinationName': destinationName,
    'geometry': geometry.map((p) => [p.latitude, p.longitude]).toList(),
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'status': status.name,
    'provider': provider,
    'calculatedAt': calculatedAt.toIso8601String(),
  };

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
    origin: LatLng(json['originLat'] as double, json['originLng'] as double),
    destination: LatLng(json['destLat'] as double, json['destLng'] as double),
    originId: json['originId'] as String,
    destinationId: json['destinationId'] as String,
    destinationName: json['destinationName'] as String,
    geometry: (json['geometry'] as List)
        .map((coord) => LatLng((coord[0] as num).toDouble(), (coord[1] as num).toDouble()))
        .toList(),
    distanceMeters: (json['distanceMeters'] as num).toDouble(),
    durationSeconds: (json['durationSeconds'] as num).toDouble(),
    status: RouteLegStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => RouteLegStatus.cached,
    ),
    provider: json['provider'] as String,
    calculatedAt: DateTime.parse(json['calculatedAt'] as String),
  );
}

/// Represents the overall route for the salesperson's daily beat.
class BeatRoutePlan {
  final String beatId;
  final String beatName;
  final List<RouteLeg> legs;
  final int totalStops;
  final int completedStops;
  final DateTime updatedAt;

  const BeatRoutePlan({
    required this.beatId,
    required this.beatName,
    required this.legs,
    required this.totalStops,
    required this.completedStops,
    required this.updatedAt,
  });

  /// The active leg currently to be travelled (towards the next pending shop).
  RouteLeg? get activeLeg => legs.isEmpty ? null : legs.first;

  /// Total remaining road distance across all pending legs.
  double get remainingDistanceMeters => legs.fold(0.0, (sum, leg) => sum + leg.distanceMeters);

  /// Total remaining estimated driving duration across all pending legs.
  double get remainingDurationSeconds => legs.fold(0.0, (sum, leg) => sum + leg.durationSeconds);

  String get formattedRemainingDistance {
    final dist = remainingDistanceMeters;
    if (dist < 1000) {
      return '${dist.toStringAsFixed(0)} m';
    }
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  String get formattedRemainingDuration {
    final mins = (remainingDurationSeconds / 60).round();
    if (mins < 1) return '< 1 min';
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '${hours}h ${remMins}m';
  }
}
