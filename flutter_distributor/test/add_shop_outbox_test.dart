import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/domain/outbox/outbox_models.dart';
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

  group('Slice 1: Add Shop (Pillar A) — Offline Outbox, Geotagging & Invariants', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const testSession = UserSession(
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
        sessionProvider: () => testSession,
      );
      await api.syncForTesting(seed: true);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Quick-add shop creates local retailer and durable CREATE_RETAILER outbox mutation atomically', () async {
      final newShop = await api.createRetailerDurable(
        name: 'Mahalaxmi Provision Store',
        ownerName: 'Suresh Kumar',
        phone: '9829011223',
        address: 'Bhadwasiya Road',
        area: 'Paota',
        routeId: 'route_paota_01',
        latitude: 26.2915,
        longitude: 73.0234,
        locationAccuracyMeters: 8.5,
      );

      // Verify returned in-memory object
      expect(newShop.id, startsWith('ret_'));
      expect(newShop.name, equals('Mahalaxmi Provision Store'));
      expect(newShop.phone, equals('9829011223'));
      expect(newShop.classType, equals('NEW'));
      expect(newShop.classSource, equals('SALESPERSON_SUGGESTED'));
      expect(newShop.creditLimitPaise, equals(0)); // Salesperson cannot assign credit
      expect(newShop.status, equals('ACTIVE'));
      expect(newShop.syncStatus, equals('PENDING'));
      expect(newShop.locationAccuracyMeters, equals(8.5));

      // Verify persisted in SQLite retailers table
      final storedRetailers = await repo.getAllRetailers();
      final stored = storedRetailers.firstWhere((r) => r.id == newShop.id);
      expect(stored.name, equals('Mahalaxmi Provision Store'));
      expect(stored.locationAccuracyMeters, equals(8.5));

      // Verify persisted in SQLite outbox_mutations table
      final pendingMutations = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jodhpur_dist',
        userId: 'usr_sales_imran',
      );
      final shopMutation = pendingMutations.firstWhere((m) => m.provisionalBusinessId == newShop.id);
      expect(shopMutation.mutationType, equals('CREATE_RETAILER'));
      expect(shopMutation.syncStatus, equals('PENDING'));

      final payload = CreateRetailerMutationPayload.fromCanonicalJson(shopMutation.payloadJson);
      expect(payload.name, equals('Mahalaxmi Provision Store'));
      expect(payload.locationAccuracyMeters, equals(8.5));
    });

    test('2. Double-tap protection: Reusing idempotency key returns the existing shop without duplicate insertion', () async {
      const stableKey = 'idem_key_add_shop_double_tap';

      final shop1 = await api.createRetailerDurable(
        name: 'Kisan Tea & Kirana',
        ownerName: 'Ramu Lal',
        phone: '9829144556',
        address: 'Mandore Road',
        area: 'Mandore',
        idempotencyKey: stableKey,
      );

      final countBefore = (await repo.getAllRetailers()).length;

      // Second identical call with the same idempotency key (simulating network bounce or double-tap)
      final shop2 = await api.createRetailerDurable(
        name: 'Kisan Tea & Kirana',
        ownerName: 'Ramu Lal',
        phone: '9829144556',
        address: 'Mandore Road',
        area: 'Mandore',
        idempotencyKey: stableKey,
      );

      final countAfter = (await repo.getAllRetailers()).length;

      expect(shop2.id, equals(shop1.id));
      expect(countAfter, equals(countBefore)); // Zero duplicate rows created
    });

    test('3. Duplicate detection checks phone, GSTIN, and normalized name similarity', () {
      // Existing seeded shop has phone '+91 98290 12345'
      final dupPhone = api.checkDuplicateRetailer(
        phone: '9829012345',
        name: 'Another Store',
        area: 'Sardarpura',
      );
      expect(dupPhone.hasDuplicate, isTrue);
      expect(dupPhone.type, equals(DuplicateType.exactMobile));
      expect(dupPhone.matchedShop!.id, equals(api.retailers.first.id));

      // Clean check with brand new mobile and name
      final noDup = api.checkDuplicateRetailer(
        phone: '9988776655',
        name: 'Unique Jodhpur Sweets',
        area: 'Ratanada',
      );
      expect(noDup.hasDuplicate, isFalse);
      expect(noDup.type, equals(DuplicateType.none));
    });

    test('4. Offline resilience: Shop saves cleanly without GPS coordinates when location is denied/disabled', () async {
      final shopWithoutGps = await api.createRetailerDurable(
        name: 'Basement Kirana Shop',
        ownerName: 'Madan Lal',
        phone: '9829988776',
        address: 'Underground Complex, Sojati Gate',
        area: 'Sojati Gate',
        latitude: null,
        longitude: null,
        locationAccuracyMeters: null,
      );

      expect(shopWithoutGps.id, startsWith('ret_'));
      expect(shopWithoutGps.latitude, isNull);
      expect(shopWithoutGps.longitude, isNull);
      expect(shopWithoutGps.locationAccuracyMeters, isNull);
      expect(shopWithoutGps.status, equals('ACTIVE'));
    });

    test('5. Dependency ordering: Order booked for a new offline shop orders after the shop mutation', () async {
      // 1. Add new shop offline
      final newShop = await api.createRetailerDurable(
        name: 'Shree Krishna General Store',
        ownerName: 'Gopal Das',
        phone: '9829555666',
        address: 'Sardarpura 4th B Rd',
        area: 'Sardarpura',
      );

      // 2. Book an order for this provisional shop
      api.clearCart();
      api.addToCart(api.products.first, OrderUnit.box, 1);
      final order = await api.confirmOrderDurable(
        shopId: newShop.id,
        paymentMode: 'COD',
      );

      // 3. Inspect outbox sequence orders
      final pending = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jodhpur_dist',
        userId: 'usr_sales_imran',
      );

      final shopMut = pending.firstWhere((m) => m.provisionalBusinessId == newShop.id);
      final orderMut = pending.firstWhere((m) => m.provisionalBusinessId == order.id);

      // Shop creation sequence MUST be strictly less than order confirmation sequence
      expect(shopMut.sequenceOrder < orderMut.sequenceOrder, isTrue);
      expect(orderMut.sequenceOrder, equals(shopMut.sequenceOrder + 1));
    });
  });
}
