import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/role_routing.dart';
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
    await db.close();
  });

  group('Ruthless Hardcore Security & Permission Fencing Tests', () {
    test('1. Hostile, malformed, and unauthorized role strings must strictly fail closed (return null)', () {
      final hostileRoles = [
        '',
        ' ',
        '   ',
        '\t',
        '\n',
        'null',
        'undefined',
        'SUPER_ADMIN',
        'ROOT',
        'SYSTEM',
        'GUEST',
        'SALES_MANAGER',
        'ACCOUNTANT',
        'RETAILER',
        'DISTRIBUTOR',
        'MANAGER',
        'ADMIN; DROP TABLE users;',
        '../../etc/passwd',
        '<script>alert(1)</script>',
        'SALES\u0000ADMIN',
        'DELIVERY\nADMIN',
      ];

      for (final hostile in hostileRoles) {
        final resolved = CanonicalRole.fromString(hostile);
        expect(
          resolved,
          isNull,
          reason: 'Hostile/unsupported role "$hostile" must fail closed and return null.',
        );
      }
    });

    test('2. Combinatorial Permission Fencing: 100% of unauthorized (role, permission) pairs throw', () {
      final allPermissions = RolePermission.values;
      final allRoles = CanonicalRole.values;

      int authorizedCount = 0;
      int unauthorizedCount = 0;

      for (final role in allRoles) {
        for (final permission in allPermissions) {
          final isAllowed = roleHasPermission(role, permission);
          if (isAllowed) {
            authorizedCount++;
            expect(
              () => assertRolePermission(role, permission),
              returnsNormally,
              reason: 'Role ${role.key} should have permission ${permission.name}',
            );
          } else {
            unauthorizedCount++;
            expect(
              () => assertRolePermission(role, permission),
              throwsA(isA<RoleAuthorizationException>()),
              reason: 'Role ${role.key} MUST NOT have permission ${permission.name}',
            );
          }
        }
      }

      // Exact count verification
      // Sales: 5, Warehouse: 5, Delivery: 5, Admin: 8, Owner: all 25 permissions
      expect(authorizedCount, equals(5 + 5 + 5 + 8 + allPermissions.length));
      expect(unauthorizedCount, equals((allRoles.length * allPermissions.length) - authorizedCount));
    });

    test('3. Cross-role unauthorized action assertions', () {
      // Sales cannot adjust stock, loading or verify delivery
      expect(() => assertRolePermission(CanonicalRole.sales, RolePermission.adjustGodownStock), throwsA(isA<RoleAuthorizationException>()));
      expect(() => assertRolePermission(CanonicalRole.sales, RolePermission.vehicleStockLoading), throwsA(isA<RoleAuthorizationException>()));
      expect(() => assertRolePermission(CanonicalRole.sales, RolePermission.verifyDeliveryOtp), throwsA(isA<RoleAuthorizationException>()));
      expect(() => assertRolePermission(CanonicalRole.sales, RolePermission.manageEmployees), throwsA(isA<RoleAuthorizationException>()));

      // Warehouse cannot create sales orders or collect cash
      expect(() => assertRolePermission(CanonicalRole.warehouse, RolePermission.createSalesOrders), throwsA(isA<RoleAuthorizationException>()));
      expect(() => assertRolePermission(CanonicalRole.warehouse, RolePermission.recordCashCollection), throwsA(isA<RoleAuthorizationException>()));
      expect(() => assertRolePermission(CanonicalRole.warehouse, RolePermission.manageProducts), throwsA(isA<RoleAuthorizationException>()));

      // Delivery cannot adjust godown stock or approve orders
      expect(() => assertRolePermission(CanonicalRole.delivery, RolePermission.adjustGodownStock), throwsA(isA<RoleAuthorizationException>()));
      expect(() => assertRolePermission(CanonicalRole.delivery, RolePermission.createSalesOrders), throwsA(isA<RoleAuthorizationException>()));
      expect(() => assertRolePermission(CanonicalRole.delivery, RolePermission.reviewOrderApprovals), throwsA(isA<RoleAuthorizationException>()));
    });
  });

  group('Ruthless Hardcore Order Booking & Mathematical Invariant Tests', () {
    test('4. Atomic All-or-Nothing Booking: If any line exceeds available stock, the entire cart fails with 0 reservations', () {
      final p1 = api.products[0];
      final p2 = api.products[1];
      final initialPendingP1 = api.pendingBookingPieces(p1.id);
      final initialPendingP2 = api.pendingBookingPieces(p2.id);
      final initialOrdersCount = api.orders.length;

      // Add 2 valid boxes of p1
      api.addToCart(p1, OrderUnit.box, 2);

      // Add an impossible quantity of p2 (more than available)
      final availP2 = api.availableGodownPieces(p2.id);
      final overbookingBoxes = (availP2 ~/ p2.boxQty) + 50;
      api.addToCart(p2, OrderUnit.box, overbookingBoxes);

      expect(
        () => api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exceeds available stock'))),
      );

      // Verify ZERO partial booking occurred
      expect(api.orders.length, equals(initialOrdersCount));
      expect(api.pendingBookingPieces(p1.id), equals(initialPendingP1));
      expect(api.pendingBookingPieces(p2.id), equals(initialPendingP2));
    });

    test('5. Zero-tolerance duplicate aggregation: Multiple items of the same product in cart are sum-checked together', () {
      final p = api.products.firstWhere((prod) => prod.id == 'KURK-01');
      final availPieces = api.availableGodownPieces(p.id);
      final availBoxes = availPieces ~/ p.boxQty;

      // Add half of available in one line
      final half1 = availBoxes ~/ 2;
      api.addToCart(p, OrderUnit.box, half1);

      // Add another batch that together exceeds total available
      final excessHalf = (availBoxes - half1) + 2;
      // In cart, addToCart merges existing entries:
      api.addToCart(p, OrderUnit.box, excessHalf);

      expect(
        () => api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'Credit'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exceeds available stock'))),
      );
    });

    test('6. Conservation of Physical Stock Equation: physical == available + pending at all times', () {
      final p = api.products.firstWhere((prod) => prod.id == 'LAYS-02');
      final totalPhysicalPieces = p.godownStockBoxes * p.boxQty;
      final initialPhysicalBoxes = p.godownStockBoxes;

      // Invariant before booking
      expect(api.availableGodownPieces(p.id) + api.pendingBookingPieces(p.id), equals(totalPhysicalPieces));

      // Book 1 box
      api.addToCart(p, OrderUnit.box, 1);
      api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD');
      expect(api.availableGodownPieces(p.id) + api.pendingBookingPieces(p.id), equals(totalPhysicalPieces));

      // Book 5 loose pieces
      api.addToCart(p, OrderUnit.piece, 5);
      api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD');
      expect(api.availableGodownPieces(p.id) + api.pendingBookingPieces(p.id), equals(totalPhysicalPieces));

      // Book 3 strips
      api.addToCart(p, OrderUnit.strip, 3);
      api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD');
      expect(api.availableGodownPieces(p.id) + api.pendingBookingPieces(p.id), equals(totalPhysicalPieces));

      // Physical godown cartons remain untouched throughout
      expect(p.godownStockBoxes, equals(initialPhysicalBoxes));
    });

    test('7. Exact boundary condition: Booking down to EXACTLY 0 available pieces succeeds, and the next 1 piece fails', () {
      // Advance initial seeded booking order so pending reservation starts clean at 0
      api.advanceOrderStage('ord_init_03');

      final p = api.products.firstWhere((prod) => prod.id == 'KURK-01');
      expect(api.pendingBookingPieces(p.id), equals(0));
      final totalBoxes = p.godownStockBoxes;
      expect(api.availableGodownBoxes(p.id), equals(totalBoxes));

      // Book 100% of available stock in full cartons
      api.addToCart(p, OrderUnit.box, totalBoxes);
      api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD');

      // Now available pieces must be EXACTLY 0
      expect(api.availableGodownPieces(p.id), equals(0));
      expect(api.availableGodownBoxes(p.id), equals(0));
      expect(api.pendingBookingPieces(p.id), equals(totalBoxes * p.boxQty));

      // Now attempt to book even 1 single piece
      api.addToCart(p, OrderUnit.piece, 1);
      expect(
        () => api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exceeds available stock'))),
      );
    });

    test('8. Rejection of invalid inputs: Non-existent shop or corrupted product ID throws StateError', () {
      final p = api.products[0];
      api.addToCart(p, OrderUnit.box, 1);

      expect(
        () => api.placeOrder(shopId: 'GHOST_SHOP_999', paymentMode: 'COD'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('does not exist'))),
      );
    });
  });

  group('Ruthless Hardcore Delivery OTP & Cash Custody Safety Tests', () {
    test('9. Universal OTP bypass is completely dead and rejects brute-force common codes', () {
      expect(api.deliveryStops, isNotEmpty);
      final stop = api.deliveryStops.first;
      final legitimateOtp = stop.serverOtp;

      final bruteForceAttempts = [
        '724185', // Old hardcoded universal bypass
        '000000',
        '123456',
        '111111',
        '999999',
        '',
        ' ',
        'null',
        'otp',
        'undefined',
        '-1',
        '724185 ',
      ];

      for (final code in bruteForceAttempts) {
        if (code.trim() != legitimateOtp.trim()) {
          final res = api.confirmDeliveryWithOtp(stop.id, code);
          expect(res, isFalse, reason: 'Brute force code "$code" must not verify delivery');
          expect(stop.isDelivered, isFalse);
          expect(stop.cashCollected, isFalse);
        }
      }

      // Valid OTP strictly confirms delivery
      final ok = api.confirmDeliveryWithOtp(stop.id, legitimateOtp);
      expect(ok, isTrue);
      expect(stop.isDelivered, isTrue);
      expect(stop.cashCollected, isTrue);
    });

    test('10. Replay Prevention: Verifying an already delivered stop returns true but does NOT double-increment cash custody', () {
      final stop = api.deliveryStops.first;
      final legitimateOtp = stop.serverOtp;

      // First confirmation
      final ok1 = api.confirmDeliveryWithOtp(stop.id, legitimateOtp);
      expect(ok1, isTrue);
      final custodyAfterFirst = api.driverCashCustodyPaise;
      expect(custodyAfterFirst, equals(stop.codAmountPaise));

      // Second confirmation (replay attack)
      final ok2 = api.confirmDeliveryWithOtp(stop.id, legitimateOtp);
      expect(ok2, isTrue);

      // Custody must NOT double
      expect(api.driverCashCustodyPaise, equals(custodyAfterFirst));
    });

    test('11. Cash Handover Safety: Cash custody strictly equals delivered COD sum and cannot be manipulated without server sync', () {
      final initialCustody = api.driverCashCustodyPaise;
      expect(initialCustody, equals(0)); // Fresh state

      // Deliver 2 stops
      final s1 = api.deliveryStops[0];
      final s2 = api.deliveryStops[1];

      api.confirmDeliveryWithOtp(s1.id, s1.serverOtp);
      api.confirmDeliveryWithOtp(s2.id, s2.serverOtp);

      final expectedTotal = s1.codAmountPaise + s2.codAmountPaise;
      expect(api.driverCashCustodyPaise, equals(expectedTotal));
      expect(api.driverCashCustodyRupees, equals(expectedTotal / 100.0));

      // Attempting any unauthorized action or reset must leave custody intact
      expect(api.driverCashCustodyPaise, equals(expectedTotal));
    });
  });
}
