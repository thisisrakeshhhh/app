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

  group('Slice 2: Product Packaging Builder & Data-Driven Unit Prices (Pillar C1)', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const testSession = UserSession(
      userId: 'usr_owner_ramesh',
      name: 'Ramesh Agarwal',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'ADMIN',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
          role: 'ADMIN',
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

    test('1. Custom packaging hierarchy supports arbitrary multi-tier units (e.g. 1 Crate = 24 Bottles)', () async {
      // Create a custom product: "Cold Drink 200ml Glass"
      // Units: 1 Bottle (base), 1 Crate = 24 Bottles
      const crateUnit = ProductPackagingUnit(
        id: 'unit_coke_crate',
        productId: 'prod_custom_coke',
        unitName: 'crate',
        multiplierToBase: 24,
        isBaseUnit: false,
        allowLooseSale: true,
        wholesalePricePaise: 44000, // Rs 440 per crate
        mrpPaise: 48000,
      );
      const bottleUnit = ProductPackagingUnit(
        id: 'unit_coke_bottle',
        productId: 'prod_custom_coke',
        unitName: 'bottle',
        multiplierToBase: 1,
        isBaseUnit: true,
        allowLooseSale: true,
        wholesalePricePaise: 1900, // Rs 19 per bottle
        mrpPaise: 2000,
      );

      await api.createProductDurable(
        id: 'prod_custom_coke',
        name: 'Cold Drink 200ml Glass',
        hindiName: 'कोल्ड ड्रिंक २०० मिली',
        category: 'BEVERAGES',
        mrpRupees: 20.0,
        piecePricePaise: 1900,
        stripQty: 1,
        boxQty: 24,
        units: [bottleUnit, crateUnit],
        idempotencyKey: 'idem_create_coke_001',
      );

      final units = await repo.getProductUnits('prod_custom_coke');
      expect(units.length, 2);
      expect(units.firstWhere((u) => u.unitName == 'bottle').multiplierToBase, 1);
      expect(units.firstWhere((u) => u.unitName == 'crate').multiplierToBase, 24);

      final product = api.products.firstWhere((p) => p.id == 'prod_custom_coke');
      expect(product.piecesForUnitName('bottle'), 1);
      expect(product.piecesForUnitName('crate'), 24);
      expect(product.priceForUnitName('bottle'), 1900);
      expect(product.priceForUnitName('crate'), 44000);
    });

    test('2. Price parity: existing products unit prices match exactly before and after migration without hardcoded floats', () async {
      // Kurkure Masala Munch in default catalog:
      // piecePricePaise = 850 (Rs 8.50)
      // stripQty = 12
      // boxQty = 96
      // Pre-migration strip formula: (850 * 12 * 0.98).round() = 9996 paise
      // Pre-migration box formula: (850 * 96 * 0.95).round() = 77520 paise
      await repo.backfillLegacyProductUnitsAndPrices();
      final products = await repo.getAllProducts();
      final kurkure = products.firstWhere((p) => p.id == 'KURK-01');
      
      // Verify backfilled data-driven prices
      expect(kurkure.priceForUnit(OrderUnit.piece), 850);
      expect(kurkure.priceForUnit(OrderUnit.strip), 9996);
      expect(kurkure.priceForUnit(OrderUnit.box), 77520);

      // Verify the prices are loaded from unit_prices table
      final dbPrices = await repo.getUnitPrices(kurkure.id);
      expect(dbPrices['piece'], 850);
      expect(dbPrices['strip'], 9996);
      expect(dbPrices['box'], 77520);
    });

    test('3. Archived product with order history cannot be hard-deleted (soft archive preservation)', () async {
      final sampleProd = api.products.first;

      // Product has initial opening balance movement
      final movementsBefore = await repo.getMovementsForProduct(sampleProd.id);
      expect(movementsBefore.isNotEmpty, isTrue);

      // Attempt deletion via repo
      await repo.deleteProduct(sampleProd.id);

      // Product must NOT be deleted from database; it must be soft-archived
      final isArchived = await repo.isProductArchived(sampleProd.id);
      expect(isArchived, isTrue, reason: 'Product with historical movements must be soft-archived, not wiped');

      // The snapshot and movements must remain 100% intact
      final snapshot = await repo.getInventorySnapshot(sampleProd.id);
      expect(snapshot, isNotNull);
      final movementsAfter = await repo.getMovementsForProduct(sampleProd.id);
      expect(movementsAfter.length, movementsBefore.length);
    });

    test('4. Adding or editing packaging creates UPDATE_PRODUCT_UNITS outbox mutation atomically', () async {
      final sampleProd = api.products.first;
      
      const newCustomUnit = ProductPackagingUnit(
        id: 'unit_custom_jar',
        productId: 'prod_1',
        unitName: 'jar',
        multiplierToBase: 100,
        isBaseUnit: false,
        allowLooseSale: true,
        wholesalePricePaise: 80000,
        mrpPaise: 90000,
      );

      await api.updateProductUnitsDurable(
        productId: sampleProd.id,
        units: [
          ProductPackagingUnit(
            id: 'unit_piece_${sampleProd.id}',
            productId: sampleProd.id,
            unitName: 'piece',
            multiplierToBase: 1,
            isBaseUnit: true,
            wholesalePricePaise: sampleProd.piecePricePaise,
          ),
          newCustomUnit,
        ],
        idempotencyKey: 'idem_unit_edit_99',
      );

      // Verify outbox mutation was persisted
      final pendingMutations = await db.outboxDao.getPendingQueue();
      final unitMutations = pendingMutations.where(
        (m) => m.mutationType == MutationType.updateProductUnits.toDbValue(),
      ).toList();

      expect(unitMutations.isNotEmpty, isTrue);
      final mutation = unitMutations.first;
      expect(mutation.idempotencyKey, 'idem_unit_edit_99');

      final payload = UpdateProductUnitsPayload.fromCanonicalJson(mutation.payloadJson);
      expect(payload.productId, sampleProd.id);
      expect(payload.units.length, 2);
      expect(payload.units.any((u) => u.unitName == 'jar'), isTrue);
    });
  });
}
