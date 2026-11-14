import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/models/inventory_math.dart';
import 'package:lala_distributor/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalRepository(db);

    // Seed a standard test product
    await db.into(db.products).insert(
      ProductsCompanion(
        id: const drift.Value('PROD_NAMKEEN_01'),
        name: const drift.Value('Bikaji Bhujia 200g'),
        hindiName: const drift.Value('बीकाजी भुजिया २०० ग्रा.'),
        category: const drift.Value('Extruded Snacks'),
        mrpRupees: const drift.Value(55.0),
        mrpPaise: const drift.Value(5500),
        piecePricePaise: const drift.Value(4500),
        stripQty: const drift.Value(12),
        boxQty: const drift.Value(24),
        gstRate: const drift.Value(12.0),
        badge: const drift.Value('Popular'),
        imageUrl: const drift.Value(''),
        isArchived: const drift.Value(false),
        createdAt: drift.Value(DateTime.now()),
      ),
    );

    // Initial snapshot: 10 cartons (24 pcs/ctn) + 0 loose = 240 physical pieces, 0 reserved
    await db.into(db.inventorySnapshots).insert(
      InventorySnapshotsCompanion(
        productId: const drift.Value('PROD_NAMKEEN_01'),
        godownCartons: const drift.Value(10),
        godownLoosePieces: const drift.Value(0),
        carCartons: const drift.Value(0),
        carLoosePieces: const drift.Value(0),
        damagedCartons: const drift.Value(0),
        damagedLoosePieces: const drift.Value(0),
        reservedCartons: const drift.Value(0),
        reservedLoosePieces: const drift.Value(0),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Checkpoint 2 — Domain InventoryStock Mathematics', () {
    test('Calculates physical, reserved, and available stock accurately', () {
      // 10 cartons (24 pcs/ctn) = 240 physical. 2 cartons + 4 loose reserved = 52 reserved.
      final stock = InventoryStock(
        cartons: 10,
        loosePieces: 0,
        piecesPerCarton: 24,
        reservedCartons: 2,
        reservedLoosePieces: 4,
      );

      expect(stock.physicalPieces, equals(240));
      expect(stock.reservedPieces, equals(52));
      expect(stock.availablePieces, equals(188)); // 240 - 52 = 188
      expect(stock.availableCartons, equals(7)); // 188 ~/ 24 = 7 cartons (168 pcs)
      expect(stock.availableLoosePieces, equals(20)); // 188 % 24 = 20 loose pieces
      expect(stock.hasSufficientStock(188), isTrue);
      expect(stock.hasSufficientStock(189), isFalse);
      expect(stock.hasSufficientPhysicalStock(240), isTrue);
    });

    test('Reservation increases reserved stock and reduces available stock', () {
      final stock = InventoryStock(
        cartons: 5,
        loosePieces: 0,
        piecesPerCarton: 20, // 100 physical
      );

      final reserved = stock.reservePieces(25);
      expect(reserved.physicalPieces, equals(100));
      expect(reserved.reservedPieces, equals(25));
      expect(reserved.availablePieces, equals(75));
      expect(reserved.reservedCartons, equals(1)); // 25 ~/ 20 = 1
      expect(reserved.reservedLoosePieces, equals(5)); // 25 % 20 = 5

      // Cannot reserve more than available stock
      expect(() => reserved.reservePieces(76), throwsA(isA<StateError>()));
    });

    test('Releasing reservation restores available stock', () {
      final stock = InventoryStock(
        cartons: 5,
        loosePieces: 0,
        piecesPerCarton: 20,
        reservedCartons: 2,
        reservedLoosePieces: 0, // 40 reserved, 60 available
      );

      final released = stock.releaseReservation(15);
      expect(released.reservedPieces, equals(25));
      expect(released.availablePieces, equals(75));

      // Cannot release more than currently reserved
      expect(() => released.releaseReservation(26), throwsA(isA<StateError>()));
    });

    test('Fulfillment commit decrements both physical and reserved stock', () {
      final stock = InventoryStock(
        cartons: 5,
        loosePieces: 0,
        piecesPerCarton: 20,
        reservedCartons: 1,
        reservedLoosePieces: 10, // 30 reserved, 70 available, 100 physical
      );

      final fulfilled = stock.commitAndDeductReserved(30);
      expect(fulfilled.reservedPieces, equals(0));
      expect(fulfilled.physicalPieces, equals(70));
      expect(fulfilled.availablePieces, equals(70));
    });

    test('Stock adjustment enforces physical stock >= reserved stock', () {
      final stock = InventoryStock(
        cartons: 5,
        loosePieces: 0,
        piecesPerCarton: 20,
        reservedCartons: 2,
        reservedLoosePieces: 0, // 40 reserved, 100 physical
      );

      // Reducing physical stock by 2 cartons (40 pcs): 60 physical >= 40 reserved -> Allowed
      final adjusted = stock.adjustStock(cartonDelta: -2);
      expect(adjusted.physicalPieces, equals(60));
      expect(adjusted.availablePieces, equals(20));

      // Reducing physical stock by 4 cartons (80 pcs): 20 physical < 40 reserved -> Prohibited
      expect(() => stock.adjustStock(cartonDelta: -4), throwsA(isA<StateError>()));
    });

    test('Invalid state detection: reserved exceeding physical stock is reported/rejected and never silently hidden', () {
      // 1. Direct construction assertion rejects invalid over-reservation
      expect(
        () => InventoryStock(
          cartons: 1,
          loosePieces: 0,
          piecesPerCarton: 24, // 24 physical
          reservedCartons: 2, // 48 reserved -> invalid!
          reservedLoosePieces: 0,
        ),
        throwsA(isA<AssertionError>()),
      );

      // 2. ProductItem with over-reservation flags isOverReserved and throws on availableGodownPieces
      final invalidProduct = ProductItem(
        id: 'PROD_INVALID',
        name: 'Invalid Item',
        hindiName: 'अमान्य',
        category: 'Test',
        piecePricePaise: 1000,
        stripQty: 10,
        boxQty: 20,
        godownStockBoxes: 2, // 40 physical
        godownReservedBoxes: 3, // 60 reserved -> over-reserved by 20 pieces!
      );

      expect(invalidProduct.isGodownOverReserved, isTrue);
      expect(invalidProduct.godownOverReservedPieces, equals(20));
      expect(() => invalidProduct.availableGodownPieces, throwsA(isA<StateError>()));
    });
  });

  group('Checkpoint 2 — LocalRepository Inventory Ledger & Idempotency', () {
    test('reserveStock updates Drift snapshot and posts auditable movement', () async {
      await repository.reserveStock(
        productId: 'PROD_NAMKEEN_01',
        pieces: 48, // 2 cartons
        orderId: 'ORD_TEST_101',
        reason: 'Order booking by salesperson',
      );

      final products = await repository.getAllProducts();
      final p = products.firstWhere((item) => item.id == 'PROD_NAMKEEN_01');

      expect(p.godownStockBoxes, equals(10)); // Physical remains 10
      expect(p.godownReservedBoxes, equals(2)); // Reserved is 2 boxes
      expect(p.godownReservedPieces, equals(0));
      expect(p.availableGodownBoxes, equals(8)); // 10 - 2 = 8 available
      expect(p.availableGodownPieces, equals(192));

      // Verify immutable ledger entry
      final movements = await (db.select(db.inventoryMovements)
            ..where((tbl) => tbl.productId.equals('PROD_NAMKEEN_01') & tbl.movementType.equals('STOCK_RESERVE')))
          .get();
      expect(movements.length, equals(1));
      expect(movements.first.movementType, equals('STOCK_RESERVE'));
      expect(movements.first.cartonDelta, equals(2));
      expect(movements.first.invoiceNumber, equals('ORD_TEST_101'));
      expect(movements.first.idempotencyKey, equals('reserve_ORD_TEST_101_PROD_NAMKEEN_01'));

      // Idempotent retry does not duplicate reservation or ledger row
      await repository.reserveStock(
        productId: 'PROD_NAMKEEN_01',
        pieces: 48,
        orderId: 'ORD_TEST_101',
      );
      final movementsAfterRetry = await (db.select(db.inventoryMovements)
            ..where((tbl) => tbl.productId.equals('PROD_NAMKEEN_01') & tbl.movementType.equals('STOCK_RESERVE')))
          .get();
      expect(movementsAfterRetry.length, equals(1));
    });

    test('Overselling prevention: cannot reserve beyond available stock', () async {
      // Current available: 240 pieces
      expect(
        () => repository.reserveStock(
          productId: 'PROD_NAMKEEN_01',
          pieces: 241, // 1 piece over available
          orderId: 'ORD_OVERSELL',
        ),
        throwsA(isA<StateError>()),
      );

      // Verify snapshot and reservations were unaffected
      final products = await repository.getAllProducts();
      final p = products.firstWhere((item) => item.id == 'PROD_NAMKEEN_01');
      expect(p.availableGodownPieces, equals(240));
      expect(p.reservedGodownPieces, equals(0));
    });

    test('releaseStockReservation releases reserved units back to available', () async {
      await repository.reserveStock(
        productId: 'PROD_NAMKEEN_01',
        pieces: 24, // 1 carton
        orderId: 'ORD_CANCEL_01',
      );

      await repository.releaseStockReservation(
        productId: 'PROD_NAMKEEN_01',
        pieces: 24,
        orderId: 'ORD_CANCEL_01',
        reason: 'Order cancelled by retailer',
      );

      final products = await repository.getAllProducts();
      final p = products.firstWhere((item) => item.id == 'PROD_NAMKEEN_01');
      expect(p.godownReservedBoxes, equals(0));
      expect(p.availableGodownBoxes, equals(10));
      expect(p.availableGodownPieces, equals(240));

      final releaseMovements = await (db.select(db.inventoryMovements)
            ..where((tbl) => tbl.movementType.equals('STOCK_RELEASE')))
          .get();
      expect(releaseMovements.length, equals(1));
      expect(releaseMovements.first.idempotencyKey, equals('release_ORD_CANCEL_01_PROD_NAMKEEN_01'));
    });

    test('commitAndDeductStock fulfills reserved order and decrements physical inventory', () async {
      // 1. Reserve 48 pieces
      await repository.reserveStock(
        productId: 'PROD_NAMKEEN_01',
        pieces: 48,
        orderId: 'ORD_DELIVER_01',
      );

      // 2. Dispatch/fulfill 48 pieces
      await repository.commitAndDeductStock(
        productId: 'PROD_NAMKEEN_01',
        pieces: 48,
        orderId: 'ORD_DELIVER_01',
        reason: 'Delivered to retailer',
      );

      final products = await repository.getAllProducts();
      final p = products.firstWhere((item) => item.id == 'PROD_NAMKEEN_01');
      expect(p.godownStockBoxes, equals(8)); // Physical decremented: 10 - 2 = 8
      expect(p.godownReservedBoxes, equals(0)); // Reservation cleared
      expect(p.availableGodownBoxes, equals(8));
      expect(p.availableGodownPieces, equals(192));

      final dispatchMovements = await (db.select(db.inventoryMovements)
            ..where((tbl) => tbl.movementType.equals('DISPATCH')))
          .get();
      expect(dispatchMovements.length, equals(1));
      expect(dispatchMovements.first.cartonDelta, equals(-2));
      expect(dispatchMovements.first.idempotencyKey, equals('dispatch_ORD_DELIVER_01_PROD_NAMKEEN_01'));
    });

    test('adjustStock prevents reducing physical inventory below reserved quantity', () async {
      // Reserve 7 cartons (168 pcs), leaving 3 cartons (72 pcs) available
      await repository.reserveStock(
        productId: 'PROD_NAMKEEN_01',
        pieces: 168,
        orderId: 'ORD_ADJ_TEST',
      );

      // Adjusting physical stock by -2 cartons (leaving 8 cartons physical >= 7 cartons reserved) -> Succeeds
      await repository.adjustStock(
        productId: 'PROD_NAMKEEN_01',
        cartonDelta: -2,
        loosePieceDelta: 0,
        reason: 'Damaged cartons removed from godown',
        idempotencyKey: 'adj_dmg_01',
      );

      final products = await repository.getAllProducts();
      final p = products.firstWhere((item) => item.id == 'PROD_NAMKEEN_01');
      expect(p.godownStockBoxes, equals(8));
      expect(p.godownReservedBoxes, equals(7));
      expect(p.availableGodownBoxes, equals(1)); // 8 - 7 = 1 box available

      // Adjusting by another -2 cartons would leave 6 physical < 7 reserved -> Must fail
      expect(
        () => repository.adjustStock(
          productId: 'PROD_NAMKEEN_01',
          cartonDelta: -2,
          loosePieceDelta: 0,
          reason: 'Excessive deduction',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Checkpoint 2 — Concurrency & Race Condition Simulation', () {
    test('Simultaneous reservations on last available stock unit: exactly one succeeds', () async {
      // Set godown stock to exactly 1 carton (24 pieces)
      await (db.update(db.inventorySnapshots)
            ..where((tbl) => tbl.productId.equals('PROD_NAMKEEN_01')))
          .write(
        const InventorySnapshotsCompanion(
          godownCartons: drift.Value(1),
          godownLoosePieces: drift.Value(0),
          reservedCartons: drift.Value(0),
          reservedLoosePieces: drift.Value(0),
        ),
      );

      // Two simultaneous sales reps try to reserve the full 24 pieces for different orders
      int successCount = 0;
      int failureCount = 0;

      Future<void> attemptReservation(String orderId) async {
        try {
          await repository.reserveStock(
            productId: 'PROD_NAMKEEN_01',
            pieces: 24,
            orderId: orderId,
          );
          successCount++;
        } catch (e) {
          failureCount++;
        }
      }

      await Future.wait([
        attemptReservation('ORD_CONCURRENT_A'),
        attemptReservation('ORD_CONCURRENT_B'),
      ]);

      expect(successCount, equals(1), reason: 'Exactly one order must succeed in reserving the last stock unit');
      expect(failureCount, equals(1), reason: 'The competing order must fail due to insufficient stock');

      final products = await repository.getAllProducts();
      final p = products.firstWhere((item) => item.id == 'PROD_NAMKEEN_01');
      expect(p.godownStockBoxes, equals(1));
      expect(p.godownReservedBoxes, equals(1));
      expect(p.availableGodownPieces, equals(0), reason: 'Available stock must be 0, never negative');
    });
  });

  group('Checkpoint 2 — FEFO (First-Expired-First-Out) Batch Management', () {
    test('Batches are picked strictly by earliest expiry date', () async {
      final now = DateTime.now();
      final batchA = ProductBatch(
        id: 'BATCH_A',
        productId: 'PROD_NAMKEEN_01',
        batchNo: 'LOT-2026-DEC',
        expiryDate: now.add(const Duration(days: 90)),
        receivedQuantity: 50,
        remainingQuantity: 50,
        createdAt: now,
        updatedAt: now,
      );
      final batchB = ProductBatch(
        id: 'BATCH_B',
        productId: 'PROD_NAMKEEN_01',
        batchNo: 'LOT-2026-NOV',
        expiryDate: now.add(const Duration(days: 30)), // Earliest expiry!
        receivedQuantity: 30,
        remainingQuantity: 30,
        createdAt: now,
        updatedAt: now,
      );
      final batchC = ProductBatch(
        id: 'BATCH_C',
        productId: 'PROD_NAMKEEN_01',
        batchNo: 'LOT-2027-JAN',
        expiryDate: now.add(const Duration(days: 180)),
        receivedQuantity: 100,
        remainingQuantity: 100,
        createdAt: now,
        updatedAt: now,
      );
      final batchNoExpiry = ProductBatch(
        id: 'BATCH_D',
        productId: 'PROD_NAMKEEN_01',
        batchNo: 'LOT-NO-EXPIRY',
        expiryDate: null, // No expiry date -> sorted last
        receivedQuantity: 40,
        remainingQuantity: 40,
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertBatch(batchA);
      await repository.upsertBatch(batchB);
      await repository.upsertBatch(batchC);
      await repository.upsertBatch(batchNoExpiry);

      final sortedBatches = await repository.getBatchesForProduct('PROD_NAMKEEN_01');

      // Verify FEFO sort order: Batch B (30d) -> Batch A (90d) -> Batch C (180d) -> Batch D (null)
      expect(sortedBatches.map((b) => b.id).toList(), equals([
        'BATCH_B',
        'BATCH_A',
        'BATCH_C',
        'BATCH_D',
      ]));

      // Plan picking for 45 pieces:
      // Should allocate full 30 from Batch B, and 15 from Batch A
      final pickPlan = await repository.planFefoPicking(
        productId: 'PROD_NAMKEEN_01',
        requiredPieces: 45,
      );

      expect(pickPlan.length, equals(2));
      expect(pickPlan[0].batch.id, equals('BATCH_B'));
      expect(pickPlan[0].allocatedPieces, equals(30));
      expect(pickPlan[1].batch.id, equals('BATCH_A'));
      expect(pickPlan[1].allocatedPieces, equals(15));
    });

    test('Expired and depleted batches are excluded from active FEFO picking', () async {
      final now = DateTime.now();
      final expiredBatch = ProductBatch(
        id: 'BATCH_EXPIRED',
        productId: 'PROD_NAMKEEN_01',
        batchNo: 'LOT-OLD-EXPIRED',
        expiryDate: now.subtract(const Duration(days: 10)),
        status: BatchStatus.expired,
        receivedQuantity: 20,
        remainingQuantity: 20,
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now,
      );

      final depletedBatch = ProductBatch(
        id: 'BATCH_DEPLETED',
        productId: 'PROD_NAMKEEN_01',
        batchNo: 'LOT-EMPTY',
        expiryDate: now.add(const Duration(days: 60)),
        status: BatchStatus.active,
        receivedQuantity: 50,
        remainingQuantity: 0, // Depleted (0 remaining)
        createdAt: now,
        updatedAt: now,
      );

      final freshBatch = ProductBatch(
        id: 'BATCH_FRESH',
        productId: 'PROD_NAMKEEN_01',
        batchNo: 'LOT-FRESH-01',
        expiryDate: now.add(const Duration(days: 60)),
        status: BatchStatus.active,
        receivedQuantity: 50,
        remainingQuantity: 50,
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertBatch(expiredBatch);
      await repository.upsertBatch(depletedBatch);
      await repository.upsertBatch(freshBatch);

      final activeBatches = await repository.getBatchesForProduct('PROD_NAMKEEN_01', activeOnly: true);
      expect(activeBatches.length, equals(1));
      expect(activeBatches.first.id, equals('BATCH_FRESH'));
    });
  });

  group('Checkpoint 2 — Database Schema Migration Verification (v6 -> v7)', () {
    test('Drift schema v7 table and column availability', () async {
      // Query sqlite_master to verify product_batches table and idx_batches_fefo index exist
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='product_batches';",
      ).get();
      expect(tables.length, equals(1), reason: 'product_batches table must exist in schema v7');

      final indices = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_batches_fefo';",
      ).get();
      expect(indices.length, equals(1), reason: 'idx_batches_fefo index must exist in schema v7');

      // Query table_info for inventory_snapshots to verify reserved columns exist
      final columns = await db.customSelect(
        "PRAGMA table_info('inventory_snapshots');",
      ).get();
      final columnNames = columns.map((row) => row.read<String>('name')).toSet();

      expect(columnNames.contains('reserved_cartons'), isTrue);
      expect(columnNames.contains('reserved_loose_pieces'), isTrue);
      expect(columnNames.contains('godown_cartons'), isTrue);
      expect(columnNames.contains('car_cartons'), isTrue);
      expect(columnNames.contains('damaged_cartons'), isTrue);
    });
  });
}
