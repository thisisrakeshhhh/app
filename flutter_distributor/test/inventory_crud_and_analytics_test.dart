import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/screens/dashboards/warehouse_dashboard.dart';
import 'package:lala_distributor/screens/views/add_edit_inventory_item_sheet.dart';
import 'package:lala_distributor/screens/views/warehouse_subviews.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  group('Warehouse Inventory Role: Full In-App CRUD, Expiry Radar & Analytics', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LocalRepository(db);
      api = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. ProductItem model supports batchNumber, expiryDate, reorderLevelBoxes and valuation getters', () {
      final now = DateTime.now();
      final expiryIn20Days = DateTime(now.year, now.month, now.day).add(const Duration(days: 20));

      final product = ProductItem(
        id: 'TEST-SKU-01',
        name: 'Test Salted Peanuts 50g',
        hindiName: 'टेस्ट नमकीन मूंगफली',
        category: 'Namkeen & Traditional Snacks',
        mrpRupees: 20.0,
        piecePricePaise: 1600, // ₹16 wholesale
        stripQty: 10,
        boxQty: 50,
        godownStockBoxes: 40,
        batchNumber: 'LOT-2026-PN01',
        expiryDate: expiryIn20Days,
        reorderLevelBoxes: 30,
      );

      // Batch & Expiry logic
      expect(product.batchNumber, equals('LOT-2026-PN01'));
      expect(product.daysUntilExpiry, equals(20));
      expect(product.isExpiringSoon, isTrue);
      expect(product.isExpired, isFalse);

      // Stock status
      expect(product.isLowStock, isFalse); // 40 > 30
      expect(product.isOutOfStock, isFalse);

      // Valuation
      // 40 boxes * 50 pcs/box * 1600 paise = 3,200,000 paise = ₹32,000.00
      expect(product.godownValuationPaise, equals(3200000));
      expect(product.godownValuationRupees, equals(32000.0));
    });

    test('2. In-App CRUD: ApiService addProduct, updateProduct, restockProduct, and removeProduct', () async {
      final initialCount = api.products.length;

      // [C] CREATE: Add new SKU
      final newProduct = ProductItem(
        id: 'PEPSI-CAN-330',
        name: 'Pepsi Sleek Can 330ml',
        hindiName: 'पेप्सी कैन 330ml',
        category: 'Carbonated Drinks (CSD)',
        mrpRupees: 35.0,
        piecePricePaise: 2900,
        stripQty: 1,
        boxQty: 24,
        godownStockBoxes: 60,
        batchNumber: 'LOT-2026-PC01',
        expiryDate: DateTime(2027, 5, 20),
        reorderLevelBoxes: 25,
      );

      api.addProduct(newProduct);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.products.length, equals(initialCount + 1));
      expect(api.products.any((p) => p.id == 'PEPSI-CAN-330'), isTrue);

      // [R] READ & GET: Verify fields
      final retrieved = api.products.firstWhere((p) => p.id == 'PEPSI-CAN-330');
      expect(retrieved.name, equals('Pepsi Sleek Can 330ml'));
      expect(retrieved.batchNumber, equals('LOT-2026-PC01'));
      expect(retrieved.godownStockBoxes, equals(60));

      // [U] UPDATE: Update pricing and batch
      final updated = retrieved.copyWith(
        name: 'Pepsi Sleek Can 330ml (Chilled)',
        mrpPaise: 3800,
        piecePricePaise: 3100,
        batchNumber: 'LOT-2026-PC02',
      );
      api.updateProduct(updated);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final postUpdate = api.products.firstWhere((p) => p.id == 'PEPSI-CAN-330');
      expect(postUpdate.name, equals('Pepsi Sleek Can 330ml (Chilled)'));
      expect(postUpdate.piecePricePaise, equals(3100));
      expect(postUpdate.batchNumber, equals('LOT-2026-PC02'));

      // RESTOCK / AUDIT: Adjust physical stock
      api.restockProduct('PEPSI-CAN-330', 15);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(postUpdate.godownStockBoxes, equals(75));

      // [D] DELETE: Remove SKU
      api.removeProduct('PEPSI-CAN-330');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.products.length, equals(initialCount));
      expect(api.products.any((p) => p.id == 'PEPSI-CAN-330'), isFalse);
    });

    testWidgets('3. WarehouseDashboard renders Central Godown banner, "+ Add SKU" button, Valuation and Expiry KPIs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WarehouseDashboard(
              api: api,
              onNavigateTab: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner checks
      expect(find.text('CENTRAL FMCG GODOWN'), findsOneWidget);
      expect(find.textContaining('Basni Industrial Area Phase II'), findsOneWidget);
      expect(find.text('+ Add SKU'), findsOneWidget);

      // KPI card checks
      expect(find.text('Godown Stock'), findsWidgets);
      expect(find.text('Stock Valuation'), findsOneWidget);
      expect(find.text('Loaded in Van'), findsOneWidget);
      expect(find.text('Expiry Radar'), findsOneWidget);
    });

    testWidgets('4. WarehouseStockView renders Stock Catalog, Expiry Radar, and Analytics tabs with full in-map controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WarehouseStockView(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top title and "+ Add SKU" button
      expect(find.text('Godown Inventory (गोदाम स्टॉक)'), findsOneWidget);
      expect(find.text('+ Add SKU'), findsOneWidget);

      // Sub-tabs
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.textContaining('Expiry Radar'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);

      // Search bar and Adjust buttons
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Adjust Stock'), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);

      // Tapping Expiry Radar tab switches view
      await tester.tap(find.textContaining('Expiry Radar'));
      await tester.pumpAndSettle();

      expect(find.text('Batch Expiry Timeline (बैच एक्सपायरी सूची)'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Expiring <60d'), findsOneWidget);

      // Tapping Analytics tab switches view
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL GODOWN STOCK VALUATION'), findsOneWidget);
      expect(find.text('Stock Valuation by Category (श्रेणी अनुसार मूल्य)'), findsOneWidget);
      expect(find.text('Reorder Threshold Alerts (पुनः ऑर्डर सूचनाएं)'), findsOneWidget);
    });

    testWidgets('5. AddEditInventoryItemSheet validates and creates a new SKU manually from UI', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddEditInventoryItemSheet.show(ctx, api),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Add Inventory SKU'), findsOneWidget);
      expect(find.text('Product Name (English) *'), findsOneWidget);

      // Fill in product name
      await tester.enterText(find.widgetWithText(TextFormField, 'Product Name (English) *'), 'Mirinda Orange 500ml');
      await tester.enterText(find.widgetWithText(TextFormField, 'Hindi / Local Name (हिंदी नाम)'), 'मिरिंडा 500ml');

      // Scroll to button if needed and submit form
      await tester.ensureVisible(find.text('Add Item to Godown Inventory'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Item to Godown Inventory'));
      await tester.pumpAndSettle();

      // Verify product added to ApiService
      expect(api.products.any((p) => p.name == 'Mirinda Orange 500ml'), isTrue);
    });
  });
}
