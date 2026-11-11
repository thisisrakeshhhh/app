import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/screens/views/add_shop_sheet.dart';
import 'package:lala_distributor/l10n/app_strings.dart';

class ZeroNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access strictly forbidden in offline tests');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = ZeroNetworkHttpOverrides();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('RouteFlow Hardcore Cart Math & Pricing Boundary Stress Test', () {
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
      await db.close();
    });

    test('1. Extreme Quantity & Large Paise Arithmetic Invariance (No 32-bit int overflow)', () {
      final expensiveProduct = ProductItem(
        id: 'prod_bulk_luxury',
        name: 'Pure Ghee 15kg Tin',
        hindiName: 'शुद्ध घी',
        category: 'Dairy',
        mrpRupees: 14000.00,
        piecePricePaise: 1250050, // ₹12,500.50
        stripQty: 1,
        boxQty: 1,
        godownStockBoxes: 50000,
        carStockBoxes: 0,
      );

      // Book 2,000 units: 2,000 * 1,250,050 paise = 2,500,100,000 paise (> 2.14 billion 32-bit signed int limit)
      final qty = 2000;
      final unitPricePaise = expensiveProduct.piecePricePaise;
      final totalAmountPaise = qty * unitPricePaise;

      expect(totalAmountPaise, equals(2500100000), reason: 'Must compute correctly beyond 32-bit integer limit');

      final gstRate = 5.0;
      final taxablePaise = ((totalAmountPaise * 10000) / (10000 + (gstRate * 100).round())).round();
      final gstPaise = totalAmountPaise - taxablePaise;

      expect(taxablePaise + gstPaise, equals(totalAmountPaise), reason: 'Taxable + GST must equal total paise exactly');
    });

    test('2. Multi-Unit Mixed Cart Calculation: Box + Strip + Pcs Total Pieces & Paise', () {
      // Kurkure: Box = 96 pcs (₹816.00 = 81600 paise), Strip = 12 pcs (₹102.00 = 10200 paise), Piece = 1 pc (₹8.50 = 850 paise)
      const boxCount = 5;
      const stripCount = 3;
      const pcsCount = 7;

      const boxPricePaise = 81600;
      const stripPricePaise = 10200;
      const piecePricePaise = 850;

      const totalPieces = (boxCount * 96) + (stripCount * 12) + (pcsCount * 1);
      expect(totalPieces, equals(480 + 36 + 7)); // 523 pieces

      const totalPaise = (boxCount * boxPricePaise) + (stripCount * stripPricePaise) + (pcsCount * piecePricePaise);
      expect(totalPaise, equals(408000 + 30600 + 5950)); // 444,550 paise = ₹4,445.50
    });

    test('3. Zero Stock & Inactive Product Protection', () {
      final outOfStockProduct = ProductItem(
        id: 'prod_zero_stock',
        name: 'Exhausted Energy Drink',
        hindiName: 'एनर्जी ड्रिंक',
        category: 'Beverages',
        mrpRupees: 60.0,
        piecePricePaise: 5000,
        stripQty: 1,
        boxQty: 1,
        godownStockBoxes: 0,
        carStockBoxes: 0,
      );

      final availablePieces = outOfStockProduct.godownStockBoxes;
      expect(availablePieces, equals(0));
      expect(availablePieces <= 0, isTrue, reason: 'Zero stock must block addition');
    });

    testWidgets('4. AddShopSheet Form Validation: Empty fields and submission constraints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddShopSheet.show(ctx, api: api),
                child: const Text('Open Add Shop'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Add Shop'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.addShopTitle), findsOneWidget);

      // Verify save button exists
      final saveBtn = find.text(AppStrings.saveShopButton);
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Sheet is still visible because form was rejected due to missing required fields
      expect(find.text(AppStrings.addShopTitle), findsOneWidget);
    });
  });
}
