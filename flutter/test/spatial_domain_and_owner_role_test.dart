import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/role_routing.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('RouteFlow Phase M1 — Canonical OWNER Role & Sovereign Governance Tests', () {
    test('1. CanonicalRole.owner parses correctly and assigns sovereign metadata', () {
      expect(CanonicalRole.fromString('OWNER'), CanonicalRole.owner);
      expect(CanonicalRole.fromString('owner'), CanonicalRole.owner);
      expect(CanonicalRole.fromString('DISTRIBUTOR_OWNER'), CanonicalRole.owner);
      expect(CanonicalRole.fromString('distributor_owner'), CanonicalRole.owner);

      final owner = CanonicalRole.owner;
      expect(owner.key, equals('OWNER'));
      expect(owner.displayName, equals('Distributor Owner'));
      expect(owner.badgeLabel, equals('OWNER'));
    });

    test('2. Owner possesses complete sovereign authority across all operations and finance', () {
      final owner = CanonicalRole.owner;
      for (final permission in RolePermission.values) {
        expect(
          roleHasPermission(owner, permission),
          isTrue,
          reason: 'Owner should possess permission ${permission.name}',
        );
        expect(
          () => assertRolePermission(owner, permission),
          returnsNormally,
        );
      }
    });

    test('3. Admin is strictly fenced from Owner-exclusive sovereign financial permissions', () {
      final admin = CanonicalRole.admin;
      const sovereignPermissions = [
        RolePermission.modifyCreditLimits,
        RolePermission.settleDriverCash,
        RolePermission.viewFinancialProfitLedger,
        RolePermission.authorizeStockWriteOff,
      ];

      for (final permission in sovereignPermissions) {
        expect(
          roleHasPermission(admin, permission),
          isFalse,
          reason: 'Admin must NOT possess sovereign permission ${permission.name}',
        );
        expect(
          () => assertRolePermission(admin, permission),
          throwsA(isA<RoleAuthorizationException>()),
          reason: 'assertRolePermission for Admin on ${permission.name} must throw',
        );
      }
    });
  });

  group('RouteFlow Phase M1 — Drift SQLite Schema Version 4 Spatial Persistence Tests', () {
    late AppDatabase db;
    late LocalRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = LocalRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('4. Fresh install initializes Drift schema version 7 with spatial columns', () async {
      expect(db.schemaVersion, equals(7));

      // Retailers table with latitude and longitude
      await repository.upsertRetailer(
        RetailerShop(
          id: 'RET-GEO-001',
          name: 'Jodhpur Heritage Spice',
          ownerName: 'Manish Bhati',
          phone: '9829099887',
          address: 'Clock Tower Market',
          area: 'Sardar Market',
          creditLimitPaise: 25000000,
          outstandingPaise: 1200000,
          latitude: 26.2965,
          longitude: 73.0232,
        ),
      );

      final retailers = await repository.getAllRetailers();
      expect(retailers.length, equals(1));
      expect(retailers.first.id, equals('RET-GEO-001'));
      expect(retailers.first.latitude, closeTo(26.2965, 0.0001));
      expect(retailers.first.longitude, closeTo(73.0232, 0.0001));
    });

    test('5. WarehouseHubs table supports insertion, retrieval, and seeding', () async {
      // Direct insertion via repository
      final hub = WarehouseHub(
        id: 'WH-TEST-01',
        name: 'Basni Central Godown',
        code: 'WH-BASNI',
        address: 'Basni Phase II, Jodhpur',
        latitude: 26.2167,
        longitude: 73.0167,
        capacityBoxes: 50000,
        activeStaffCount: 12,
        godownStockBoxes: 4200,
        carStockBoxes: 350,
      );

      await repository.upsertWarehouseHub(hub);

      final storedHubs = await repository.getAllWarehouseHubs();
      expect(storedHubs.length, equals(1));
      expect(storedHubs.first.id, equals('WH-TEST-01'));
      expect(storedHubs.first.name, equals('Basni Central Godown'));
      expect(storedHubs.first.latitude, closeTo(26.2167, 0.0001));
      expect(storedHubs.first.longitude, closeTo(73.0167, 0.0001));
      expect(storedHubs.first.capacityBoxes, equals(50000));
      expect(storedHubs.first.activeStaffCount, equals(12));
    });

    test('6. Additive migration from v3 to v4 adds spatial columns and warehouse_hubs table', () async {
      final rawDb = sqlite3.openInMemory();

      // Create v3 baseline schema
      rawDb.execute('''
        CREATE TABLE products (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          hindi_name TEXT NOT NULL,
          category TEXT NOT NULL,
          mrp_rupees REAL NOT NULL,
          piece_price_paise INTEGER NOT NULL,
          strip_qty INTEGER NOT NULL,
          box_qty INTEGER NOT NULL,
          gst_rate REAL NOT NULL DEFAULT 18.0,
          badge TEXT NOT NULL DEFAULT '',
          image_url TEXT NOT NULL DEFAULT '',
          is_archived INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );

        CREATE TABLE retailers (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          owner_name TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT NOT NULL,
          area TEXT NOT NULL,
          credit_limit_paise INTEGER NOT NULL,
          outstanding_paise INTEGER NOT NULL,
          visited_today INTEGER NOT NULL DEFAULT 0,
          total_time_spent_seconds INTEGER NOT NULL DEFAULT 0,
          visit_count_today INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );

        CREATE TABLE inventory_snapshots (
          product_id TEXT NOT NULL PRIMARY KEY REFERENCES products (id),
          godown_cartons INTEGER NOT NULL DEFAULT 0,
          godown_loose_pieces INTEGER NOT NULL DEFAULT 0,
          car_cartons INTEGER NOT NULL DEFAULT 0,
          car_loose_pieces INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL
        );

        CREATE TABLE inventory_movements (
          id TEXT NOT NULL PRIMARY KEY,
          product_id TEXT NOT NULL REFERENCES products (id),
          movement_type TEXT NOT NULL,
          carton_delta INTEGER NOT NULL,
          loose_piece_delta INTEGER NOT NULL,
          reason TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL
        );

        CREATE TABLE database_metadata (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );

        CREATE TABLE outbox_mutations (
          mutation_id TEXT NOT NULL PRIMARY KEY,
          organization_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          user_role TEXT NOT NULL,
          mutation_type TEXT NOT NULL,
          idempotency_key TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          schema_version INTEGER NOT NULL,
          sync_status TEXT NOT NULL,
          retry_count INTEGER NOT NULL,
          sequence_order INTEGER NOT NULL,
          last_error TEXT,
          created_at_ms INTEGER NOT NULL,
          next_retry_at_ms INTEGER NOT NULL,
          synced_at_ms INTEGER
        );

        PRAGMA user_version = 3;
      ''');

      // Insert existing retailer in v3 schema
      rawDb.execute('''
        INSERT INTO retailers (id, name, owner_name, phone, address, area, credit_limit_paise, outstanding_paise, created_at)
        VALUES ('RET-LEGACY-01', 'Old City General Store', 'Gopal Das', '9829011111', 'Sojati Gate', 'Old City', 1000000, 200000, 1700000000);
      ''');

      // Open with Drift AppDatabase target schemaVersion = 7
      final upgradedDb = AppDatabase(NativeDatabase.opened(rawDb));
      expect(upgradedDb.schemaVersion, equals(7));

      // Verify warehouse_hubs table now exists
      final tablesAfter = await upgradedDb.customSelect(
        "SELECT count(*) as cnt FROM sqlite_master WHERE type='table' AND name='warehouse_hubs';",
      ).getSingle();
      expect(tablesAfter.read<int>('cnt'), equals(1));

      // Verify existing retailer survived and columns latitude and longitude were added
      final updatedRetailer = await upgradedDb.customSelect(
        "SELECT id, name, latitude, longitude FROM retailers WHERE id='RET-LEGACY-01';",
      ).getSingle();
      expect(updatedRetailer.read<String>('name'), equals('Old City General Store'));
      expect(updatedRetailer.readNullable<double>('latitude'), isNull);
      expect(updatedRetailer.readNullable<double>('longitude'), isNull);

      await upgradedDb.close();
    });
  });

  group('RouteFlow Phase M1 — Domain Spatial Model & Seed Integrity Tests', () {
    test('7. ApiService populates realistic Jodhpur coordinates and warehouse hubs', () {
      final api = ApiService();

      // Check Jodhpur retailers have valid non-null coordinates
      final retailersWithCoords = api.retailers.where((r) => r.latitude != null && r.longitude != null && r.latitude! < 29.0).toList();
      expect(retailersWithCoords.length, greaterThanOrEqualTo(4));

      for (final r in retailersWithCoords) {
        expect(r.latitude!, inInclusiveRange(26.0, 27.0), reason: 'Jodhpur latitude range');
        expect(r.longitude!, inInclusiveRange(72.5, 73.5), reason: 'Jodhpur longitude range');
      }

      // Check warehouse hubs
      expect(api.warehouseHubs.length, greaterThanOrEqualTo(2));
      final centralWh = api.warehouseHubs.firstWhere((w) => w.id == 'WH-JDH-CENTRAL');
      expect(centralWh.name, contains('Central'));
      expect(centralWh.latitude, closeTo(26.2167, 0.0001));
      expect(centralWh.longitude, closeTo(73.0167, 0.0001));
      expect(centralWh.totalStockBoxes, equals(centralWh.godownStockBoxes + centralWh.carStockBoxes));

      // Check delivery stops inherit coordinates
      final stopsWithCoords = api.deliveryStops.where((s) => s.latitude != null && s.longitude != null).toList();
      expect(stopsWithCoords.length, greaterThanOrEqualTo(2));
    });
  });
}
