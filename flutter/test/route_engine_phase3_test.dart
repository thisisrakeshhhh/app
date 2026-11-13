import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/features/sales/routing/external_navigation_service.dart';
import 'package:lala_distributor/features/sales/routing/polyline_decoder.dart';
import 'package:lala_distributor/features/sales/routing/route_cache_repository.dart';
import 'package:lala_distributor/features/sales/routing/route_deviation_detector.dart';
import 'package:lala_distributor/features/sales/routing/route_engine_service.dart';
import 'package:lala_distributor/features/sales/routing/route_info_panel.dart';
import 'package:lala_distributor/features/sales/routing/route_models.dart';
import 'package:lala_distributor/features/sales/routing/route_provider.dart';
import 'package:lala_distributor/models/models.dart';

void main() {
  group('RouteFlow Phase 3 — Real Road Route Engine Unit Tests', () {
    // 1. Polyline decoder tests
    test('1. PolylineDecoder decodes standard encoded polyline cleanly', () {
      // Simple polyline encoded string
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final points = PolylineDecoder.decode(encoded);
      expect(points, isNotEmpty);
      expect(points.length, equals(3));
      expect(points.first.latitude, closeTo(38.5, 0.1));
      expect(points.first.longitude, closeTo(-120.2, 0.1));
    });

    test('2. PolylineDecoder Haversine distance and perpendicular distance to polyline', () {
      // 1 degree lat is ~111km
      final d = PolylineDecoder.distanceMeters(30.0, 76.0, 30.01, 76.0);
      expect(d, closeTo(1112.0, 50.0));

      final polyline = [
        const LatLng(30.0, 76.0),
        const LatLng(30.0, 76.01),
      ];
      // Point 50 meters north of line
      final dToLine = PolylineDecoder.distanceToPolyline(const LatLng(30.00045, 76.005), polyline);
      expect(dToLine, closeTo(50.0, 15.0));
    });

    // 2. Routing provider tests
    test('3. OsrmRouteProvider successfully parses road route response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                'distance': 2450.5,
                'duration': 360.0,
              }
            ],
          }),
          200,
        );
      });

      final provider = OsrmRouteProvider(client: mockClient);
      final leg = await provider.calculateLeg(
        origin: const LatLng(30.7225, 76.7620),
        destination: const LatLng(30.7300, 76.7700),
        originId: 'origin_1',
        destinationId: 'dest_1',
        destinationName: 'Punjab Kirana',
      );

      expect(leg.status, equals(RouteLegStatus.success));
      expect(leg.isRoadFollowing, isTrue);
      expect(leg.distanceMeters, equals(2450.5));
      expect(leg.durationSeconds, equals(360.0));
      expect(leg.geometry.length, equals(3));
      expect(leg.formattedDistance, equals('2.5 km'));
      expect(leg.formattedDuration, equals('6 min'));
    });

    test('4. OsrmRouteProvider falls back to honest approximate fallback on network failure', () async {
      final mockClient = MockClient((request) async => throw Exception('Connection timeout'));
      final provider = OsrmRouteProvider(client: mockClient);

      final leg = await provider.calculateLeg(
        origin: const LatLng(30.7225, 76.7620),
        destination: const LatLng(30.7300, 76.7700),
        originId: 'origin_1',
        destinationId: 'dest_1',
        destinationName: 'Aroma Super Store',
      );

      expect(leg.status, equals(RouteLegStatus.approximateFallback));
      expect(leg.isApproximate, isTrue);
      expect(leg.isRoadFollowing, isFalse);
      expect(leg.provider, equals('ApproximateFallback'));
    });

    // 3. Route cache repository tests
    test('5. RouteCacheRepository caches and retrieves legs accurately', () {
      final cache = RouteCacheRepository();
      final leg = RouteLeg(
        origin: const LatLng(30.7225, 76.7620),
        destination: const LatLng(30.7300, 76.7700),
        originId: 'orig',
        destinationId: 'dest',
        destinationName: 'Sharma General Store',
        geometry: const [LatLng(30.7225, 76.7620), LatLng(30.7300, 76.7700)],
        distanceMeters: 1200,
        durationSeconds: 180,
        status: RouteLegStatus.success,
        provider: 'OSRM',
        calculatedAt: DateTime.now(),
      );

      cache.putLeg(leg);
      expect(cache.count, equals(1));

      // Exact lookup
      final retrieved = cache.getLeg(30.7225, 76.7620, 30.7300, 76.7700);
      expect(retrieved, isNotNull);
      expect(retrieved!.status, equals(RouteLegStatus.cached));
      expect(retrieved.destinationName, equals('Sharma General Store'));

      // Lookup with slight 10m coordinate jitter matches cache
      final proximate = cache.getLeg(30.72251, 76.76201, 30.73001, 76.77001);
      expect(proximate, isNotNull);

      // Lookup in different city fails cache lookup
      final miss = cache.getLeg(26.2850, 73.0180, 26.2900, 73.0200);
      expect(miss, isNull);
    });

    // 4. GPS & Route Deviation Engine tests
    test('6. RouteDeviationDetector filters stationary jitter and detects consecutive off-route movement', () {
      final detector = RouteDeviationDetector(
        deviationThresholdMeters: 60.0,
        requiredConsecutiveObservations: 2,
        rerouteCooldown: const Duration(seconds: 1),
      );

      final polyline = [
        const LatLng(30.7200, 76.7600),
        const LatLng(30.7300, 76.7600),
      ];

      // Test 6a: Stationary device (< 1.2 m/s) does not show directional heading
      final stationaryPos = Position(
        longitude: 76.7600,
        latitude: 30.7250,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 90.0,
        headingAccuracy: 10.0,
        speed: 0.2, // Walking / standing jitter
        speedAccuracy: 0.1,
      );
      expect(RouteDeviationDetector.extractReliableHeading(stationaryPos), isNull);

      // Test 6b: Moving device (>= 1.2 m/s) with accurate heading returns heading
      final movingPos = Position(
        longitude: 76.7600,
        latitude: 30.7250,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 180.0,
        headingAccuracy: 15.0,
        speed: 4.5, // Driving speed
        speedAccuracy: 0.5,
      );
      expect(RouteDeviationDetector.extractReliableHeading(movingPos), equals(180.0));

      // Test 6c: Position on road polyline -> no deviation
      expect(detector.checkDeviation(pos: movingPos, activePolyline: polyline), isFalse);

      // Test 6d: First off-route position (120m away) -> returns false (needs 2 consecutive)
      final offRoute1 = Position(
        longitude: 76.7615, // ~140m east of line
        latitude: 30.7250,
        timestamp: DateTime.now(),
        accuracy: 12.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 90.0,
        headingAccuracy: 10.0,
        speed: 5.0,
        speedAccuracy: 0.5,
      );
      expect(detector.checkDeviation(pos: offRoute1, activePolyline: polyline), isFalse);

      // Second consecutive off-route position -> triggers true for rerouting
      final offRoute2 = Position(
        longitude: 76.7618,
        latitude: 30.7252,
        timestamp: DateTime.now(),
        accuracy: 12.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 90.0,
        headingAccuracy: 10.0,
        speed: 5.0,
        speedAccuracy: 0.5,
      );
      expect(detector.checkDeviation(pos: offRoute2, activePolyline: polyline), isTrue);
    });

    // 5. Route Engine Service tests
    test('7. RouteEngineService builds ordered beat route and aggregates distance & ETA', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                'distance': 1000.0,
                'duration': 180.0,
              }
            ],
          }),
          200,
        );
      });

      final service = RouteEngineService(
        provider: OsrmRouteProvider(client: mockClient),
      );

      final shops = [
        RetailerShop(
          id: 'shop_1',
          name: 'Punjab Kirana',
          ownerName: 'Gurpreet Singh',
          phone: '9876543210',
          address: 'Kharar Road',
          area: 'Sector 121',
          latitude: 30.7230,
          longitude: 76.7630,
          visitedToday: false,
          creditLimitPaise: 5000000,
          outstandingPaise: 120000,
        ),
        RetailerShop(
          id: 'shop_2',
          name: 'Aroma Super Store',
          ownerName: 'Aroma Group',
          phone: '9876543211',
          address: 'Sector 22',
          area: 'Sector 22',
          latitude: 30.7330,
          longitude: 76.7730,
          visitedToday: false,
          creditLimitPaise: 5000000,
          outstandingPaise: 0,
        ),
      ];

      final plan = await service.buildBeatRoute(
        repPosition: const LatLng(30.7200, 76.7600),
        assignedShops: shops,
        beatId: 'beat_chd',
        beatName: 'Chandigarh Beat',
      );

      expect(plan.legs.length, equals(2)); // Rep->Shop1, Shop1->Shop2
      expect(plan.totalStops, equals(2));
      expect(plan.completedStops, equals(0));
      expect(plan.remainingDistanceMeters, equals(2000.0));
      expect(plan.remainingDurationSeconds, equals(360.0));
      expect(plan.formattedRemainingDistance, equals('2.0 km'));
      expect(plan.formattedRemainingDuration, equals('6 min'));
      expect(plan.activeLeg!.destinationName, equals('Punjab Kirana'));

      // Test reroute active leg: preserves stop order
      final rerouted = await service.rerouteActiveLeg(
        newRepPosition: const LatLng(30.7210, 76.7610),
        nextShop: shops[0],
      );
      expect(rerouted, isNotNull);
      expect(rerouted!.legs.length, equals(2));
      expect(rerouted.activeLeg!.destinationName, equals('Punjab Kirana'));
    });

    // 6. External Navigation Service test
    test('8. ExternalNavigationService launches navigation intent safely', () async {
      final res = await ExternalNavigationService.launchTurnByTurn(
        latitude: 30.7230,
        longitude: 76.7630,
        destinationLabel: 'Punjab Kirana',
      );
      expect(res, isTrue);
    });

    // 7. RouteInfoPanel widget test
    testWidgets('9. RouteInfoPanel renders next stop, distance, ETA, and navigation button', (tester) async {
      final leg = RouteLeg(
        origin: const LatLng(30.7200, 76.7600),
        destination: const LatLng(30.7230, 76.7630),
        originId: 'rep',
        destinationId: 'shop_1',
        destinationName: 'Punjab Kirana',
        geometry: const [LatLng(30.7200, 76.7600), LatLng(30.7230, 76.7630)],
        distanceMeters: 2400,
        durationSeconds: 540,
        status: RouteLegStatus.success,
        provider: 'OSRM',
        calculatedAt: DateTime.now(),
      );

      final plan = BeatRoutePlan(
        beatId: 'beat_1',
        beatName: 'Chandigarh Beat',
        legs: [leg],
        totalStops: 5,
        completedStops: 1,
        updatedAt: DateTime.now(),
      );

      bool navTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteInfoPanel(
              plan: plan,
              isCalculating: false,
              onNavigatePressed: () => navTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('NEXT STOP'), findsOneWidget);
      expect(find.text('Punjab Kirana'), findsOneWidget);
      expect(find.text('2.4 km'), findsOneWidget);
      expect(find.text('9 min'), findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);
      expect(find.textContaining('4 of 5 stops left'), findsOneWidget);

      await tester.tap(find.text('Navigate'));
      await tester.pump();
      expect(navTapped, isTrue);
    });
  });
}
