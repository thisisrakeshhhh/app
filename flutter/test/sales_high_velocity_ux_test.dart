import 'dart:convert';
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

  group('Slice 4: High-Velocity Sales UX & Cart Durability (Pillar B)', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

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
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Cart drafts survive shop switching and persist to SQLite per retailer', () async {
      final shop1 = api.retailers.first;
      final shop2 = api.retailers[1];
      final prod1 = api.products.first;

      // 1. Build cart for shop1
      api.selectShop(shop1);
      api.addToCart(prod1, OrderUnit.box, 1);
      api.updateCartQuantity(prod1.id, 2, OrderUnit.box);
      await api.saveCurrentCartDraft();

      // Verify draft persisted in SQLite
      final draftRow = await repo.getCartDraft(shop1.id);
      expect(draftRow, isNotNull);
      final decoded = jsonDecode(draftRow!) as List;
      expect(decoded.length, 1);
      expect(decoded.first['quantity'], 3);

      // 2. Switch to shop2
      api.selectShop(shop2);
      expect(api.cart.isEmpty, isTrue);

      // 3. Switch back to shop1 -> draft restored!
      await api.loadCartDraftForRetailer(shop1.id);
      expect(api.cart.length, 1);
      final key = CartItem.makeCartKey(prod1.id, OrderUnit.box);
      expect(api.cart[key]?.quantity, 3);
    });

    test('2. Stale price warning surfaces when product price in DB changed since draft was saved', () async {
      final shop = api.retailers.first;
      final prod = ProductItem(
        id: 'TEST-PRICE-STALE-01',
        name: 'Test Price Item',
        hindiName: 'टेस्ट प्राइस आइटम',
        category: 'Snacks',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 10,
        boxQty: 50,
        godownStockBoxes: 50,
      );
      api.addProduct(prod);

      api.selectShop(shop);
      api.addToCart(prod, OrderUnit.piece, 1);
      api.updateCartQuantity(prod.id, 9, OrderUnit.piece);
      await api.saveCurrentCartDraft();

      // Now update product price in DB (simulate price hike from Rs 8.50 to Rs 9.00)
      const newPricePaise = 900;
      await api.updateProductUnitsDurable(
        productId: prod.id,
        units: [
          ProductPackagingUnit(
            id: 'unit_pcs_${prod.id}',
            productId: prod.id,
            unitName: 'piece',
            multiplierToBase: 1,
            isBaseUnit: true,
            wholesalePricePaise: newPricePaise,
          ),
        ],
        idempotencyKey: 'idem_price_hike_900',
      );

      // Reload draft -> Stale price check must report difference
      final warnings = await api.checkCartStalePrices(shop.id);
      expect(warnings.isNotEmpty, isTrue);
      expect(warnings.first.productId, prod.id);
      expect(warnings.first.oldPricePaise, 850);
      expect(warnings.first.newPricePaise, 900);
    });

    test('3. Repeat Last Order clones last order lines into cart and checks live stock', () async {
      final shop = api.retailers.first;
      final prod = api.products.first;

      api.selectShop(shop);
      api.addToCart(prod, OrderUnit.box, 2);

      // Confirm order 1
      await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'CASH',
        checkoutIdempotencyKey: 'idem_first_order_001',
      );

      expect(api.orders.isNotEmpty, isTrue);
      api.cart.clear();
      expect(api.cart.isEmpty, isTrue);

      // Repeat last order
      final success = await api.repeatLastOrder(shop.id);
      expect(success, isTrue);

      // Current cart now has the repeated items
      final key = CartItem.makeCartKey(prod.id, OrderUnit.box);
      expect(api.cart[key]?.quantity, 2);
    });

    test('4. Class D / NEW retailer strictly disables credit / khata checkout and requires cash', () async {
      final newShop = await api.createRetailerDurable(
        name: 'New Corner Stall',
        ownerName: 'Vikas',
        phone: '9988776655',
        address: 'Bhadwasiya Mandi',
        area: 'Bhadwasiya',
        suggestedClass: 'NEW',
        idempotencyKey: 'idem_new_stall_001',
      );

      expect(newShop.classType, 'NEW');
      expect(api.canUseCreditOrKhata(newShop), isFalse);

      final classDShop = RetailerShop(
        id: 'ret_class_d_01',
        name: 'Late Payer Kirana',
        ownerName: 'Shyamlal',
        phone: '9988112233',
        address: 'Clock Tower',
        area: 'Old City',
        creditLimitPaise: 500000,
        outstandingPaise: 490000,
        classType: 'D',
      );

      expect(api.canUseCreditOrKhata(classDShop), isFalse, reason: 'Class D must be cash-only regardless of limit');
    });

    test('5. No-order visit outcome is durably recorded in visits table', () async {
      final shop = api.retailers.first;

      await api.recordNoOrderVisit(
        retailerId: shop.id,
        outcome: 'SHOP_CLOSED',
        notes: 'Owner is attending a family wedding; revisit tomorrow.',
      );

      final visits = await repo.getVisitsForRetailer(shop.id);
      expect(visits.isNotEmpty, isTrue);
      final latestVisit = visits.first;
      expect(latestVisit.retailerId, shop.id);
      expect(latestVisit.outcome, 'SHOP_CLOSED');
      expect(latestVisit.notes, contains('family wedding'));
      expect(shop.visitedToday, isTrue);
    });
  });
}
