import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/l10n/app_language.dart';
import 'package:lala_distributor/l10n/language_controller.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/screens/dashboards/sales_dashboard.dart';
import 'package:lala_distributor/screens/views/sales_route_map_view.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  group('Sales Route Map & In-Map CRUD Operations', () {
    late ApiService api;

    setUp(() {
      api = ApiService();
    });

    test('1. Sardarpura & Nai Sadak Route shops have real coordinates and authentic area addresses', () {
      final assigned = api.assignedRouteShops;
      expect(assigned.length, equals(4));

      // Stop A: Nai Sadak (Clock Tower)
      expect(assigned[0].area, equals('Nai Sadak'));
      expect(assigned[0].address, contains('Nai Sadak'));
      expect(assigned[0].latitude, equals(26.2945));
      expect(assigned[0].longitude, equals(73.0240));

      // Stop B: Sardarpura
      expect(assigned[1].area, equals('Sardarpura'));
      expect(assigned[1].address, contains('B-Road'));
      expect(assigned[1].latitude, equals(26.2750));
      expect(assigned[1].longitude, equals(73.0080));

      // Stop C: Nai Sadak
      expect(assigned[2].area, equals('Nai Sadak'));
      expect(assigned[2].address, contains('Nai Sadak'));
      expect(assigned[2].latitude, equals(26.2915));
      expect(assigned[2].longitude, equals(73.0215));

      // Stop D: Sardarpura
      expect(assigned[3].area, equals('Sardarpura'));
      expect(assigned[3].address, contains('4th C Road'));
      expect(assigned[3].latitude, equals(26.2810));
      expect(assigned[3].longitude, equals(73.0115));
    });

    test('2. In-Map CRUD operations on ApiService: Add, Update, Remove from Beat, Delete permanently', () async {
      expect(api.assignedRouteShops.length, equals(4));

      // CREATE / ADD: Add a new shop to beat
      final newShop = RetailerShop(
        id: 'ret_test_sardar_05',
        name: 'New Sardarpura Mart',
        ownerName: 'Kailash Choudhary',
        phone: '+91 98299 11223',
        address: 'Plot 45, 5th B Road',
        area: 'Sardarpura',
        latitude: 26.2790,
        longitude: 73.0105,
        creditLimitPaise: 0,
        outstandingPaise: 0,
      );
      api.retailers.add(newShop);
      api.addShopToTodayBeat(newShop.id);

      expect(api.assignedRouteShops.length, equals(5));
      expect(api.isAssignedBeatShop('ret_test_sardar_05'), isTrue);

      // UPDATE: Update retailer details
      await api.updateRetailerDetails(
        shopId: 'ret_test_sardar_05',
        name: 'New Sardarpura Supermarket',
        ownerName: 'Kailash C.',
        phone: '+91 98299 99999',
        address: 'Plot 45, Main 5th B Road',
        area: 'Sardarpura',
      );

      final updated = api.retailers.firstWhere((r) => r.id == 'ret_test_sardar_05');
      expect(updated.name, equals('New Sardarpura Supermarket'));
      expect(updated.ownerName, equals('Kailash C.'));
      expect(updated.phone, equals('+91 98299 99999'));

      // DELETE FROM BEAT: Remove from today's active route
      api.removeShopFromTodayBeat('ret_test_sardar_05');
      expect(api.assignedRouteShops.length, equals(4));
      expect(api.isAssignedBeatShop('ret_test_sardar_05'), isFalse);

      // DELETE PERMANENTLY: Deletes from retailers completely
      await api.deleteRetailer('ret_test_sardar_05');
      expect(api.retailers.any((r) => r.id == 'ret_test_sardar_05'), isFalse);
    });

    testWidgets('3. SalesDashboard displays embedded map under navbar with "4 shops assigned beat" and Sardarpura & Nai Sadak Route', (tester) async {
      await tester.pumpWidget(
        LanguageScope(
          controller: LanguageController(initialLanguage: AppLanguage.en),
          child: MaterialApp(
            home: Scaffold(
              body: SalesDashboard(
                api: api,
                onNavigateTab: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check embedded map canvas and sketch label
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Route sketch (not to scale)'), findsOneWidget);

      // Check Beat header and dynamic "4 shops assigned beat" badge
      expect(find.text("TODAY'S ASSIGNED BEAT"), findsOneWidget);
      expect(find.text('4 shops assigned beat'), findsOneWidget);
      expect(find.text('Sardarpura & Nai Sadak Route'), findsOneWidget);

      // Check In-Map "+ Add Shop" button
      expect(find.text('+ Add Shop'), findsOneWidget);

      // Check Continue Route button
      expect(find.byKey(const ValueKey('continue_route_btn')), findsOneWidget);

      // Check Edit and Delete action icons
      expect(find.byTooltip('Edit Shop'), findsOneWidget);
      expect(find.byTooltip('Delete / Remove Shop'), findsOneWidget);
    });

    testWidgets('4. SalesRouteMapView displays Sardarpura & Nai Sadak Route with in-map CRUD buttons', (tester) async {
      await tester.pumpWidget(
        LanguageScope(
          controller: LanguageController(initialLanguage: AppLanguage.en),
          child: MaterialApp(
            home: Scaffold(
              body: SalesRouteMapView(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sardarpura & Nai Sadak Route'), findsOneWidget);
      expect(find.text('4 Shops Assigned Beat • 1 Visited'), findsOneWidget);

      // Check in-map CRUD controls
      expect(find.text('+ Add Shop'), findsOneWidget);
      expect(find.byTooltip('Edit Shop'), findsOneWidget);
      expect(find.byTooltip('Delete / Remove Shop'), findsOneWidget);
    });
  });
}
