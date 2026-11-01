import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/models/inventory_math.dart';
import 'package:lala_distributor/models/models.dart';

void main() {
  group('Drift Schema Version 1 -> Version 2 Real Migration Tests', () {
    test(
        '1-3. Version 1 -> 2 migration adds isArchived and preserves existing products, retailers, snapshots, and movements',
        () async {
      // Create raw in-memory SQLite database simulating a v1 production database
      final rawDb = sqlite3.openInMemory();

      // 1. Create exact v1 schema (schemaVersion = 1, without is_archived column)
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

        PRAGMA user_version = 1;
      ''');

      // 2. Insert sample records into the v1 database
      rawDb.execute('''
        INSERT INTO products (id, name, hindi_name, category, mrp_rupees, piece_price_paise, strip_qty, box_qty, gst_rate, badge, image_url, created_at)
        VALUES ('prod_v1_kurkure', 'Kurkure Masala Munch', 'कुरकुरे मसाला मंच', 'Snacks', 20.0, 1600, 12, 48, 18.0, 'Hot', '', 1700000000);

        INSERT INTO retailers (id, name, owner_name, phone, address, area, credit_limit_paise, outstanding_paise, visited_today, total_time_spent_seconds, visit_count_today, created_at)
        VALUES ('ret_v1_ganesh', 'Shree Ganesh Kirana', 'Ramprasad', '+91 98290 12345', 'Clock Tower', 'Sardarpura', 5000000, 1250000, 1, 900, 2, 1700000000);

        INSERT INTO inventory_snapshots (product_id, godown_cartons, godown_loose_pieces, car_cartons, car_loose_pieces, updated_at)
        VALUES ('prod_v1_kurkure', 120, 24, 15, 0, 1700000000);

        INSERT INTO inventory_movements (id, product_id, movement_type, carton_delta, loose_piece_delta, reason, created_at)
        VALUES ('mov_v1_opening', 'prod_v1_kurkure', 'OPENING_BALANCE', 135, 24, 'Initial v1 stock', 1700000000);

        INSERT INTO inventory_movements (id, product_id, movement_type, carton_delta, loose_piece_delta, reason, created_at)
        VALUES ('mov_v1_transfer', 'prod_v1_kurkure', 'TRANSFER_TO_CAR', 15, 0, 'Loaded van', 1700000500);
      ''');

      // 3. Open this existing v1 database with Drift AppDatabase (target schemaVersion = 2)
      final upgradedDb = AppDatabase(NativeDatabase.opened(rawDb));
      final repo = LocalRepository(upgradedDb);

      expect(upgradedDb.schemaVersion, equals(2));

      // Requirement 1: Products preserved and new isArchived column defaulted to false
      final products = await repo.getAllProducts();
      expect(products.length, equals(1));
      expect(products.first.id, equals('prod_v1_kurkure'));
      expect(products.first.name, equals('Kurkure Masala Munch'));
      expect(products.first.godownStockBoxes, equals(120));
      expect(products.first.carStockBoxes, equals(15));

      final rawProductRow = await (upgradedDb.select(upgradedDb.products)
            ..where((tbl) => tbl.id.equals('prod_v1_kurkure')))
          .getSingle();
      expect(rawProductRow.isArchived, isFalse);

      // Requirement 2: Retailers and snapshots preserved
      final retailers = await repo.getAllRetailers();
      expect(retailers.length, equals(1));
      expect(retailers.first.id, equals('ret_v1_ganesh'));
      expect(retailers.first.name, equals('Shree Ganesh Kirana'));
      expect(retailers.first.totalTimeSpentSeconds, equals(900));
      expect(retailers.first.visitCountToday, equals(2));
      expect(retailers.first.visitedToday, isTrue);

      final snapshot = await repo.getInventorySnapshot('prod_v1_kurkure');
      expect(snapshot, isNotNull);
      expect(snapshot!.godownCartons, equals(120));
      expect(snapshot.godownLoosePieces, equals(24));
      expect(snapshot.carCartons, equals(15));

      // Requirement 3: Historical inventory movements preserved
      final movements = await repo.getMovementsForProduct('prod_v1_kurkure');
      expect(movements.length, equals(2));
      final mTypes = movements.map((m) => m.movementType).toList();
      expect(mTypes, containsAll(['OPENING_BALANCE', 'TRANSFER_TO_CAR']));

      await upgradedDb.close();
    });
  });

  group('Drift Schema v2 Product Archive, Audit Safety & Opening Movements', () {
    late AppDatabase db;
    late LocalRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = LocalRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Fresh install initializes schema version 2 correctly', () async {
      expect(db.schemaVersion, equals(2));
      expect(await repository.getMetadata('schema_initialized'), isNull);
      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.inventoryMovements).get(), isEmpty);
    });

    test('4-6. Product archive preserves historical movements, hides from active listing, blocks new stock operations',
        () async {
      final product = ProductItem(
        id: 'prod_audit_01',
        name: 'Balaji Crunchex',
        hindiName: 'बालाजी क्रंचेक्स',
        category: 'Snacks',
        mrpRupees: 10.0,
        piecePricePaise: 800,
        stripQty: 12,
        boxQty: 60,
        godownStockBoxes: 50,
      );

      await repository.upsertProduct(product);

      // Record a movement
      await repository.recordStockMovement(
        productId: product.id,
        movementType: 'INWARD',
        cartonDelta: 10,
        loosePieceDelta: 0,
        reason: 'Restock shipment Basni',
        newGodownCartons: 60,
        newGodownLoosePieces: 0,
        newCarCartons: 0,
        newCarLoosePieces: 0,
      );

      // Verify product is in active listings
      expect((await repository.getAllProducts()).length, equals(1));
      expect(await repository.isProductArchived(product.id), isFalse);

      // Soft archive the product
      await repository.archiveProduct(product.id);

      // Requirement 5: Archived products are excluded from normal active listings
      expect((await repository.getAllProducts()), isEmpty);
      expect((await repository.getAllProducts(includeArchived: true)).length, equals(1));
      expect(await repository.isProductArchived(product.id), isTrue);

      // Requirement 4: Historical movements remain 100% queryable and untouched
      final movements = await repository.getMovementsForProduct(product.id);
      expect(movements.isNotEmpty, isTrue);
      expect(movements.any((m) => m.movementType == 'INWARD'), isTrue);

      // Requirement 6: Archived product CANNOT receive new stock movements
      expect(
        () async => await repository.recordStockMovement(
          productId: product.id,
          movementType: 'INWARD',
          cartonDelta: 5,
          loosePieceDelta: 0,
          reason: 'Attempted restock on archived product',
          newGodownCartons: 65,
          newGodownLoosePieces: 0,
          newCarCartons: 0,
          newCarLoosePieces: 0,
        ),
        throwsA(isA<StateError>()),
      );

      // Deleting a product with movements soft-archives rather than destroying history
      await repository.deleteProduct(product.id);
      final movementsAfterDelete = await repository.getMovementsForProduct(product.id);
      expect(movementsAfterDelete.length, equals(movements.length),
          reason: 'Audit movements must never be destroyed by product deletion');

      // Restoring the product re-enables stock operations and active listing
      await repository.restoreProduct(product.id);
      expect((await repository.getAllProducts()).length, equals(1));
      expect(await repository.isProductArchived(product.id), isFalse);

      // Now stock movement succeeds again
      await repository.recordStockMovement(
        productId: product.id,
        movementType: 'INWARD',
        cartonDelta: 5,
        loosePieceDelta: 0,
        reason: 'Restock after restoring product',
        newGodownCartons: 65,
        newGodownLoosePieces: 0,
        newCarCartons: 0,
        newCarLoosePieces: 0,
      );
      final finalMovements = await repository.getMovementsForProduct(product.id);
      expect(finalMovements.length, equals(movements.length + 1));
    });

    test('7-9. Opening balance movement recorded atomically and idempotently', () async {
      final sampleProducts = [
        ProductItem(
          id: 'prod_seed_01',
          name: 'Kurkure Masala Munch',
          hindiName: 'कुरकुरे',
          category: 'Snacks',
          mrpRupees: 20.0,
          piecePricePaise: 1600,
          stripQty: 12,
          boxQty: 48,
          godownStockBoxes: 100,
          carStockBoxes: 15,
        ),
      ];

      final sampleRetailers = [
        RetailerShop(
          id: 'ret_seed_01',
          name: 'Shree Ganesh Kirana',
          ownerName: 'Ramprasad',
          phone: '9829012345',
          address: 'Station Rd',
          area: 'Clock Tower',
          creditLimitPaise: 5000000,
          outstandingPaise: 1000000,
        ),
      ];

      // First seed run
      await repository.seedIfEmpty(sampleProducts, sampleRetailers);

      // Requirement 7 & 9: Opening snapshot and OPENING_BALANCE movement exist
      final snapshot = await repository.getInventorySnapshot('prod_seed_01');
      expect(snapshot, isNotNull);
      expect(snapshot!.godownCartons, equals(100));
      expect(snapshot.carCartons, equals(15));

      var movements = await repository.getMovementsForProduct('prod_seed_01');
      expect(movements.length, equals(1));
      expect(movements.first.movementType, equals('OPENING_BALANCE'));
      expect(movements.first.cartonDelta, equals(115)); // 100 + 15
      expect(movements.first.loosePieceDelta, equals(0));

      // Requirement 8: Repeated seeding calls are completely idempotent and do not duplicate movements
      await repository.seedIfEmpty(sampleProducts, sampleRetailers);
      movements = await repository.getMovementsForProduct('prod_seed_01');
      expect(movements.length, equals(1),
          reason: 'Repeated seeding must never duplicate opening balance movements');
    });

    test('Retailer visit time tracking and metadata persistence', () async {
      await repository.setMetadata('pilot_release', 'b1-verified');
      expect(await repository.getMetadata('pilot_release'), equals('b1-verified'));

      final retailer = RetailerShop(
        id: 'ret_marwar',
        name: 'Marwar Super Provision',
        ownerName: 'Bhanwar Singh',
        phone: '9829198765',
        address: 'Sohati Gate',
        area: 'Sohati Gate',
        creditLimitPaise: 4000000,
        outstandingPaise: 800000,
      );

      await repository.upsertRetailer(retailer);
      await repository.updateRetailerVisit(
        retailer.id,
        totalTimeSpentSeconds: 650,
        visitCountToday: 2,
        visitedToday: true,
      );

      final reloaded = (await repository.getAllRetailers()).first;
      expect(reloaded.visitedToday, isTrue);
      expect(reloaded.totalTimeSpentSeconds, equals(650));
      expect(reloaded.visitCountToday, equals(2));
    });

    test('Integer carton/piece inventory math operations roundtrip', () async {
      final product = ProductItem(
        id: 'prod_math_01',
        name: 'Kurkure Masala',
        hindiName: 'कुरकुरे',
        category: 'Snacks',
        mrpRupees: 20.0,
        piecePricePaise: 1600,
        stripQty: 12,
        boxQty: 48,
        godownStockBoxes: 10,
      );

      await repository.upsertProduct(product);

      final snapshot = await repository.getInventorySnapshot(product.id);
      var stock = InventoryStock(
        cartons: snapshot!.godownCartons,
        loosePieces: snapshot.godownLoosePieces,
        piecesPerCarton: product.boxQty,
      );

      // Open 1 carton: 9 cartons, 48 loose pieces
      var afterOpen = stock.openCarton(1);
      expect(afterOpen.cartons, equals(9));
      expect(afterOpen.loosePieces, equals(48));

      // Deduct 50 pieces: 8 cartons, 46 loose pieces
      var afterSale = afterOpen.deductPieces(50);
      expect(afterSale.cartons, equals(8));
      expect(afterSale.loosePieces, equals(46));
      expect(afterSale.totalPieces, equals(430));

      await repository.recordStockMovement(
        productId: product.id,
        movementType: 'OPEN_CARTON',
        cartonDelta: -1,
        loosePieceDelta: 48,
        reason: 'Break carton for loose retail dispatch',
        newGodownCartons: afterSale.cartons,
        newGodownLoosePieces: afterSale.loosePieces,
        newCarCartons: 0,
        newCarLoosePieces: 0,
      );

      final updatedSnap = await repository.getInventorySnapshot(product.id);
      expect(updatedSnap!.godownCartons, equals(8));
      expect(updatedSnap.godownLoosePieces, equals(46));
    });
  });
}
