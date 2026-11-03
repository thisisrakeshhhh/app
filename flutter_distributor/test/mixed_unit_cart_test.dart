import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
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

  group('Slice 0: Mixed-Unit Cart & Base Quantity Mathematics', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;
    late ProductItem testProduct;

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

      // Product with Box = 50 pieces, Strip = 5 pieces, Piece = 1 piece
      testProduct = ProductItem(
        id: 'TEST-SKU-01',
        name: 'Balaji Crunchex',
        hindiName: 'बालाजी क्रंचेक्स',
        category: 'Snacks',
        mrpRupees: 10.0,
        piecePricePaise: 800, // ₹8.00 base per piece
        stripQty: 5,          // 5 pieces per strip
        boxQty: 50,           // 50 pieces per box
        godownStockBoxes: 2,  // 2 boxes = 100 total pieces
        carStockBoxes: 0,
      );
      await repo.upsertProduct(testProduct);
      api.addProduct(testProduct);
    });

    tearDown(() async {
      // Allow any microtasks to flush before closing DB
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Mixed-unit cart holds multiple unit lines (box, strip, piece) simultaneously without overwriting', () {
      api.clearCart();

      // Add 1 Box (50 pcs)
      api.addToCart(testProduct, OrderUnit.box, 1);
      // Add 1 Strip (5 pcs)
      api.addToCart(testProduct, OrderUnit.strip, 1);
      // Add 1 Loose Piece (1 pc)
      api.addToCart(testProduct, OrderUnit.piece, 1);

      // Verify cart holds 3 distinct lines
      expect(api.cart.length, equals(3));
      expect(api.cart.values.any((item) => item.unit == OrderUnit.box && item.quantity == 1), isTrue);
      expect(api.cart.values.any((item) => item.unit == OrderUnit.strip && item.quantity == 1), isTrue);
      expect(api.cart.values.any((item) => item.unit == OrderUnit.piece && item.quantity == 1), isTrue);

      // 1 box (50) + 1 strip (5) + 1 piece (1) = 56 total pieces
      expect(api.cartTotalPieces, equals(56));
    });

    test('2. Exact integer base quantity arithmetic: 2 boxes + 3 strips + 4 pieces = 119 pieces', () {
      api.clearCart();

      // Add 2 boxes (2 * 50 = 100 pcs)
      api.addToCart(testProduct, OrderUnit.box, 2);
      // Add 3 strips (3 * 5 = 15 pcs)
      api.addToCart(testProduct, OrderUnit.strip, 3);
      // Add 4 loose pieces (4 * 1 = 4 pcs)
      api.addToCart(testProduct, OrderUnit.piece, 4);

      // (2 * 50) + (3 * 5) + 4 = 100 + 15 + 4 = 119 pieces
      expect(api.cartTotalPieces, equals(119));
    });

    test('3. Stock availability validation sums base pieces across all unit lines of the same SKU', () {
      api.clearCart();
      // Available stock is 2 boxes = 100 pieces
      expect(api.availableGodownPieces(testProduct.id), equals(100));

      // Attempt to book 1 box (50 pcs) + 9 strips (45 pcs) + 10 pieces (10 pcs) = 105 pieces (> 100)
      api.addToCart(testProduct, OrderUnit.box, 1);
      api.addToCart(testProduct, OrderUnit.strip, 9);
      api.addToCart(testProduct, OrderUnit.piece, 10);
      expect(api.cartTotalPieces, equals(105));

      // Order placement must throw StateError because 105 exceeds 100 available pieces
      expect(
        () => api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('exceeds available stock'),
        )),
      );
    });

    test('4. Removing one unit line keeps other unit lines for the same product intact', () {
      api.clearCart();

      api.addToCart(testProduct, OrderUnit.box, 1);
      api.addToCart(testProduct, OrderUnit.piece, 6);
      expect(api.cart.length, equals(2));

      // Remove the piece line (key = "${id}::piece")
      final pieceKey = CartItem.makeCartKey(testProduct.id, OrderUnit.piece);
      api.removeCartLine(pieceKey);

      expect(api.cart.length, equals(1));
      final remaining = api.cart.values.first;
      expect(remaining.unit, equals(OrderUnit.box));
      expect(remaining.quantity, equals(1));
      expect(api.cartTotalPieces, equals(50));
    });

    test('5. Outbox payload creates separate OrderItemPayload lines per unit for the same product', () async {
      api.clearCart();

      api.addToCart(testProduct, OrderUnit.box, 1);
      api.addToCart(testProduct, OrderUnit.piece, 5);

      final order = await api.confirmOrderDurable(
        shopId: api.retailers.first.id,
        paymentMode: 'Credit',
      );

      // Verify the generated order holds 2 distinct line items for this single product
      expect(order.items.length, equals(2));
      final boxLine = order.items.firstWhere((it) => it.unit == OrderUnit.box);
      final pieceLine = order.items.firstWhere((it) => it.unit == OrderUnit.piece);

      expect(boxLine.quantity, equals(1));
      expect(boxLine.totalPieces, equals(50));
      expect(pieceLine.quantity, equals(5));
      expect(pieceLine.totalPieces, equals(5));
      expect(order.items.fold(0, (sum, it) => sum + it.totalPieces), equals(55));
    });
  });
}
