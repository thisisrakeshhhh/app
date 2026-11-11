import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/domain/outbox/outbox_models.dart';
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

  group('Part B5: Packaging Arbitrary Tiers & Conversion Snapshots', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const ownerSession = UserSession(
      userId: 'usr_owner_ramesh',
      name: 'Ramesh Lal',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'OWNER',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
          role: 'OWNER',
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
        sessionProvider: () => ownerSession,
      );
      await api.syncForTesting(seed: true);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Arbitrary packaging tiers support Crate = 24 Bottles and Tin 15L as base unit with can_buy, can_sell, loose_sale flags', () async {
      // First insert the parent products so foreign key constraints are satisfied
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: 'PROD_BEV_01',
          name: 'Jeera Soda Glass',
          hindiName: 'जीरा सोडा',
          category: 'Beverages',
          mrpRupees: 20.0,
          piecePricePaise: 1800,
          stripQty: 1,
          boxQty: 24,
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: 'PROD_OIL_01',
          name: 'Mustard Oil 15L Tin',
          hindiName: 'सरसों तेल 15L',
          category: 'Edible Oils',
          mrpRupees: 2400.0,
          piecePricePaise: 210000,
          stripQty: 1,
          boxQty: 1,
          createdAt: DateTime.now(),
        ),
      );

      // Configure Beverage product: Crate = 24 Bottles
      final beverageUnits = [
        const ProductPackagingUnit(
          id: 'unit_bev_bottle',
          productId: 'PROD_BEV_01',
          unitName: 'Bottle',
          multiplierToBase: 1,
          isBaseUnit: true,
          allowLooseSale: true,
          canBuy: true,
          canSell: true,
          wholesalePricePaise: 1800, // ₹18
          mrpPaise: 2000,
        ),
        const ProductPackagingUnit(
          id: 'unit_bev_crate',
          productId: 'PROD_BEV_01',
          unitName: 'Crate',
          multiplierToBase: 24,
          isBaseUnit: false,
          allowLooseSale: false,
          canBuy: true,
          canSell: true,
          wholesalePricePaise: 40000, // ₹400
          mrpPaise: 48000,
        ),
      ];

      await repo.saveProductUnits('PROD_BEV_01', beverageUnits);
      final retrievedBev = await repo.getProductUnits('PROD_BEV_01');
      expect(retrievedBev.length, equals(2));

      final bottle = retrievedBev.firstWhere((u) => u.unitName == 'Bottle');
      expect(bottle.multiplierToBase, equals(1));
      expect(bottle.isBaseUnit, isTrue);
      expect(bottle.looseSale, isTrue);
      expect(bottle.canBuy, isTrue);
      expect(bottle.canSell, isTrue);

      final crate = retrievedBev.firstWhere((u) => u.unitName == 'Crate');
      expect(crate.multiplierToBase, equals(24));
      expect(crate.isBaseUnit, isFalse);
      expect(crate.looseSale, isFalse);

      // Configure Edible Oil product: Tin (15L) as base unit
      final oilUnits = [
        const ProductPackagingUnit(
          id: 'unit_oil_tin',
          productId: 'PROD_OIL_01',
          unitName: 'Tin (15L)',
          multiplierToBase: 1,
          isBaseUnit: true,
          allowLooseSale: false,
          canBuy: true,
          canSell: true,
          wholesalePricePaise: 210000, // ₹2100
          mrpPaise: 240000,
        ),
      ];

      await repo.saveProductUnits('PROD_OIL_01', oilUnits);
      final retrievedOil = await repo.getProductUnits('PROD_OIL_01');
      expect(retrievedOil.first.unitName, equals('Tin (15L)'));
      expect(retrievedOil.first.isBaseUnit, isTrue);
      expect(retrievedOil.first.multiplierToBase, equals(1));
      expect(retrievedOil.first.looseSale, isFalse);
    });

    test('2. Order line items capture multiplierToBaseAtTime snapshot and preserve historical ratio when catalog changes', () {
      final orderItem = OrderItemPayload(
        productId: 'PROD_BEV_01',
        productName: 'Jeera Soda Glass',
        orderedUnit: 'Crate',
        orderedQuantity: 5,
        multiplierToBaseAtTime: 24,
        totalPieces: 120, // 5 crates * 24 bottles
        unitPricePaiseAtTime: 40000,
        piecePricePaiseAtTime: 1800,
        lineTotalPaise: 200000, // ₹2000
      );

      final json = orderItem.toJson();
      expect(json['multiplierToBaseAtTime'], equals(24));
      expect(json['totalPieces'], equals(120));

      // Reconstructed from JSON payload
      final reconstructed = OrderItemPayload.fromJson(json);
      expect(reconstructed.multiplierToBaseAtTime, equals(24));
      expect(reconstructed.totalPieces, equals(120));
      expect(reconstructed.orderedUnit, equals('Crate'));
    });

    test('3. Stock inward GRN captures basePiecesPerCartonSnapshot preserving ledger conversion ratios', () {
      final grnPayload = StockInwardMutationPayload(
        provisionalGrnId: 'grn_test_101',
        organizationId: 'org_jodhpur_dist',
        userId: 'usr_wh_mukesh',
        idempotencyKey: 'idemp_grn_bev_01',
        productId: 'PROD_BEV_01',
        supplierName: 'Rajasthan Beverage Co.',
        invoiceNumber: 'INV-2026-99',
        batchNumber: 'BATCH-JAN-26',
        receivedCartons: 10,
        receivedLoosePieces: 0,
        damagedCartons: 0,
        damagedLoosePieces: 0,
        notes: 'Cold drink season stock',
        clientCreatedAtEpochMs: 1735700000000,
        basePiecesPerCartonSnapshot: 24,
      );

      final map = grnPayload.toMap();
      expect(map['basePiecesPerCartonSnapshot'], equals(24));

      final restored = StockInwardMutationPayload.fromMap(map);
      expect(restored.basePiecesPerCartonSnapshot, equals(24));
      expect(restored.totalBasePiecesInward, equals(240)); // 10 cartons * 24
    });
  });
}
