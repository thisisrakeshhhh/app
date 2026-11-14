import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/services/sync_worker.dart';
import 'helpers/test_catalog_helper.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Checkpoint 5: Sales Order Booking with Live Reservation Integration Suite', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const testSession = UserSession(
      userId: 'usr_sales_sunil',
      name: 'Sunil Choudhary',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'SALES',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur Marwar Sweets & FMCG',
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
      await registerTestCatalogFixtures(api, repo);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Real-time stock reservation lock: Available = Physical - Reserved in Drift SQLite & memory', () async {
      final product = api.products.firstWhere((p) => p.id == 'KURK-01');
      final shop = api.retailers.first;

      final initialPhysicalBoxes = product.godownStockBoxes;
      final initialPhysicalPieces = product.godownStockBoxes * product.boxQty;
      final initialAvailablePieces = api.availableGodownPieces(product.id);
      expect(initialAvailablePieces, equals(initialPhysicalPieces));
      expect(api.pendingBookingPieces(product.id), equals(0));

      // Book 2 boxes (2 * 96 = 192 pieces)
      api.addToCart(product, OrderUnit.box, 2);
      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      // Verify order stage is booking
      expect(order.stage, equals(OrderLifecycleStage.booking));

      // Verify RAM calculations
      expect(api.pendingBookingPieces(product.id), equals(192));
      expect(api.availableGodownPieces(product.id), equals(initialPhysicalPieces - 192));
      expect(api.availableGodownBoxes(product.id), equals(initialPhysicalBoxes - 2));

      // Verify physical stock is untouched (zero premature deduction before warehouse dispatch)
      final prodInMemory = api.products.firstWhere((p) => p.id == product.id);
      expect(prodInMemory.godownStockBoxes, equals(initialPhysicalBoxes));
      expect(prodInMemory.godownReservedBoxes, equals(2));
      expect(prodInMemory.availableGodownPieces, equals(initialPhysicalPieces - 192));

      // Verify Drift SQLite snapshot has reservedCartons updated
      final snapshot = await (db.select(db.inventorySnapshots)
            ..where((tbl) => tbl.productId.equals(product.id)))
          .getSingle();
      expect(snapshot.godownCartons, equals(initialPhysicalBoxes));
      expect(snapshot.reservedCartons, equals(2));
      expect(snapshot.reservedLoosePieces, equals(0));
    });

    test('2. Dynamic visual badges: In Stock, Low Stock, and Out of Stock react strictly to Available stock', () async {
      // Use existing product with known packaging
      final testProd = api.products.firstWhere((p) => p.id == 'KURK-01');
      final totalBoxes = testProd.godownStockBoxes;
      final reorderLevel = testProd.reorderLevelBoxes;
      expect(totalBoxes, greaterThan(reorderLevel));

      // Initial state: Available = totalBoxes > reorderLevel => IN STOCK
      expect(testProd.isInStock, isTrue);
      expect(testProd.isLowStock, isFalse);
      expect(testProd.isOutOfStock, isFalse);

      // Step 2: Reserve stock so that available boxes <= reorderLevel => LOW STOCK
      final reserveBoxesForLow = totalBoxes - reorderLevel;
      api.setVirtualReservationForTesting(testProd.id, reserveBoxesForLow * testProd.boxQty);
      final pLow = api.products.firstWhere((p) => p.id == testProd.id);
      expect(pLow.safeAvailableGodownBoxes, equals(reorderLevel));
      expect(pLow.isLowStock, isTrue, reason: '$reorderLevel boxes available <= reorder level $reorderLevel must trigger Low Stock');
      expect(pLow.isInStock, isFalse);
      expect(pLow.isOutOfStock, isFalse);

      // Step 3: Reserve 100% of physical stock -> Available = 0 => OUT OF STOCK
      api.setVirtualReservationForTesting(testProd.id, totalBoxes * testProd.boxQty);
      final pOut = api.products.firstWhere((p) => p.id == testProd.id);
      expect(pOut.safeAvailableGodownPieces, equals(0));
      expect(pOut.isOutOfStock, isTrue, reason: '0 available pieces must trigger Out of Stock badge');
      expect(pOut.isLowStock, isFalse);
      expect(pOut.isInStock, isFalse);
    });

    test('3. Overselling Prevention: Attempting to confirm quantity exceeding available stock is strictly blocked', () async {
      final product = api.products.firstWhere((p) => p.id == 'LAYS-02');
      final availableBoxes = api.availableGodownBoxes(product.id);
      final initialOrdersCount = api.orders.length;

      // Add 1 more box than available to cart
      api.addToCart(product, OrderUnit.box, availableBoxes + 1);

      // Verify canAddToCart helper reports false
      expect(api.canAddToCart(product, OrderUnit.box, 1), isFalse);

      // Attempting confirmation must throw StateError with descriptive overselling message
      expect(
        () => api.confirmOrderDurable(
          shopId: api.retailers.first.id,
          paymentMode: 'COD',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exceeds available stock'))),
      );

      // Verify ZERO outbox mutations or orders were inserted
      expect(api.orders.length, equals(initialOrdersCount));
      final pendingMutations = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jodhpur_dist',
        userId: 'usr_sales_sunil',
      );
      expect(pendingMutations.isEmpty, isTrue);
    });

    test('4. Concurrency & Release Safety: Virtual reservation is auto-released upon order cancellation or rejection', () async {
      final product = api.products.firstWhere((p) => p.id == 'KURK-01');
      final shop = api.retailers.first;

      final initialAvailable = api.availableGodownPieces(product.id);

      // 1. Place booking of 3 boxes
      api.addToCart(product, OrderUnit.box, 3);
      final piecesReserved = 3 * product.boxQty;
      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'Credit',
      );

      expect(api.availableGodownPieces(product.id), equals(initialAvailable - piecesReserved));

      // 2. Rep cancels order or server rejects it
      api.cancelOrder(order.id, reason: 'Retailer requested cancellation');

      // 3. Verify order transitioned to rejected
      final cancelledOrder = api.orders.firstWhere((o) => o.id == order.id);
      expect(cancelledOrder.stage, equals(OrderLifecycleStage.rejected));

      // 4. Invariant: Available stock is immediately restored to 100% full
      expect(api.availableGodownPieces(product.id), equals(initialAvailable));
      expect(api.pendingBookingPieces(product.id), equals(0));

      final prodRestored = api.products.firstWhere((p) => p.id == product.id);
      expect(prodRestored.godownReservedBoxes, equals(0));
      expect(prodRestored.isInStock, isTrue);
    });

    test('5. Multi-Unit Packaging (Box, Strip, Loose Piece) calculation preserves integer precision', () async {
      // Find a product with stripQty > 1 (e.g. Parle-G: stripQty 12, boxQty 96)
      final product = api.products.firstWhere((p) => p.stripQty > 1);
      final shop = api.retailers.first;

      final initialPending = api.pendingBookingPieces(product.id);
      final initialAvailable = api.availableGodownPieces(product.id);

      // Add mixed combo: 1 box + 2 strips + 5 loose pieces
      final expectedTotalPieces = (1 * product.piecesForUnit(OrderUnit.box)) +
          (2 * product.piecesForUnit(OrderUnit.strip)) +
          (5 * product.piecesForUnit(OrderUnit.piece));
      api.addMixedUnitsToCart(
        product,
        boxes: 1,
        strips: 2,
        pieces: 5,
      );

      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      expect(order.items.length, equals(3));
      final reservedTotal = order.items.fold<int>(0, (sum, it) => sum + it.totalPieces);
      expect(reservedTotal, equals(expectedTotalPieces));

      // Assert reservation locks exact piece count without fractional errors
      expect(api.pendingBookingPieces(product.id), equals(initialPending + expectedTotalPieces));
      expect(api.availableGodownPieces(product.id), equals(initialAvailable - expectedTotalPieces));
    });

    test('6. Offline Order Outbox: Queuing with provisional ID (ord_temp_*) and SQLite durability', () async {
      final product = api.products.first;
      final shop = api.retailers.first;

      api.addToCart(product, OrderUnit.box, 1);
      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      // Provisional order ID must follow ord_temp_* convention
      expect(order.id, startsWith('ord_temp_'));
      expect(order.orderNumber, startsWith('LOCAL-ORD-'));

      // Check SQLite outbox persistence
      final pending = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jodhpur_dist',
        userId: 'usr_sales_sunil',
      );
      expect(pending.length, equals(1));
      expect(pending.first.mutationType, equals('CREATE_ORDER'));
      expect(pending.first.provisionalBusinessId, equals(order.id));
      expect(pending.first.syncStatus, equals('PENDING'));

      final payload = jsonDecode(pending.first.payloadJson);
      expect(payload['provisionalOrderId'], equals(order.id));
      expect(payload['items'], isNotEmpty);
    });

    test('7. Background Sync: Server 409 rejection marks outbox FAILED_PERMANENT and auto-releases virtual reservation', () async {
      final product = api.products.first;
      final shop = api.retailers.first;
      final initialAvailable = api.availableGodownPieces(product.id);

      api.addToCart(product, OrderUnit.box, 2);
      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );
      expect(api.availableGodownPieces(product.id), equals(initialAvailable - (2 * product.boxQty)));

      // Mock client that returns 409 INSUFFICIENT_STOCK
      final mockClient = MockClient((request) async {
        final pending = await db.outboxDao.getPendingMutations(
          organizationId: 'org_jodhpur_dist',
          userId: 'usr_sales_sunil',
        );
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'INSUFFICIENT_STOCK',
            'mutationId': pending.first.id,
            'message': 'Warehouse godown ran out of stock concurrently',
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final syncWorker = SyncWorker(
        db: db,
        apiService: api,
        httpClient: mockClient,
        baseUrl: 'https://test-marwar.routeflow.internal',
        accessTokenProvider: () async => 'test_token',
      );

      final result = await syncWorker.processPendingOutbox(
        organizationId: 'org_jodhpur_dist',
        userId: 'usr_sales_sunil',
      );
      expect(result.success, isFalse);
      expect(result.hasPermanentFailure, isTrue);

      // Verify outbox mutation was marked FAILED_PERMANENT
      final failedMutations = await db.outboxDao.getFailedMutations();
      expect(failedMutations.length, equals(1));
      expect(failedMutations.first.lastErrorCode, equals('INSUFFICIENT_STOCK'));

      // Invariant: Virtual reservation was automatically released by SyncWorker upon rejection
      expect(api.availableGodownPieces(product.id), equals(initialAvailable));
      final rejectedOrder = api.orders.firstWhere((o) => o.id == order.id);
      expect(rejectedOrder.stage, equals(OrderLifecycleStage.rejected));
    });
  });
}
