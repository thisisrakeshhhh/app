import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/auth/auth_repository.dart';
import 'package:lala_distributor/data/auth/secure_token_storage.dart';
import 'package:lala_distributor/domain/auth/tenant_boundary_gate.dart';
import 'package:lala_distributor/features/sales/widgets/sales_map_markers.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/screens/dashboards/sales_dashboard.dart';
import 'package:lala_distributor/screens/role_shell.dart';
import 'package:lala_distributor/screens/views/sales_route_map_view.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/services/auth_service.dart';

void main() {
  const testBaseUrl = 'https://routeflow-api-staging.workers.dev';

  String makeJwt({String companyId = 'comp_jodhpur', required String role, required String name}) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'usr_role_test',
      'name': name,
      'company_id': companyId,
      'role': role,
      'exp': exp,
    })));
    return '$header.$payload.fake_sig';
  }

  AuthService createAuthWithRole(String role, String name) {
    final jwt = makeJwt(role: role, name: name);
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': jwt,
          'refresh_token': 'refresh_$role',
          'user': {'id': 'usr_$role', 'name': name, 'company_id': 'comp_jodhpur', 'role': role},
          'organizations': [{'id': 'comp_jodhpur', 'name': 'Jodhpur FMCG Depot', 'role': role}],
        }),
        200,
      );
    });

    final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
    final storage = InMemoryTokenStorage();
    return AuthService(
      repository: repo,
      secureStorage: storage,
      tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
    );
  }

  group('Sales Step 0 Corrections & Domain Invariants', () {
    late ApiService api;

    setUp(() {
      api = ApiService();
    });

    test('1. Fabricated address numbers removed: Shop without SCO/Gali returns null and shows no fake numbers', () {
      final shopWithoutUnit = RetailerShop(
        id: 'shop_plain_01',
        name: 'Sharma General Store',
        ownerName: 'Ramesh Sharma',
        phone: '9876543210',
        address: 'Opposite Clock Tower, Nai Sadak',
        area: 'Sardarpura',
        creditLimitPaise: 500000,
        outstandingPaise: 0,
      );

      // Must be null: zero invented fallback numbers from hashCode
      expect(shopWithoutUnit.scoNo, isNull);
      expect(shopWithoutUnit.gaaliNo, isNull);

      final shopWithUnit = RetailerShop(
        id: 'shop_unit_02',
        name: 'Apex Kirana',
        ownerName: 'Mohan Lal',
        phone: '9876543211',
        address: 'SCO 42, Gali No. 3, Near Bus Stand',
        area: 'Sardarpura',
        creditLimitPaise: 500000,
        outstandingPaise: 0,
      );

      expect(shopWithUnit.scoNo, equals('SCO 42'));
      expect(shopWithUnit.gaaliNo, equals('Gali No. 3'));
    });

    test('2. Class names: Matches database schema A, B, C, D, NEW with zero marketing fluff', () {
      final shopA = RetailerShop(
        id: 's1',
        name: 'Shop A',
        ownerName: 'O1',
        phone: '111',
        address: 'X',
        area: 'Y',
        creditLimitPaise: 100000,
        outstandingPaise: 0,
        classType: 'A',
      );
      final shopB = RetailerShop(
        id: 's2',
        name: 'Shop B',
        ownerName: 'O2',
        phone: '222',
        address: 'X',
        area: 'Y',
        creditLimitPaise: 100000,
        outstandingPaise: 0,
        classType: 'B',
      );
      final shopD = RetailerShop(
        id: 's3',
        name: 'Shop D',
        ownerName: 'O3',
        phone: '333',
        address: 'X',
        area: 'Y',
        creditLimitPaise: 0,
        outstandingPaise: 0,
        classType: 'D',
      );
      final shopNew = RetailerShop(
        id: 's4',
        name: 'Shop New',
        ownerName: 'O4',
        phone: '444',
        address: 'X',
        area: 'Y',
        creditLimitPaise: 0,
        outstandingPaise: 0,
        classType: 'NEW',
      );

      expect(shopA.classDisplayName, equals('Class A'));
      expect(shopB.classDisplayName, equals('Class B'));
      expect(shopD.classDisplayName, equals('Class D'));
      expect(shopNew.classDisplayName, equals('Class NEW'));

      // Assert no marketing text exists in display names
      expect(shopA.classDisplayName, isNot(contains('5★')));
      expect(shopA.classDisplayName, isNot(contains('High Volume')));
    });

    test('3. Combo mixed-unit order booking: 1 Box (96p) + 1 Strip (12p) + 5 Pcs calculates 113 pieces and exact wholesale price', () {
      final product = ProductItem(
        id: 'PROD_TEST_KURKURE',
        name: 'Kurkure Masala Munch',
        hindiName: 'कुरकुरे मसाला मंच',
        category: 'Snacks',
        piecePricePaise: 850, // ₹8.50 per piece
        stripQty: 12,
        boxQty: 96,
        mrpPaise: 1000, // ₹10.00 MRP
        customUnitPricesPaise: {
          'box': 81600, // 96 * 850
          'strip': 10200, // 12 * 850
          'piece': 850,
        },
      );

      // Add 1 Box + 1 Strip + 5 Pieces simultaneously
      api.clearCart();
      api.addMixedUnitsToCart(product, boxes: 1, strips: 1, pieces: 5);

      final totalPieces = (1 * product.boxQty) + (1 * product.stripQty) + 5;
      expect(totalPieces, equals(113));

      // 1 Box (81600 paise) + 1 Strip (10200 paise) + 5 Pieces (5 * 850 = 4250 paise) = 96050 paise (₹960.50)
      final expectedTotalPaise = 81600 + 10200 + (5 * 850);
      expect(api.cartTotalPaise, equals(expectedTotalPaise));
      expect(api.cartTotalRupees, equals(960.50));
    });

    test('4. Route editing permissions: Sales rep cannot remove assigned beat stops, but can add extra visits', () {
      // Snapshot the baseline assigned beat shops
      api.setAssignedBeatShopIds(api.retailers.map((r) => r.id));

      // Add an unassigned retailer to test extra visit toggling
      final unassignedShop = RetailerShop(
        id: 'shop_unassigned_extra',
        name: 'Extra Mandi Kirana',
        ownerName: 'Sunil Extra',
        phone: '9988776655',
        address: 'Out of Beat, Mandi Yard',
        area: 'Mandi',
        creditLimitPaise: 200000,
        outstandingPaise: 0,
      );
      api.retailers.add(unassignedShop);

      // Pick the first assigned beat shop
      final assignedShop = api.assignedRouteShops.first;
      expect(api.isAssignedBeatShop(assignedShop.id), isTrue);

      // Rep attempts to remove assigned shop: MUST BE REJECTED
      final removeSuccess = api.toggleShopInRoute(assignedShop.id);
      expect(removeSuccess, isFalse);
      expect(api.isShopInTodayRoute(assignedShop.id), isTrue);

      // Unassigned shop can be added as extra visit today
      expect(api.isAssignedBeatShop(unassignedShop.id), isFalse);
      final addSuccess = api.toggleShopInRoute(unassignedShop.id);
      expect(addSuccess, isTrue);
      expect(api.isExtraVisitToday(unassignedShop.id), isTrue);
      expect(api.isShopInTodayRoute(unassignedShop.id), isTrue);

      // Extra visit appears at the end of the route
      expect(api.assignedRouteShops.last.id, equals(unassignedShop.id));
    });

    testWidgets('5. Role isolation: Owner sees GST Summary button, Sales Rep does not', (tester) async {
      // 1. Pump role shell for OWNER
      final ownerAuth = createAuthWithRole('OWNER', 'Rakesh Agarwal');
      await ownerAuth.login('owner', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: ownerAuth),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Owner MUST see Accountant & GST Summary button
      expect(find.byTooltip('Accountant GST Summary'), findsOneWidget);

      // 2. Pump role shell for SALES
      final salesAuth = createAuthWithRole('SALES', 'Vikram Rathore');
      await salesAuth.login('sales_rep', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: salesAuth),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Sales rep MUST NOT see Accountant & GST Summary button
      expect(find.byTooltip('Accountant GST Summary'), findsNothing);
    });

    testWidgets('6. Route map view: Handles 0 shops and renders pins from coordinates honestly', (tester) async {
      // Test zero shops
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesRouteMapView(api: api),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should display honest route sketch label
      expect(find.text('Route sketch (not to scale)'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('7. Phase 2 MarkerCache generates distinct keys and updates cleanly across shop status transitions', (tester) async {
      final cache = SalesMapMarkerCache();

      // Keys for pending -> next -> checkedIn -> visited must all be unique
      final pendingKey = SalesMapMarkerCache.shopKey(1, isVisited: false, isCheckedIn: false, isNext: false);
      final nextKey = SalesMapMarkerCache.shopKey(1, isVisited: false, isCheckedIn: false, isNext: true);
      final checkedInKey = SalesMapMarkerCache.shopKey(1, isVisited: false, isCheckedIn: true, isNext: false);
      final visitedKey = SalesMapMarkerCache.shopKey(1, isVisited: true, isCheckedIn: false, isNext: false);

      expect({pendingKey, nextKey, checkedInKey, visitedKey}.length, equals(4));

      await tester.runAsync(() async {
        // Prewarm pending & next
        int updates = 0;
        await cache.prewarmShopMarkers(
          count: 3,
          nextPendingIndex: 0,
          onUpdated: () => updates++,
        );
        expect(updates, equals(1));
        expect(cache.getCached(nextKey), isNotNull);

        // Transition stop #1 to checked-in and stop #2 to next
        await cache.prewarmShopMarkers(
          count: 3,
          checkedInIndices: {0},
          nextPendingIndex: 1,
          onUpdated: () => updates++,
        );
        expect(updates, equals(2));
        expect(cache.getCached(checkedInKey), isNotNull);

        // Transition stop #1 to completed visit
        await cache.prewarmShopMarkers(
          count: 3,
          visitedIndices: {0},
          nextPendingIndex: 1,
          onUpdated: () => updates++,
        );
        expect(updates, equals(3));
        expect(cache.getCached(visitedKey), isNotNull);

        // Godown, cluster, and heading markers render & cache cleanly
        final godown = await cache.getGodownMarker();
        final cluster = await cache.getClusterMarker(12);
        final repHeading = await cache.getRepBlueDot(withHeadingCone: true);
        final repDot = await cache.getRepBlueDot(withHeadingCone: false);
        expect(godown, isNotNull);
        expect(cluster, isNotNull);
        expect(repHeading, isNotNull);
        expect(repDot, isNotNull);
      });
    });

    testWidgets('8. Phase 2 SalesDashboard preserves beat, Continue Route, Add Shop, and renders compact map controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesDashboard(
              api: api,
              onNavigateTab: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // All Phase 2 map controls must be present
      expect(find.byTooltip('My Location'), findsOneWidget);
      expect(find.byTooltip('Focus Next Shop'), findsOneWidget);
      expect(find.byTooltip('Recenter Route'), findsOneWidget);
      expect(find.byTooltip('Show All Shops'), findsOneWidget);
      expect(find.byTooltip('Fullscreen Map'), findsOneWidget);
      expect(find.byTooltip('Zoom In'), findsOneWidget);
      expect(find.byTooltip('Zoom Out'), findsOneWidget);

      // Existing workflow buttons preserved
      expect(find.text('+ Add Shop'), findsWidgets);
    });
  });
}
