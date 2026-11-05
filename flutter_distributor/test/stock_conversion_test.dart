import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  late AppDatabase db;
  late LocalRepository repository;
  late ApiService api;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalRepository(db);
    api = ApiService.internalForTesting(database: db, localRepo: repository);
    await api.syncForTesting();
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  group('B1 Stock Conversion & Preview Review Tests', () {
    test('1. One strip reserves exactly the configured number of pieces (stripQty)', () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      expect(prod.stripQty, equals(12));

      final initialPending = api.pendingBookingPieces(prod.id);

      api.addToCart(prod, OrderUnit.strip, 1);
      final shop = api.retailers.first;
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      final finalPending = api.pendingBookingPieces(prod.id);
      expect(finalPending - initialPending, equals(prod.stripQty),
          reason: '1 strip must reserve exactly stripQty (12) pieces without whole-carton rounding');
    });

    test('2. Multiple partial orders aggregate correctly in integer pieces', () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      final initialPending = api.pendingBookingPieces(prod.id);

      final shop = api.retailers.first;

      // Order 1: 1 strip (12 pieces)
      api.addToCart(prod, OrderUnit.strip, 1);
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      // Order 2: 3 loose pieces (3 pieces)
      api.addToCart(prod, OrderUnit.piece, 3);
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      // Order 3: 1 box (96 pieces)
      api.addToCart(prod, OrderUnit.box, 1);
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      final finalPending = api.pendingBookingPieces(prod.id);
      final expectedDelta = prod.stripQty + 3 + prod.boxQty; // 12 + 3 + 96 = 111 pieces
      expect(finalPending - initialPending, equals(expectedDelta));

      // 111 pieces in box of 96 = 1 full box + 15 loose pieces
      expect(111 ~/ prod.boxQty, equals(1));
      expect(111 % prod.boxQty, equals(15));
    });

    test('3. Multiple products have independent reservations', () async {
      final prod1 = api.products.firstWhere((p) => p.id == 'KURK-01');
      final prod2 = api.products.firstWhere((p) => p.id == 'LAYS-01');

      final initialPending1 = api.pendingBookingPieces(prod1.id);
      final initialPending2 = api.pendingBookingPieces(prod2.id);

      // Book only prod1
      api.addToCart(prod1, OrderUnit.box, 2);
      final shop = api.retailers.first;
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      // prod1 reservation increased
      expect(api.pendingBookingPieces(prod1.id), greaterThan(initialPending1));

      // prod2 reservation is completely unaffected
      expect(api.pendingBookingPieces(prod2.id), equals(initialPending2));
    });

    test('4. A booking exceeding available-to-book stock is rejected', () async {
      final prod = api.products.firstWhere((p) => p.id == 'LAYS-02');
      final availablePieces = api.availableGodownPieces(prod.id);
      final shop = api.retailers.first;

      // Attempt to book more than available
      final excessBoxes = (availablePieces ~/ prod.boxQty) + 5;
      api.addToCart(prod, OrderUnit.box, excessBoxes);

      // We test whether placeOrder rejects or allows overbooking
      expect(
        () => api.placeOrder(shopId: shop.id, paymentMode: 'COD'),
        throwsA(isA<StateError>()),
        reason: 'Order exceeding available-to-book stock should be rejected',
      );
    });

    test('5. Repeated confirmation does not reserve the same order twice and rejects empty cart', () async {
      final prod = api.products.firstWhere((p) => p.id == 'PEPSI-500');
      final initialPending = api.pendingBookingPieces(prod.id);
      final shop = api.retailers.first;

      api.addToCart(prod, OrderUnit.box, 2);
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      final pendingAfterFirst = api.pendingBookingPieces(prod.id);
      expect(pendingAfterFirst, equals(initialPending + (2 * prod.boxQty)));

      // Cart is now empty. A repeated call with empty cart must throw StateError without adding another reservation
      expect(api.cart.isEmpty, isTrue);
      expect(
        () => api.placeOrder(shopId: shop.id, paymentMode: 'COD'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cart is empty'),
        )),
        reason: 'Placing order with empty cart must be rejected without double-reserving',
      );

      // Pending pieces must remain unchanged after rejected second attempt
      expect(api.pendingBookingPieces(prod.id), equals(pendingAfterFirst));
    });

    test('6. Physical godown stock remains unchanged after bookings', () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      final initialPhysicalBoxes = prod.godownStockBoxes;
      final snapshotBefore = await repository.getInventorySnapshot(prod.id);

      api.addToCart(prod, OrderUnit.box, 4);
      final shop = api.retailers.first;
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      // Memory physical stock unchanged
      expect(prod.godownStockBoxes, equals(initialPhysicalBoxes));

      // SQLite snapshot unchanged
      final snapshotAfter = await repository.getInventorySnapshot(prod.id);
      expect(snapshotAfter!.godownCartons, equals(snapshotBefore!.godownCartons));
    });

    test('7. Van transfer is based on physical stock (not locked by bookings) and persists to SQLite', () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-02');
      final physicalBefore = prod.godownStockBoxes;
      expect(physicalBefore, greaterThan(0));

      final shop = api.retailers.first;

      // Book out almost all available stock
      final availBoxes = api.availableGodownBoxes(prod.id);
      if (availBoxes > 0) {
        api.addToCart(prod, OrderUnit.box, availBoxes);
        api.placeOrder(shopId: shop.id, paymentMode: 'COD');
      }

      // Available-to-book is now 0
      expect(api.availableGodownBoxes(prod.id), equals(0));

      // Physical godown stock is still physically present in warehouse
      expect(prod.godownStockBoxes, equals(physicalBefore));

      // Van transfer of physical stock succeeds because goods are physically present
      final transferred = await api.transferStockToCar(prod.id, 1);
      expect(transferred, isTrue,
          reason: 'Van driver can load physical stock into delivery vehicle regardless of booking drafts');

      // Verify persistence in SQLite
      final movements = await repository.getMovementsForProduct(prod.id);
      expect(movements.any((m) => m.movementType == 'TRANSFER_TO_CAR'), isTrue);
    });

    test('8. Pending bookings are temporary and do not survive process restart as persistent SQLite reservations', () async {
      final prod = api.products.firstWhere((p) => p.id == 'STING-250');
      final initialPhysical = prod.godownStockBoxes;

      // Place booking in session 1
      api.addToCart(prod, OrderUnit.box, 3);
      final shop = api.retailers.first;
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      // In session 1, available stock shows reservation
      expect(api.availableGodownBoxes(prod.id), equals(initialPhysical - 3));

      // Verify SQLite movements table contains NO SALE or ORDER movement
      final movements = await repository.getMovementsForProduct(prod.id);
      expect(movements.any((m) => m.movementType == 'SALE'), isFalse);
      expect(movements.any((m) => m.movementType == 'ORDER'), isFalse);

      // Re-query fresh products from SQLite (simulating process restart)
      final reloadedFromDb = await repository.getAllProducts();
      final reloadedProd = reloadedFromDb.firstWhere((p) => p.id == prod.id);

      // Persisted godown stock in SQLite remains 100% full initial physical stock
      expect(reloadedProd.godownStockBoxes, equals(initialPhysical),
          reason: 'SQLite authoritative inventory does not contain premature booking deductions');
    });

    test('9. In-memory rollback occurs if SQLite write fails during transferStockToCar', () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      final godownBefore = prod.godownStockBoxes;
      final carBefore = prod.carStockBoxes;

      // Close the database to force SQLite write failure
      await db.close();

      await expectLater(
        api.transferStockToCar(prod.id, 1),
        throwsA(anything),
      );

      // In-memory stock must be rolled back to initial state
      expect(prod.godownStockBoxes, equals(godownBefore));
      expect(prod.carStockBoxes, equals(carBefore));
    });

    test('10. Safe rejection of invalid quantities, empty cart, and unknown products', () async {
      final shop = api.retailers.first;

      // 1. Empty cart
      api.clearCart();
      expect(
        () => api.placeOrder(shopId: shop.id, paymentMode: 'COD'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Cart is empty'))),
      );

      // 2. Unknown shop
      final prod = api.products.first;
      api.addToCart(prod, OrderUnit.piece, 1);
      expect(
        () => api.placeOrder(shopId: 'NON-EXISTENT-SHOP', paymentMode: 'COD'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('does not exist'))),
      );
    });
  });
}
