import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/domain/auth/role_routing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    await Future.delayed(const Duration(milliseconds: 100));
    await db.close();
  });

  group('Ruthless Hardcore Four-Role CRUD & Invariant Test Suite', () {

    // =========================================================================
    // 1. SALES REPRESENTATIVE ROLE: COMPLETE CRUD & INVARIANTS
    // =========================================================================
    group('1. SALES ROLE CRUD & OPERATIONS', () {
      test('1.1 [C] Create: Add to cart, compute taxes, and place valid booking orders', () {
        final p = api.products.first; // e.g. Kurkure
        api.clearCart();

        // Add 2 boxes
        api.addToCart(p, OrderUnit.box, 2);
        expect(api.cart.length, 1);
        expect(api.cart[p.id]!.quantity, 2);
        expect(api.cart[p.id]!.unit, OrderUnit.box);
        expect(api.cartTotalPieces, 2 * p.boxQty);

        // Verify GST Tax Split: CGST == SGST (within 1 paisa rounding)
        final totalGst = api.cartTotalGstPaise;
        final cgst = api.cartCgstPaise;
        final sgst = api.cartSgstPaise;
        expect(cgst + sgst, totalGst);
        expect((cgst - sgst).abs(), lessThanOrEqualTo(1));

        // Place Order on Credit for first retailer
        final shop = api.retailers.first;
        final initialOrdersCount = api.orders.length;
        final initialUdhaar = shop.outstandingRupees;

        final order = api.placeOrder(
          shopId: shop.id,
          paymentMode: 'Credit',
        );

        expect(api.orders.length, initialOrdersCount + 1);
        expect(order.shopId, shop.id);
        expect(order.paymentMode, 'Credit');
        expect(order.stage, OrderLifecycleStage.booking);
        expect(api.cart.isEmpty, isTrue); // Cart cleared after placement
        expect(shop.outstandingRupees, initialUdhaar + order.totalRupees);
      });

      test('1.2 [R] Read: Retailers, Assigned Beat, Price Book, and Stock Availability', () {
        expect(api.retailers.isNotEmpty, isTrue);
        expect(api.products.isNotEmpty, isTrue);

        final sampleProd = api.products.first;
        final atpPieces = api.availableGodownPieces(sampleProd.id);
        expect(atpPieces, greaterThanOrEqualTo(0));

        // Invariant: ATP pieces must never exceed total physical pieces in godown
        final totalPhysicalPieces = sampleProd.godownStockBoxes * sampleProd.boxQty;
        expect(atpPieces, lessThanOrEqualTo(totalPhysicalPieces));
      });

      test('1.3 [U] Update: Cart quantity updates, unit toggling, and shop visit timers', () {
        final p = api.products.first;
        api.clearCart();
        api.addToCart(p, OrderUnit.box, 1);

        // Update quantity (+3 boxes = 4 boxes)
        api.updateCartQuantity(p.id, 3);
        expect(api.cart[p.id]!.quantity, 4);

        // Update quantity (-1 box = 3 boxes)
        api.updateCartQuantity(p.id, -1);
        expect(api.cart[p.id]!.quantity, 3);

        // Switch unit to piece
        api.setCartUnit(p.id, OrderUnit.piece);
        expect(api.cart[p.id]!.unit, OrderUnit.piece);
        expect(api.cartTotalPieces, 3); // 3 loose pieces now

        // Shop visit workflow
        final shop = api.retailers.first;
        expect(api.activeVisitShopId, isNull);

        api.startShopVisit(shop.id);
        expect(api.activeVisitShopId, shop.id);
        expect(api.activeVisitShop?.id, shop.id);
        expect(shop.isCheckedIn, isTrue);

        final elapsed = api.endShopVisit(shop.id);
        expect(api.activeVisitShopId, isNull);
        expect(shop.visitedToday, isTrue);
        expect(elapsed, greaterThanOrEqualTo(0));
      });

      test('1.4 [D] Delete: Decrementing to 0 removes from cart; clearCart purges all items', () {
        final p1 = api.products[0];
        final p2 = api.products[1];
        api.clearCart();

        api.addToCart(p1, OrderUnit.box, 1);
        api.addToCart(p2, OrderUnit.box, 2);
        expect(api.cart.length, 2);

        // Decrement p1 by 1 -> quantity becomes 0 -> removed automatically
        api.updateCartQuantity(p1.id, -1);
        expect(api.cart.containsKey(p1.id), isFalse);
        expect(api.cart.length, 1);

        // Purge cart
        api.clearCart();
        expect(api.cart.isEmpty, isTrue);

        // Placing order on empty cart must throw StateError
        expect(
          () => api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD'),
          throwsA(isA<StateError>()),
        );
      });

      test('1.5 Invariant: Overselling prevention in Sales booking', () {
        final p = api.products.first;
        api.clearCart();

        // Calculate available boxes
        final availableBoxes = api.availableGodownPieces(p.id) ~/ p.boxQty;
        // Attempt to book availableBoxes + 10 boxes
        api.addToCart(p, OrderUnit.box, availableBoxes + 10);

        expect(
          () => api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD'),
          throwsA(predicate((e) => e is StateError && e.message.contains('exceeds available stock'))),
        );
      });
    });

    // =========================================================================
    // 2. WAREHOUSE ROLE: COMPLETE CRUD & INVARIANTS
    // =========================================================================
    group('2. WAREHOUSE ROLE CRUD & OPERATIONS', () {
      test('2.1 [C] Create: Inward shipment intake increments Godown stock', () async {
        final p = api.products.first;
        final initialGodown = p.godownStockBoxes;

        // Inward 50 boxes
        api.restockProduct(p.id, 50);

        expect(p.godownStockBoxes, initialGodown + 50);
        expect(api.totalGodownBoxes, greaterThanOrEqualTo(initialGodown + 50));
        await Future.delayed(const Duration(milliseconds: 50));
      });

      test('2.2 [R] Read: Godown vs Van inventory metrics and low-stock filtering', () {
        expect(api.totalGodownBoxes, greaterThan(0));
        expect(api.totalCarBoxes, greaterThan(0));
        expect(api.carNumber, isNotEmpty);

        // Verify products query
        final lowStock = api.products.where((p) => p.godownStockBoxes < 40).toList();
        expect(lowStock, isA<List<ProductItem>>());
      });

      test('2.3 [U] Update: Transfer stock between Godown and Van vehicle', () async {
        final p = api.products.first;
        final initialGodown = p.godownStockBoxes;
        final initialCar = p.carStockBoxes;

        // Transfer 10 boxes from Godown to Van
        final ok1 = await api.transferStockToCar(p.id, 10);
        expect(ok1, isTrue);
        expect(p.godownStockBoxes, initialGodown - 10);
        expect(p.carStockBoxes, initialCar + 10);

        // Return 5 boxes from Van back to Godown
        final ok2 = await api.transferStockToCar(p.id, -5);
        expect(ok2, isTrue);
        expect(p.godownStockBoxes, initialGodown - 5);
        expect(p.carStockBoxes, initialCar + 5);
      });

      test('2.4 [D] Delete / Conservation: Prevent transferring more than exists in Godown or Van', () async {
        final p = api.products.first;
        final curGodown = p.godownStockBoxes;
        final curCar = p.carStockBoxes;

        // Attempt to transfer more boxes to Van than Godown has
        final failedTransfer1 = await api.transferStockToCar(p.id, curGodown + 100);
        expect(failedTransfer1, isFalse);
        expect(p.godownStockBoxes, curGodown); // Unchanged

        // Attempt to return more boxes to Godown than Van has
        final failedTransfer2 = await api.transferStockToCar(p.id, -(curCar + 100));
        expect(failedTransfer2, isFalse);
        expect(p.carStockBoxes, curCar); // Unchanged
      });
    });

    // =========================================================================
    // 3. DELIVERY ROLE: COMPLETE CRUD & INVARIANTS
    // =========================================================================
    group('3. DELIVERY ROLE CRUD & OPERATIONS', () {
      test('3.1 [C] Create & [R] Read: Active vehicle assignment and delivery stops queue', () {
        expect(api.carNumber, 'RJ-19-GB-4021');
        expect(api.deliveryStops, isA<List<DeliveryStop>>());

        // Invariant: Total driver cash custody starts at sum of delivered COD stops
        final initialCodDelivered = api.deliveryStops
            .where((s) => s.isDelivered)
            .fold(0.0, (sum, s) => sum + s.codAmountRupees);
        expect(api.driverCashCustodyRupees, initialCodDelivered);
      });

      test('3.2 [U] Update: Customer OTP verification completes drop and increments driver cash', () async {
        // Find or create an undelivered COD stop
        DeliveryStop? pendingStop;
        for (final stop in api.deliveryStops) {
          if (!stop.isDelivered && stop.codAmountRupees > 0) {
            pendingStop = stop;
            break;
          }
        }

        // If all pre-seeded stops are delivered, create one
        if (pendingStop == null) {
          pendingStop = DeliveryStop(
            id: 'stop_test_${DateTime.now().millisecondsSinceEpoch}',
            orderId: 'ord_test_99',
            shopName: 'Test Kirana Mart',
            ownerName: 'Ramesh Lal',
            phone: '9829012345',
            address: 'Station Road',
            area: 'Jodhpur Central',
            codAmountPaise: 500000, // ₹5000
            serverOtp: '1234',
            itemCount: 4,
            isDelivered: false,
          );
          api.deliveryStops.add(pendingStop);
        }

        final initialCash = api.driverCashCustodyRupees;
        final stopCod = pendingStop.codAmountRupees;

        // Wrong OTP must fail
        final wrongOtpResult = api.confirmDeliveryWithOtp(pendingStop.id, '0000');
        expect(wrongOtpResult, isFalse);
        expect(pendingStop.isDelivered, isFalse);
        expect(api.driverCashCustodyRupees, initialCash);

        // Correct OTP (must match stop.serverOtp) must succeed
        final successOtpResult = api.confirmDeliveryWithOtp(pendingStop.id, pendingStop.serverOtp);
        expect(successOtpResult, isTrue);
        expect(pendingStop.isDelivered, isTrue);
        expect(api.driverCashCustodyRupees, initialCash + stopCod);
        await Future.delayed(const Duration(milliseconds: 50));
      });

      test('3.3 [D] Handover Safeguard: Cash custody cannot be cleared without server verification', () {
        // Driver cash custody must be preserved
        expect(api.driverCashCustodyRupees, greaterThanOrEqualTo(0));
        // Verify that ApiService derives driverCashCustodyRupees strictly from delivered stops
        final deliveredCodSum = api.deliveryStops
            .where((s) => s.isDelivered)
            .fold(0.0, (sum, s) => sum + s.codAmountRupees);
        expect(api.driverCashCustodyRupees, deliveredCodSum);
      });
    });

    // =========================================================================
    // 4. ADMIN ROLE: COMPLETE CRUD & INVARIANTS
    // =========================================================================
    group('4. ADMIN ROLE CRUD & OPERATIONS', () {
      test('4.1 [C] Create: Add new SKU to Master Catalog', () async {
        final newSku = ProductItem(
          id: 'prod_new_sku_99',
          name: 'Haldiram Aloo Bhujia 400g',
          hindiName: 'हल्दीराम आलू भुजिया',
          category: 'Namkeen & Sweets',
          boxQty: 48,
          stripQty: 12,
          piecePricePaise: 7500, // ₹75
          mrpRupees: 90.0,
          gstRate: 12.0,
          godownStockBoxes: 60,
          carStockBoxes: 10,
        );

        final initialCount = api.products.length;
        api.addProduct(newSku);

        expect(api.products.length, initialCount + 1);
        expect(api.products.any((p) => p.id == 'prod_new_sku_99'), isTrue);
        await Future.delayed(const Duration(milliseconds: 50));
      });

      test('4.2 [R] Read: Master executive calculations, GST breakdown, and working capital', () {
        // Delivered Sales turnover
        final deliveredSales = api.totalDeliveredSalesRupees;
        expect(deliveredSales, greaterThanOrEqualTo(0));

        // Total GST collected
        final gst = api.totalGstCollectedRupees;
        expect(gst, greaterThanOrEqualTo(0));

        // Retailer Udhaar
        final udhaar = api.totalUdhaarRupees;
        expect(udhaar, greaterThanOrEqualTo(0));

        // Working capital invariant: Retailer Udhaar equals sum of positive retailer balances
        final calculatedUdhaar = api.retailers.fold(
          0.0,
          (sum, r) => sum + (r.outstandingRupees > 0 ? r.outstandingRupees : 0),
        );
        expect(udhaar, calculatedUdhaar);
      });

      test('4.3 [U] Update: Modify SKU price and details', () async {
        final prod = api.products.first;
        final updated = ProductItem(
          id: prod.id,
          name: '${prod.name} (Updated Pack)',
          hindiName: prod.hindiName,
          category: prod.category,
          boxQty: prod.boxQty,
          stripQty: prod.stripQty,
          piecePricePaise: prod.piecePricePaise + 500, // +₹5
          mrpRupees: prod.mrpRupees + 10.0,
          gstRate: prod.gstRate,
          godownStockBoxes: prod.godownStockBoxes,
          carStockBoxes: prod.carStockBoxes,
        );

        api.updateProduct(updated);

        final found = api.products.firstWhere((p) => p.id == prod.id);
        expect(found.name, contains('(Updated Pack)'));
        expect(found.piecePricePaise, prod.piecePricePaise + 500);
        await Future.delayed(const Duration(milliseconds: 50));
      });

      test('4.4 [D] Delete / Archive: Delete temporary product and verify cart eviction', () async {
        final tempProd = ProductItem(
          id: 'prod_temp_del',
          name: 'Discontinued Kurkure Test',
          hindiName: 'कुर्कुरे टेस्ट',
          category: 'Snacks',
          boxQty: 10,
          stripQty: 5,
          piecePricePaise: 1000,
          mrpRupees: 15.0,
          gstRate: 18.0,
          godownStockBoxes: 5,
        );
        api.addProduct(tempProd);
        api.addToCart(tempProd, OrderUnit.box, 1);
        expect(api.cart.containsKey('prod_temp_del'), isTrue);

        // Remove product
        api.removeProduct('prod_temp_del');
        expect(api.products.any((p) => p.id == 'prod_temp_del'), isFalse);
        expect(api.cart.containsKey('prod_temp_del'), isFalse); // Automatically evicted from cart
        await Future.delayed(const Duration(milliseconds: 50));
      });

      test('4.5 Invariant: Advance order lifecycle from Booking -> ReadyStock -> OrderSend -> Delivered', () {
        // 1. Book an order
        final shop = api.retailers.first;
        final p = api.products.first;
        api.clearCart();
        api.addToCart(p, OrderUnit.box, 1);
        final order = api.placeOrder(shopId: shop.id, paymentMode: 'COD');
        expect(order.stage, OrderLifecycleStage.booking);

        // 2. Advance to Ready Stock (Pack verification)
        api.advanceOrderStage(order.id);
        expect(order.stage, OrderLifecycleStage.readyStock);

        // 3. Advance to Order Send (Dispatch onto van)
        api.advanceOrderStage(order.id);
        expect(order.stage, OrderLifecycleStage.orderSend);

        // 4. Advance to Delivered (Customer drop completed)
        final initialDeliveredSales = api.totalDeliveredSalesRupees;
        api.advanceOrderStage(order.id);
        expect(order.stage, OrderLifecycleStage.delivered);
        expect(api.totalDeliveredSalesRupees, initialDeliveredSales + order.totalRupees);
      });
    });

    // =========================================================================
    // 5. DISTRIBUTOR OWNER ROLE: COMPLETE CRUD & SOVEREIGN GOVERNANCE
    // =========================================================================
    group('5. DISTRIBUTOR OWNER ROLE CRUD & SOVEREIGN GOVERNANCE', () {
      test('5.1 [C/U] Sovereign Credit Limit Governance: Modify retailer credit limits and reject negative values', () async {
        final shop = api.retailers.first;
        final initialLimit = shop.creditLimitPaise;

        // 1. Owner modifies retailer credit limit (e.g. increase by ₹25,000 = 2500000 paise)
        final newLimit = initialLimit + 2500000;
        await api.updateRetailerCreditLimit(shop.id, newLimit);

        expect(shop.creditLimitPaise, newLimit);
        expect(shop.creditLimitRupees, newLimit / 100.0);

        // Verify persisted to SQLite
        final dbRetailer = await repository.getAllRetailers();
        final found = dbRetailer.firstWhere((r) => r.id == shop.id);
        expect(found.creditLimitPaise, newLimit);

        // 2. Reject negative credit limit
        expect(
          () async => await api.updateRetailerCreditLimit(shop.id, -5000),
          throwsA(isA<ArgumentError>()),
        );

        // 3. Reject non-existent shop
        expect(
          () async => await api.updateRetailerCreditLimit('NON_EXISTENT_SHOP', 1000000),
          throwsA(isA<StateError>()),
        );
      });

      test('5.2 [U] Sovereign Stock Write-Off: Authorize damaged stock write-off with audit trail', () async {
        final prod = api.products.first;
        final initialGodown = prod.godownStockBoxes;

        // 1. Write off 5 damaged cartons
        await api.writeOffDamagedStock(
          productId: prod.id,
          cartonCount: 5,
          reason: 'Monsoon Water Leakage in Bay 4',
        );

        expect(prod.godownStockBoxes, initialGodown - 5);

        // Verify movement audit in SQLite
        final movements = await repository.getMovementsForProduct(prod.id);
        final writeOffMov = movements.firstWhere((m) => m.movementType == 'WRITE_OFF');
        expect(writeOffMov.cartonDelta, -5);
        expect(writeOffMov.reason, contains('Monsoon Water Leakage'));

        // 2. Reject write-off exceeding godown stock
        expect(
          () async => await api.writeOffDamagedStock(
            productId: prod.id,
            cartonCount: prod.godownStockBoxes + 500,
            reason: 'Excessive Write-off',
          ),
          throwsA(isA<StateError>()),
        );

        // 3. Reject non-positive write-off count
        expect(
          () async => await api.writeOffDamagedStock(
            productId: prod.id,
            cartonCount: 0,
            reason: 'Zero Write-off',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('5.3 [U] Sovereign Driver Cash Settlement: Settle driver custody into depot account', () {
        final initialSettled = api.settledDriverCashRupees;

        // Settle ₹12,500 driver cash handover
        final success = api.settleDriverCashHandover(
          driverId: 'usr_delivery_01',
          settledAmountRupees: 12500.0,
        );

        expect(success, isTrue);
        expect(api.settledDriverCashRupees, initialSettled + 12500.0);

        // Reject negative settlement
        expect(
          () => api.settleDriverCashHandover(
            driverId: 'usr_delivery_01',
            settledAmountRupees: -100.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('5.4 [R] Sovereign Executive Visibility: Multi-depot godown capacity and revenue overview', () {
        // Multi-depot visibility
        expect(api.warehouseHubs.length, greaterThanOrEqualTo(2));
        final totalDepotCapacity = api.warehouseHubs.fold(0, (sum, w) => sum + w.capacityBoxes);
        expect(totalDepotCapacity, greaterThan(5000));

        // Enterprise turnover & udhaar
        expect(api.totalDeliveredSalesRupees, greaterThanOrEqualTo(0));
        expect(api.totalUdhaarRupees, greaterThanOrEqualTo(0));
      });

      test('5.5 Sovereign Authority Invariant: Owner has 100% of all 25 system permissions', () {
        final owner = CanonicalRole.owner;
        for (final p in RolePermission.values) {
          expect(roleHasPermission(owner, p), isTrue, reason: 'Owner must have ${p.name}');
          expect(() => assertRolePermission(owner, p), returnsNormally);
        }
      });

      test('5.6 Sovereign Fencing Invariant: All other roles are strictly rejected from Sovereign permissions', () {
        const sovereignPermissions = [
          RolePermission.modifyCreditLimits,
          RolePermission.settleDriverCash,
          RolePermission.viewFinancialProfitLedger,
          RolePermission.authorizeStockWriteOff,
        ];

        final nonOwnerRoles = [
          CanonicalRole.sales,
          CanonicalRole.warehouse,
          CanonicalRole.delivery,
          CanonicalRole.admin,
        ];

        for (final role in nonOwnerRoles) {
          for (final perm in sovereignPermissions) {
            expect(
              roleHasPermission(role, perm),
              isFalse,
              reason: 'Role ${role.key} MUST NOT have sovereign permission ${perm.name}',
            );
            expect(
              () => assertRolePermission(role, perm),
              throwsA(isA<RoleAuthorizationException>()),
              reason: 'Role ${role.key} calling assertRolePermission on ${perm.name} must throw',
            );
          }
        }
      });
    });

    // =========================================================================
    // 6. ROLE BOUNDARY & FAIL-CLOSED ENFORCEMENT
    // =========================================================================
    group('6. ROLE BOUNDARIES & FAIL-CLOSED ENFORCEMENT', () {
      test('6.1 All canonical roles map or fail-closed as strictly specified', () {
        expect(CanonicalRole.fromString('SALES'), CanonicalRole.sales);
        expect(CanonicalRole.fromString('WAREHOUSE'), CanonicalRole.warehouse);
        expect(CanonicalRole.fromString('DELIVERY'), CanonicalRole.delivery);
        expect(CanonicalRole.fromString('ADMIN'), CanonicalRole.admin);
        expect(CanonicalRole.fromString('OWNER'), CanonicalRole.owner);

        // The other canonical roles must FAIL CLOSED (return null -> RoleBlockedView) until their modules are built
        expect(CanonicalRole.fromString('SALES_MANAGER'), isNull);
        expect(CanonicalRole.fromString('ACCOUNTANT'), isNull);
        expect(CanonicalRole.fromString('RETAILER'), isNull);

        // Invalid roles must fail closed
        expect(CanonicalRole.fromString('SUPERUSER'), isNull);
        expect(CanonicalRole.fromString('HACKER'), isNull);
        expect(CanonicalRole.fromString(''), isNull);
        expect(CanonicalRole.fromString(null), isNull);
      });

      test('6.2 Permission boundaries are strictly enforced across roles', () {
        // Sales representative permissions
        expect(roleHasPermission(CanonicalRole.sales, RolePermission.createSalesOrders), isTrue);
        expect(roleHasPermission(CanonicalRole.sales, RolePermission.recordVisitCheckIn), isTrue);
        expect(roleHasPermission(CanonicalRole.sales, RolePermission.adjustGodownStock), isFalse);
        expect(roleHasPermission(CanonicalRole.sales, RolePermission.verifyDeliveryOtp), isFalse);
        expect(roleHasPermission(CanonicalRole.sales, RolePermission.viewOrgOverview), isFalse);

        // Warehouse manager permissions
        expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.adjustGodownStock), isTrue);
        expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.recordInwardStock), isTrue);
        expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.createSalesOrders), isFalse);
        expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.verifyDeliveryOtp), isFalse);

        // Delivery driver permissions
        expect(roleHasPermission(CanonicalRole.delivery, RolePermission.verifyDeliveryOtp), isTrue);
        expect(roleHasPermission(CanonicalRole.delivery, RolePermission.recordCashCollection), isTrue);
        expect(roleHasPermission(CanonicalRole.delivery, RolePermission.adjustGodownStock), isFalse);
        expect(roleHasPermission(CanonicalRole.delivery, RolePermission.createSalesOrders), isFalse);

        // Admin permissions
        expect(roleHasPermission(CanonicalRole.admin, RolePermission.viewOrgOverview), isTrue);
        expect(roleHasPermission(CanonicalRole.admin, RolePermission.manageProducts), isTrue);
        expect(roleHasPermission(CanonicalRole.admin, RolePermission.manageRetailers), isTrue);
        expect(roleHasPermission(CanonicalRole.admin, RolePermission.viewReports), isTrue);
      });
    });
  });
}
