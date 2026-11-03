import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/screens/dashboards/admin_dashboard.dart';
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

  group('Part B8: Owner Control Room — Approvals Inbox, Salesperson Cards & Inactive Alerts', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const ownerSession = UserSession(
      userId: 'usr_owner_ramesh',
      name: 'Ramesh Lal',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'OWNER',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
          role: 'OWNER',
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
        sessionProvider: () => ownerSession,
      );
      await api.syncForTesting(seed: true);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Owner approvals inbox lists pending shops and one-tap approval activates shop with credit limit', () async {
      // Create a pending shop with class NEW
      final pendingShop = await api.createRetailerDurable(
        name: 'New Ganesh Kirana',
        ownerName: 'Ganesh Ram',
        phone: '9829011223',
        address: 'Bhadwasiya Mandi',
        area: 'Bhadwasiya',
        routeId: 'route_sojati_01',
        shopType: 'KIRANA',
        suggestedClass: 'NEW',
      );

      final pendingList = api.pendingShopApprovals;
      expect(pendingList.any((s) => s.id == pendingShop.id), isTrue);

      // Owner approves with Class B and ₹15,000 credit limit (1,500,000 paise)
      await api.approveNewShop(
        retailerId: pendingShop.id,
        approvedClass: 'B',
        approvedCreditLimitPaise: 1500000,
      );

      final approved = api.retailers.firstWhere((r) => r.id == pendingShop.id);
      expect(approved.status, equals('ACTIVE'));
      expect(approved.classType, equals('B'));
      expect(approved.creditLimitPaise, equals(1500000));
    });

    test('2. Inactive shops filter identifies shops with no recent orders within threshold days', () {
      final inactiveShops = api.getInactiveShops(daysThreshold: 15);
      expect(inactiveShops, isNotNull);
      // New shops without orders are flagged as inactive for owner follow-up
      expect(inactiveShops.isNotEmpty, isTrue);
    });

    test('3. Salesperson performance aggregates active visits, coverage, and cash collections', () {
      final performances = api.getSalespersonPerformances();
      expect(performances.isNotEmpty, isTrue);

      final imran = performances.first;
      expect(imran.name.isNotEmpty, isTrue);
      expect(imran.beat.isNotEmpty, isTrue);
      expect(imran.totalShops, greaterThan(0));
    });

    testWidgets('4. AdminDashboard renders Approvals Inbox, Inactive Shops Alert, and Salesperson cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(
              api: api,
              onNavigateTab: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('owner_approvals_inbox')), findsOneWidget);
      expect(find.byKey(const ValueKey('owner_inactive_shops_alert')), findsOneWidget);
      expect(find.byKey(const ValueKey('owner_salesperson_cards')), findsOneWidget);
    });
  });
}
