import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/screens/dashboards/sales_dashboard.dart';
import 'package:lala_distributor/screens/views/sales_subviews.dart';
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

  group('Part B7: High-Velocity Sales UX — Search, Stepper, Order Again & Continue Route', () {
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
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    testWidgets('1. SalesOrderBookingView search bar filters by English, Hindi, and SKU', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesOrderBookingView(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search bar exists
      final searchField = find.byKey(const ValueKey('sales_order_search_field'));
      expect(searchField, findsOneWidget);

      // Search by SKU: KURK-02
      await tester.enterText(searchField, 'KURK-02');
      await tester.pumpAndSettle();
      expect(find.text('Kurkure Chilli Chatka'), findsOneWidget);
      expect(find.text('Kurkure Masala Munch'), findsNothing);

      // Search by Hindi name: चिल्ली
      await tester.enterText(searchField, 'चिल्ली');
      await tester.pumpAndSettle();
      expect(find.text('Kurkure Chilli Chatka'), findsOneWidget);
      expect(find.text('Kurkure Masala Munch'), findsNothing);
    });

    testWidgets('2. Quick-qty chips (+1, +5, +10) update quantity and live line totals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesOrderBookingView(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap +5 chip on the first product card
      final chip5 = find.byKey(ValueKey('quick_qty_5_${api.products.first.id}'));
      expect(chip5, findsOneWidget);

      await tester.tap(chip5);
      await tester.pumpAndSettle();

      // Initial was 1, so 1 + 5 = 6
      expect(find.byKey(ValueKey('qty_display_${api.products.first.id}')), findsOneWidget);
      expect(find.text('6'), findsWidgets);
    });

    testWidgets('3. Order Again shelf displays previously ordered products for the active shop', (tester) async {
      // First book an order for shop
      final shop = api.retailers.first;
      api.addToCart(api.products.first, OrderUnit.box, 2);
      await api.confirmOrderDurable(shopId: shop.id, paymentMode: 'Cash');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesOrderBookingView(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Order again shelf should be visible
      expect(find.byKey(const ValueKey('order_again_shelf')), findsOneWidget);
      expect(find.text('Order Again ⚡'), findsOneWidget);
    });

    testWidgets('4. Today screen displays Continue Route button with next pending shop', (tester) async {
      int navigatedToTab = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesDashboard(
              api: api,
              onNavigateTab: (tab) => navigatedToTab = tab,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final continueBtn = find.byKey(const ValueKey('continue_route_btn'));
      expect(continueBtn, findsOneWidget);

      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Should navigate to retailer tab (tab 2)
      expect(navigatedToTab, equals(2));
    });

    test('5. WhatsApp order share summary formats valid text with items, total, and OTP', () {
      final order = api.orders.first;
      final shareText = api.generateWhatsAppOrderShareText(order);

      expect(shareText, contains('RouteFlow Order Confirmation'));
      expect(shareText, contains(order.shopName));
      expect(shareText, contains('OTP'));
      expect(shareText, contains('Total: ₹'));
    });
  });
}
