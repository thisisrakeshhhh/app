import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_exceptions.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/domain/outbox/outbox_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';

class ZeroNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access strictly forbidden in Phase O1.1 offline tests');
  }
}

void main() {
  HttpOverrides.global = ZeroNetworkHttpOverrides();

  group('RouteFlow Phase O1.1 — Order Confirmation Durability & Integrity Tests', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const testSession = UserSession(
      userId: 'usr_sales_ramesh',
      name: 'Ramesh Sharma',
      activeOrganizationId: 'org_jaipur_dist',
      activeRole: 'SALES',
      organizations: [
        OrganizationMembership(
          id: 'org_jaipur_dist',
          name: 'Jaipur FMCG Distributors',
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
      await db.close();
    });

    // TEST-01: Commit-before-UI-Success & Outbox Durability
    test('TEST-01: Explicit confirmation writes durable CREATE_ORDER outbox row to SQLite disk', () async {
      final product = api.products.first; // Kurkure
      final shop = api.retailers.first;

      api.addToCart(product, OrderUnit.box, 2);
      expect(api.cart.isNotEmpty, isTrue);

      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      expect(order.orderNumber, startsWith('LOCAL-ORD-'));
      expect(order.stage, equals(OrderLifecycleStage.booking));
      expect(api.cart.isEmpty, isTrue);

      // Verify outbox row in SQLite
      final pending = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jaipur_dist',
        userId: 'usr_sales_ramesh',
      );
      expect(pending.length, equals(1));
      expect(pending.first.mutationType, equals('CREATE_ORDER'));
      expect(pending.first.provisionalBusinessId, equals(order.id));
      expect(pending.first.syncStatus, equals('PENDING'));
    });

    // TEST-02: App Restart Reconstruction
    test('TEST-02: Cold boot reconstructs provisional DistributorOrder from outbox mutations', () async {
      final product = api.products.first;
      final shop = api.retailers.first;

      api.addToCart(product, OrderUnit.box, 2);
      final confirmed = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'Credit',
      );

      final availableBeforeRestart = api.availableGodownPieces(product.id);

      // Simulate app kill: create a brand new ApiService sharing the same SQLite DB
      final restartedApi = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => testSession,
      );
      // Before sync, only initial seed orders exist
      expect(restartedApi.orders.any((o) => o.id == confirmed.id), isFalse);

      // Cold boot sync
      await restartedApi.syncForTesting(seed: false);

      // Verify reconstructed order appears in memory
      final recovered = restartedApi.orders.firstWhere((o) => o.id == confirmed.id);
      expect(recovered.orderNumber, equals(confirmed.orderNumber));
      expect(recovered.stage, equals(OrderLifecycleStage.booking));
      expect(recovered.totalPaise, equals(confirmed.totalPaise));
      expect(recovered.items.first.totalPieces, equals(192)); // 2 boxes * 96 pcs

      // Verify virtual reservation is restored after cold boot
      expect(restartedApi.availableGodownPieces(product.id), equals(availableBeforeRestart));
    });

    // TEST-03: Retry with Same Key & Payload (Idempotent Replay)
    test('TEST-03: Replay with same idempotency key and identical cart returns existing order safely', () async {
      final product = api.products.first;
      final shop = api.retailers.first;
      const idempotencyKey = 'idemp_stable_checkout_001';

      api.addToCart(product, OrderUnit.box, 2);
      final firstOrder = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
        checkoutIdempotencyKey: idempotencyKey,
      );

      // Re-populate cart identically
      api.addToCart(product, OrderUnit.box, 2);
      final secondOrder = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
        checkoutIdempotencyKey: idempotencyKey,
      );

      expect(secondOrder.id, equals(firstOrder.id));
      expect(secondOrder.orderNumber, equals(firstOrder.orderNumber));

      // Assert outbox row count remains exactly 1 (no duplicate rows)
      final allPending = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jaipur_dist',
        userId: 'usr_sales_ramesh',
      );
      expect(allPending.length, equals(1));
    });

    // TEST-04: Mismatched Payload with Same Key
    test('TEST-04: Reusing idempotency key with modified cart throws IdempotencyPayloadMismatchException', () async {
      final product = api.products.first;
      final shop = api.retailers.first;
      const idempotencyKey = 'idemp_key_tamper_guard';

      api.addToCart(product, OrderUnit.box, 1);
      await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
        checkoutIdempotencyKey: idempotencyKey,
      );

      // Try re-submitting with altered quantity
      api.addToCart(product, OrderUnit.box, 5);
      expect(
        () => api.confirmOrderDurable(
          shopId: shop.id,
          paymentMode: 'COD',
          checkoutIdempotencyKey: idempotencyKey,
        ),
        throwsA(isA<IdempotencyPayloadMismatchException>()),
      );

      // Cart is preserved upon payload mismatch failure
      expect(api.cart.isNotEmpty, isTrue);

      // SQLite outbox remains exactly 1 row
      final count = await db.outboxDao.countPending(
        organizationId: 'org_jaipur_dist',
        userId: 'usr_sales_ramesh',
      );
      expect(count, equals(1));
    });

    // TEST-05: Genuinely New Identical Orders
    test('TEST-05: Two consecutive identical orders produce two distinct outbox rows and order numbers', () async {
      final product = api.products.first;
      final shop = api.retailers.first;

      api.addToCart(product, OrderUnit.box, 2);
      final order1 = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      api.addToCart(product, OrderUnit.box, 2);
      final order2 = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      expect(order1.id, isNot(equals(order2.id)));
      expect(order1.orderNumber, isNot(equals(order2.orderNumber)));

      final allPending = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jaipur_dist',
        userId: 'usr_sales_ramesh',
      );
      expect(allPending.length, equals(2));
      expect(allPending[0].sequenceOrder, equals(1));
      expect(allPending[1].sequenceOrder, equals(2));
    });

    // TEST-06: Concurrent Confirmations Serialize Monotonically
    test('TEST-06: Concurrent order confirmations serialize cleanly with monotonic sequences', () async {
      final p1 = api.products[0];
      final p2 = api.products[1];

      // Insert two mutations concurrently into outbox DAO
      final future1 = db.outboxDao.insertOrderMutationAtomic(
        id: 'out_race_1',
        organizationId: 'org_jaipur_dist',
        userId: 'usr_sales_ramesh',
        idempotencyKey: 'idemp_race_1',
        mutationType: 'CREATE_ORDER',
        payloadJson: '{"item": "${p1.id}"}',
        provisionalBusinessId: 'ord_race_1',
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      final future2 = db.outboxDao.insertOrderMutationAtomic(
        id: 'out_race_2',
        organizationId: 'org_jaipur_dist',
        userId: 'usr_sales_ramesh',
        idempotencyKey: 'idemp_race_2',
        mutationType: 'CREATE_ORDER',
        payloadJson: '{"item": "${p2.id}"}',
        provisionalBusinessId: 'ord_race_2',
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch + 10,
      );

      final results = await Future.wait([future1, future2]);
      final seqs = results.map((m) => m.sequenceOrder).toList()..sort();
      expect(seqs, equals([1, 2]));

      final pending = await db.outboxDao.getPendingMutations(
        organizationId: 'org_jaipur_dist',
        userId: 'usr_sales_ramesh',
      );
      expect(pending.length, equals(2));
      expect(pending.first.sequenceOrder, equals(1));
      expect(pending.last.sequenceOrder, equals(2));
    });

    // TEST-07: Financial & Stock Isolation Invariant
    test('TEST-07: Confirming order does NOT alter physical InventorySnapshots or Retailers in SQLite', () async {
      final product = api.products.first;
      final shop = api.retailers.first;

      final initialDbProducts = await repo.getAllProducts();
      final initialDbRetailers = await repo.getAllRetailers();

      final initialStock = initialDbProducts.firstWhere((p) => p.id == product.id).godownStockBoxes;
      final initialOutstanding = initialDbRetailers.firstWhere((r) => r.id == shop.id).outstandingPaise;

      api.addToCart(product, OrderUnit.box, 3);
      await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'Credit',
      );

      // Verify physical stock and retailer credit in Drift SQLite are 100% UNCHANGED
      final postDbProducts = await repo.getAllProducts();
      final postDbRetailers = await repo.getAllRetailers();

      final postStock = postDbProducts.firstWhere((p) => p.id == product.id).godownStockBoxes;
      final postOutstanding = postDbRetailers.firstWhere((r) => r.id == shop.id).outstandingPaise;

      expect(postStock, equals(initialStock));
      expect(postOutstanding, equals(initialOutstanding));
    });

    // TEST-08: Packaging Ratio Preservation
    test('TEST-08: Reconstructed order retains exact original packaging units and piece count', () async {
      final product = api.products.first; // Kurkure (10 strip, 50 box)
      final shop = api.retailers.first;

      api.addToCart(product, OrderUnit.strip, 3); // 3 strips = 30 pieces
      final confirmed = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      // Alter catalogue product packaging in local database to simulate master data change
      await repo.upsertProduct(ProductItem(
        id: product.id,
        name: product.name,
        hindiName: product.hindiName,
        category: product.category,
        mrpRupees: product.mrpRupees,
        piecePricePaise: product.piecePricePaise,
        stripQty: 8, // Changed from 10 to 8
        boxQty: 40,  // Changed from 50 to 40
        godownStockBoxes: product.godownStockBoxes,
      ));

      // Reconstruct
      final restartedApi = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => testSession,
      );
      await restartedApi.syncForTesting(seed: false);

      final recovered = restartedApi.orders.firstWhere((o) => o.id == confirmed.id);
      final item = recovered.items.first;

      expect(item.unit, equals(OrderUnit.strip));
      expect(item.quantity, equals(3));
      expect(item.totalPieces, equals(36)); // Retained original packaging ratio 12 pcs/strip!
    });

    // TEST-09: Reservation Lifecycle Transition
    test('TEST-09: Advancing order from booking to readyStock releases booking reservation', () async {
      final product = api.products.first;
      final shop = api.retailers.first;

      final initialAvailable = api.availableGodownPieces(product.id);

      api.addToCart(product, OrderUnit.box, 2); // 2 boxes * 96 = 192 pieces
      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      expect(api.availableGodownPieces(product.id), equals(initialAvailable - 192));

      // Advance stage to readyStock
      api.advanceOrderStage(order.id);
      expect(order.stage, equals(OrderLifecycleStage.readyStock));

      // Booking reservation is released; available godown pieces restored to full!
      expect(api.availableGodownPieces(product.id), equals(initialAvailable));
    });

    // TEST-10: Session Identity Enforcement
    test('TEST-10: Unauthenticated user cannot confirm order and writes zero SQLite rows', () async {
      final unauthApi = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => null, // No session
      );
      await unauthApi.syncForTesting(seed: false);

      unauthApi.addToCart(unauthApi.products.first, OrderUnit.box, 1);
      expect(
        () => unauthApi.confirmOrderDurable(
          shopId: unauthApi.retailers.first.id,
          paymentMode: 'COD',
        ),
        throwsA(isA<UnauthenticatedException>()),
      );

      final outboxCount = await db.outboxDao.countAllPendingAcrossUsers();
      expect(outboxCount, equals(0));
    });

    // TEST-11: Zero Network Activity
    test('TEST-11: Order confirmation executes strictly offline without network requests', () async {
      // HttpOverrides.global asserts createHttpClient throws StateError
      final product = api.products.first;
      final shop = api.retailers.first;

      api.addToCart(product, OrderUnit.box, 1);
      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      expect(order.orderNumber, startsWith('LOCAL-ORD-'));
    });

    // TEST-12: Existing B1 Compatibility
    test('TEST-12: Legacy synchronous placeOrder continues to function backwards-compatibly', () {
      final product = api.products.first;
      final shop = api.retailers.first;

      api.addToCart(product, OrderUnit.box, 1);
      final order = api.placeOrder(
        shopId: shop.id,
        paymentMode: 'COD',
      );

      expect(order.orderNumber, startsWith('ROUT-'));
      expect(api.orders.first.id, equals(order.id));
      expect(api.cart.isEmpty, isTrue);
    });
  });
}
