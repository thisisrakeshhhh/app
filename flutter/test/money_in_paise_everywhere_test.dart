import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/models/models.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sql;

class ZeroNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access strictly forbidden in offline tests');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = ZeroNetworkHttpOverrides();

  group('Part B1: Money In Paise Everywhere (Integer Invariant)', () {
    test('1. ProductItem stores mrpPaise as an integer and mrpRupees is derived for display', () {
      final p1 = ProductItem(
        id: 'P-1',
        name: 'Good Day 100g',
        hindiName: 'गुड डे',
        category: 'Biscuits',
        mrpPaise: 2500, // ₹25.00
        piecePricePaise: 2100,
        stripQty: 12,
        boxQty: 72,
        gstRate: 5.0,
      );

      expect(p1.mrpPaise, equals(2500));
      expect(p1.mrpRupees, equals(25.0));

      // Test with odd paise like ₹12.50
      final p2 = ProductItem(
        id: 'P-2',
        name: 'Kurkure Solid Masti',
        hindiName: 'सॉलिड मस्ती',
        category: 'Snacks',
        mrpRupees: 12.50,
        piecePricePaise: 1050,
        stripQty: 10,
        boxQty: 60,
        gstRate: 12.0,
      );

      expect(p2.mrpPaise, equals(1250));
      expect(p2.mrpRupees, equals(12.5));
    });

    test('2. Schema migration from v5 to v6 adds mrp_paise and backfills from legacy mrp_rupees without float error', () async {
      final rawDb = sql.sqlite3.openInMemory();

      // Create v5 products table without mrp_paise
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
          latitude REAL,
          longitude REAL,
          location_accuracy_meters REAL,
          class_type TEXT NOT NULL DEFAULT 'NEW',
          class_source TEXT NOT NULL DEFAULT 'MANUAL',
          shop_type TEXT NOT NULL DEFAULT 'KIRANA',
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          sync_status TEXT NOT NULL DEFAULT 'PENDING',
          route_id TEXT,
          created_at INTEGER NOT NULL
        );

        CREATE TABLE routes (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT NOT NULL,
          salesperson_id TEXT,
          created_at INTEGER NOT NULL
        );

        CREATE TABLE route_stops (
          id TEXT NOT NULL PRIMARY KEY,
          route_id TEXT NOT NULL,
          retailer_id TEXT NOT NULL,
          stop_sequence INTEGER NOT NULL,
          planned_day_of_week INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );

        CREATE TABLE product_units (
          product_id TEXT NOT NULL,
          unit_name TEXT NOT NULL,
          multiplier_to_base INTEGER NOT NULL,
          PRIMARY KEY (product_id, unit_name)
        );

        CREATE TABLE unit_prices (
          product_id TEXT NOT NULL,
          unit_name TEXT NOT NULL,
          multiplier_to_base INTEGER NOT NULL,
          price_paise INTEGER NOT NULL,
          PRIMARY KEY (product_id, unit_name)
        );

        CREATE TABLE cart_drafts (
          retailer_id TEXT NOT NULL,
          cart_json TEXT NOT NULL,
          updated_at_epoch_ms INTEGER NOT NULL,
          PRIMARY KEY (retailer_id)
        );

        CREATE TABLE visits (
          id TEXT NOT NULL PRIMARY KEY,
          retailer_id TEXT NOT NULL,
          salesperson_id TEXT NOT NULL,
          outcome TEXT NOT NULL,
          notes TEXT,
          timestamp_epoch_ms INTEGER NOT NULL
        );

        CREATE TABLE class_settings (
          class_name TEXT NOT NULL PRIMARY KEY,
          default_credit_limit_paise INTEGER NOT NULL,
          credit_days INTEGER NOT NULL,
          visit_frequency_days INTEGER NOT NULL
        );

        CREATE TABLE warehouse_hubs (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT NOT NULL,
          address TEXT NOT NULL,
          latitude REAL,
          longitude REAL,
          capacity_boxes INTEGER NOT NULL DEFAULT 0,
          active_staff_count INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );

        CREATE TABLE inventory_snapshots (
          product_id TEXT NOT NULL PRIMARY KEY REFERENCES products (id),
          godown_cartons INTEGER NOT NULL DEFAULT 0,
          godown_loose_pieces INTEGER NOT NULL DEFAULT 0,
          car_cartons INTEGER NOT NULL DEFAULT 0,
          car_loose_pieces INTEGER NOT NULL DEFAULT 0,
          damaged_cartons INTEGER NOT NULL DEFAULT 0,
          damaged_loose_pieces INTEGER NOT NULL DEFAULT 0,
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

        CREATE TABLE outbox_mutations (
          id TEXT NOT NULL PRIMARY KEY,
          organization_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          idempotency_key TEXT NOT NULL UNIQUE,
          mutation_type TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          sequence_order INTEGER NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'PENDING',
          provisional_business_id TEXT,
          lease_token TEXT,
          lease_generation INTEGER NOT NULL DEFAULT 0,
          lease_expires_at_ms INTEGER,
          attempt_count INTEGER NOT NULL DEFAULT 0,
          last_error_code TEXT,
          next_retry_at_ms INTEGER,
          created_at_epoch_ms INTEGER NOT NULL,
          synced_at_epoch_ms INTEGER
        );

        CREATE TABLE database_metadata (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );

        PRAGMA user_version = 5;
      ''');

      // Insert legacy products with various float MRPs
      rawDb.execute('''
        INSERT INTO products (id, name, hindi_name, category, mrp_rupees, piece_price_paise, strip_qty, box_qty, created_at)
        VALUES 
          ('p1', 'Parle-G 50g', 'पारले-जी', 'Biscuits', 5.0, 420, 10, 120, 1700000000),
          ('p2', 'Kurkure Masala', 'कुरकुरे', 'Snacks', 20.0, 1680, 12, 48, 1700000000),
          ('p3', 'Soap Bar Special', 'साबुन', 'Personal Care', 37.50, 3100, 6, 36, 1700000000);
      ''');

      // Upgrade with AppDatabase target schemaVersion = 7
      final upgradedDb = AppDatabase(NativeDatabase.opened(rawDb));
      expect(upgradedDb.schemaVersion, equals(7));

      final repo = LocalRepository(upgradedDb);
      final products = await repo.getAllProducts();
      expect(products.length, equals(3));

      final p1 = products.firstWhere((p) => p.id == 'p1');
      expect(p1.mrpPaise, equals(500)); // ₹5.00 = 500 paise

      final p2 = products.firstWhere((p) => p.id == 'p2');
      expect(p2.mrpPaise, equals(2000)); // ₹20.00 = 2000 paise

      final p3 = products.firstWhere((p) => p.id == 'p3');
      expect(p3.mrpPaise, equals(3750)); // ₹37.50 = 3750 paise

      await upgradedDb.close();
    });
  });
}
