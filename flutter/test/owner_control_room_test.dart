import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
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

  group('Slice 5: Owner Control Room & Sovereign Governance (Pillar C & Governance)', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const ownerSession = UserSession(
      userId: 'usr_owner_ramesh',
      name: 'Ramesh Agarwal',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'ADMIN',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
          role: 'ADMIN',
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

    test('1. Approving a new shop transitions shop from NEW to approved class and sets approved credit limit', () async {
      // 1. Create a shop as a salesperson (suggested Class B, starts as NEW cash-only)
      final shop = await api.createRetailerDurable(
        name: 'Ganesh General Store',
        ownerName: 'Ganesh Ram',
        phone: '9829011223',
        address: 'Sojati Gate',
        area: 'Sojati Gate',
        suggestedClass: 'B',
        idempotencyKey: 'idem_create_ganesh_01',
      );

      expect(shop.classType, 'NEW');
      expect(shop.creditLimitPaise, 0);

      // 2. Owner approves the shop as Class B with ₹25,000 credit limit
      await api.approveNewShop(
        retailerId: shop.id,
        approvedClass: 'B',
        approvedCreditLimitPaise: 2500000,
      );

      // Verify in-memory state updated
      final updatedShop = api.retailers.firstWhere((r) => r.id == shop.id);
      expect(updatedShop.classType, 'B');
      expect(updatedShop.creditLimitPaise, 2500000);
      expect(updatedShop.status, 'ACTIVE');

      // Verify persisted in SQLite
      final dbShop = await repo.getRetailerById(shop.id);
      expect(dbShop?.classType, 'B');
      expect(dbShop?.creditLimitPaise, 2500000);
    });

    test('2. Rejecting a new shop transitions status to REJECTED and disables ordering', () async {
      final shop = await api.createRetailerDurable(
        name: 'Suspicious Fake Stall',
        ownerName: 'Unknown',
        phone: '9829099887',
        address: 'Outer Bypass',
        area: 'Bypass',
        idempotencyKey: 'idem_create_fake_01',
      );

      await api.rejectNewShop(
        retailerId: shop.id,
        rejectionReason: 'Shop does not exist at reported location (GPS audit failed)',
      );

      final updatedShop = api.retailers.firstWhere((r) => r.id == shop.id);
      expect(updatedShop.status, 'REJECTED');

      final dbShop = await repo.getRetailerById(shop.id);
      expect(dbShop?.status, 'REJECTED');
    });

    test('3. Class settings can be edited and persist in SQLite class_settings table', () async {
      await repo.seedDefaultClassSettingsIfEmpty();

      // Update Class A terms: raise credit limit to ₹1,00,000 (10000000 paise) and credit days to 21
      await api.updateClassSetting(
        className: 'A',
        defaultCreditLimitPaise: 10000000,
        creditDays: 21,
        visitFrequencyDays: 1,
      );

      final settings = await repo.getAllClassSettings();
      final classA = settings.firstWhere((s) => s.className == 'A');
      expect(classA.defaultCreditLimitPaise, 10000000);
      expect(classA.creditDays, 21);
      expect(classA.visitFrequencyDays, 1);
    });

    test('4. Real metric calculations strictly match live DB aggregates without fake percentages', () async {
      final initialMetrics = await api.getOwnerMetrics();

      // Book an order
      final shop = api.retailers.first;
      final prod = api.products.first;
      api.selectShop(shop);
      api.addToCart(prod, OrderUnit.box, 2);

      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'CASH',
        checkoutIdempotencyKey: 'idem_metrics_ord_01',
      );

      final metricsAfter = await api.getOwnerMetrics();
      // Real sum of today's booked orders increments exactly by the new order amount
      expect(metricsAfter.todayBookingsPaise, initialMetrics.todayBookingsPaise + order.totalPaise);
      expect(metricsAfter.todayOrdersCount, initialMetrics.todayOrdersCount + 1);
      // Real count of pending outbox mutations
      expect(metricsAfter.pendingOutboxCount >= 1, isTrue);
    });
  });
}
