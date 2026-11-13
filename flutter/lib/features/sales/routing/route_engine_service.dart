import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lala_distributor/models/models.dart';
import 'route_cache_repository.dart';
import 'route_models.dart';
import 'route_provider.dart';

/// Central business orchestrator for FMCG beat routing.
///
/// Preserves the owner's assigned stop sequence as authoritative truth.
/// Generates:
/// 1. Rep GPS -> Next Pending Shop (Active Leg)
/// 2. Next Pending Shop -> Stop i+1 -> ... -> Stop N (Remaining Planned Beat Legs)
///
/// Caches successful route legs, handles intelligent rerouting, and aggregates
/// real road distance and driving ETA.
class RouteEngineService {
  final RouteProvider _provider;
  final RouteCacheRepository _cache;

  BeatRoutePlan? _currentPlan;
  bool _isCalculating = false;

  RouteEngineService({
    RouteProvider? provider,
    RouteCacheRepository? cache,
  })  : _provider = provider ?? OsrmRouteProvider(),
        _cache = cache ?? RouteCacheRepository();

  BeatRoutePlan? get currentPlan => _currentPlan;
  bool get isCalculating => _isCalculating;
  RouteCacheRepository get cache => _cache;

  /// Builds or recalculates the ordered road route for [assignedShops] starting from [repPosition].
  Future<BeatRoutePlan> buildBeatRoute({
    required LatLng repPosition,
    required List<RetailerShop> assignedShops,
    required String beatId,
    required String beatName,
    WarehouseHub? godown,
  }) async {
    _isCalculating = true;

    // Filter shops with valid coordinates while strictly preserving sequence
    final locatedShops = assignedShops
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    if (locatedShops.isEmpty) {
      _isCalculating = false;
      _currentPlan = BeatRoutePlan(
        beatId: beatId,
        beatName: beatName,
        legs: const [],
        totalStops: 0,
        completedStops: 0,
        updatedAt: DateTime.now(),
      );
      return _currentPlan!;
    }

    final completedCount = locatedShops.where((s) => s.visitedToday).length;

    // Identify the next pending stop index
    int nextPendingIdx = -1;
    for (int i = 0; i < locatedShops.length; i++) {
      if (!locatedShops[i].visitedToday && !locatedShops[i].isCheckedIn) {
        nextPendingIdx = i;
        break;
      }
    }
    // If all are visited or checked in, fallback to last stop or checked in
    if (nextPendingIdx == -1) {
      for (int i = 0; i < locatedShops.length; i++) {
        if (!locatedShops[i].visitedToday) {
          nextPendingIdx = i;
          break;
        }
      }
    }

    final legs = <RouteLeg>[];

    // If there is a next pending stop, calculate Active Leg: Rep GPS -> Next Shop
    if (nextPendingIdx != -1) {
      final targetShop = locatedShops[nextPendingIdx];
      final targetCoord = LatLng(targetShop.latitude!, targetShop.longitude!);

      final activeLeg = await _calculateOrGetCachedLeg(
        origin: repPosition,
        destination: targetCoord,
        originId: 'rep_live_gps',
        destinationId: targetShop.id,
        destinationName: targetShop.name,
      );
      legs.add(activeLeg);

      // Remaining planned legs: Next Shop -> Next+1 -> ... -> Last Shop
      LatLng previousCoord = targetCoord;
      String previousId = targetShop.id;

      for (int i = nextPendingIdx + 1; i < locatedShops.length; i++) {
        final nextShop = locatedShops[i];
        final nextCoord = LatLng(nextShop.latitude!, nextShop.longitude!);

        final leg = await _calculateOrGetCachedLeg(
          origin: previousCoord,
          destination: nextCoord,
          originId: previousId,
          destinationId: nextShop.id,
          destinationName: nextShop.name,
        );
        legs.add(leg);

        previousCoord = nextCoord;
        previousId = nextShop.id;
      }
    }

    _currentPlan = BeatRoutePlan(
      beatId: beatId,
      beatName: beatName,
      legs: legs,
      totalStops: locatedShops.length,
      completedStops: completedCount,
      updatedAt: DateTime.now(),
    );

    _isCalculating = false;
    return _currentPlan!;
  }

  /// Recalculates ONLY the active leg (Rep GPS -> Next Shop) during deviation,
  /// preserving all remaining scheduled legs untouched.
  Future<BeatRoutePlan?> rerouteActiveLeg({
    required LatLng newRepPosition,
    required RetailerShop nextShop,
  }) async {
    if (_currentPlan == null) return null;

    final targetCoord = LatLng(nextShop.latitude!, nextShop.longitude!);
    final newActiveLeg = await _provider.calculateLeg(
      origin: newRepPosition,
      destination: targetCoord,
      originId: 'rep_reroute_gps',
      destinationId: nextShop.id,
      destinationName: nextShop.name,
    );

    if (newActiveLeg.isRoadFollowing) {
      _cache.putLeg(newActiveLeg);
    }

    final updatedLegs = <RouteLeg>[newActiveLeg];
    if (_currentPlan!.legs.length > 1) {
      updatedLegs.addAll(_currentPlan!.legs.sublist(1));
    }

    _currentPlan = BeatRoutePlan(
      beatId: _currentPlan!.beatId,
      beatName: _currentPlan!.beatName,
      legs: updatedLegs,
      totalStops: _currentPlan!.totalStops,
      completedStops: _currentPlan!.completedStops,
      updatedAt: DateTime.now(),
    );

    return _currentPlan;
  }

  Future<RouteLeg> _calculateOrGetCachedLeg({
    required LatLng origin,
    required LatLng destination,
    required String originId,
    required String destinationId,
    required String destinationName,
  }) async {
    // 1. Check cache first
    final cached = _cache.getLeg(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (cached != null) return cached;

    // 2. Query routing provider
    final leg = await _provider.calculateLeg(
      origin: origin,
      destination: destination,
      originId: originId,
      destinationId: destinationId,
      destinationName: destinationName,
    );

    // 3. Cache if successful road geometry
    if (leg.isRoadFollowing) {
      _cache.putLeg(leg);
    }

    return leg;
  }
}
