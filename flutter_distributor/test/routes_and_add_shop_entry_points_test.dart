import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/screens/views/admin_subviews.dart';
import 'package:lala_distributor/services/api_service.dart';

class ZeroNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access strictly forbidden in offline tests');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = ZeroNetworkHttpOverrides();

  group('Part B4: Routes, Route Picker & Add Shop Entry Points', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const salesSession = UserSession(
      userId: 'usr_sales_imran',
      name: 'Imran Khan',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'SALES',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
          role: 'SALES',
          isActive: true,
        ),
      ],
    );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LocalRepository(db);
      api = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => salesSession,
      );
      await api.syncForTesting(seed: true);

      // Seed 2 distinct routes with route stops
      await repo.insertRoute(RouteEntry(
        id: 'route_sojati_01',
        name: 'Sojati Gate & Station Road',
        code: 'SOJ-01',
        dayOfWeek: 'Monday',
        isActive: true,
        createdAt: DateTime.now(),
      ));

      await repo.insertRoute(RouteEntry(
        id: 'route_sardarpura_02',
        name: 'Sardarpura C Road Beat',
        code: 'SAR-02',
        dayOfWeek: 'Tuesday',
        isActive: true,
        createdAt: DateTime.now(),
      ));
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Available routes load from database and default route matches sales representative assigned beat', () async {
      final routes = await api.getAvailableRoutes();
      expect(routes.length, greaterThanOrEqualTo(2));

      final defaultRoute = await api.getDefaultRouteForUser('usr_sales_imran');
      expect(defaultRoute, isNotNull);
      expect(defaultRoute!.id, equals('route_sojati_01'));
      expect(defaultRoute.name, contains('Sojati Gate'));
    });

    test('2. Geographic coordinate near an alternative beat triggers nearby-route suggestion without force-switching', () async {
      // Coordinates inside Sardarpura market (lat: 26.2805, lng: 73.0110)
      final suggestedRoute = await api.suggestNearbyRoute(
        latitude: 26.2805,
        longitude: 73.0110,
        currentRouteId: 'route_sojati_01',
      );

      expect(suggestedRoute, isNotNull);
      expect(suggestedRoute!.id, equals('route_sardarpura_02'));
      expect(suggestedRoute.name, contains('Sardarpura'));
    });

    test('3. Exact duplicate mobile check triggers exact confirmation flag with matched shop record', () async {
      final existingShop = api.retailers.first;

      final dupCheck = await api.checkShopDuplicates(
        phone: existingShop.phone,
        gstin: '',
        name: 'Completely Different Name Store',
        area: 'Different Area',
      );

      expect(dupCheck.hasDuplicate, isTrue);
      expect(dupCheck.type, equals(DuplicateType.exactMobile));
      expect(dupCheck.matchedShop, isNotNull);
      expect(dupCheck.matchedShop!.id, equals(existingShop.id));
      expect(dupCheck.requiresStrictConfirmation, isTrue);
    });

    test('4. Adding a new shop to a route preserves manual stop sequence at end of route', () async {
      final newShop = await api.quickAddShop(
        shopName: 'New Jalori Gate Mart',
        ownerName: 'Sunil Mehta',
        phone: '9829988771',
        routeId: 'route_sojati_01',
      );

      final stops = await repo.getRouteStops('route_sojati_01');
      expect(stops.isNotEmpty, isTrue);
      final lastStop = stops.last;
      expect(lastStop.retailerId, equals(newShop.id));
      expect(lastStop.stopSequence, equals(stops.length));
    });

    testWidgets('5. Owner AdminRetailersView renders + Add Retailer button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminRetailersView(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('admin_add_retailer_btn')), findsOneWidget);
      expect(find.text('+ Add Retailer'), findsOneWidget);
    });
  });
}
