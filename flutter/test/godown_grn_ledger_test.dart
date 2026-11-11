import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/domain/outbox/outbox_models.dart';
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

  group('Slice 3: Receive Stock (GRN) + Double-Entry Ledger (Pillar C2)', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const testSession = UserSession(
      userId: 'usr_warehouse_sohan',
      name: 'Sohan Lal',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'WAREHOUSE',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
          role: 'WAREHOUSE',
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

    test('1. Inward receipt credits godownCartons and posts INWARD ledger entry', () async {
      final sampleProd = api.products.first;
      final initialSnapshot = await repo.getInventorySnapshot(sampleProd.id);
      final initialGodownBoxes = initialSnapshot?.godownCartons ?? 0;

      await api.receiveStockGrnDurable(
        productId: sampleProd.id,
        supplierName: 'Parle Agro Jodhpur Depot',
        invoiceNumber: 'INV-2026-9041',
        batchNumber: 'B-7729',
        cartonsReceived: 50,
        loosePiecesReceived: 0,
        damagedCartons: 0,
        damagedLoosePieces: 0,
        notes: 'Delivered via Ashok Leyland RJ-19-1234',
        idempotencyKey: 'idem_grn_001',
      );

      // Verify Snapshot updated
      final updatedSnapshot = await repo.getInventorySnapshot(sampleProd.id);
      expect(updatedSnapshot?.godownCartons, initialGodownBoxes + 50);

      // Verify Ledger Entry posted
      final movements = await repo.getMovementsForProduct(sampleProd.id);
      final inwardMovements = movements.where((m) => m.movementType == 'INWARD').toList();
      expect(inwardMovements.isNotEmpty, isTrue);

      final latestInward = inwardMovements.first;
      expect(latestInward.cartonDelta, 50);
      expect(latestInward.supplierName, 'Parle Agro Jodhpur Depot');
      expect(latestInward.invoiceNumber, 'INV-2026-9041');
      expect(latestInward.batchNumber, 'B-7729');
    });

    test('2. Damaged stock credits damagedCartons and is strictly excluded from sellable stock calculation', () async {
      final sampleProd = api.products.first;
      final initialSnapshot = await repo.getInventorySnapshot(sampleProd.id);
      final initialGodownBoxes = initialSnapshot?.godownCartons ?? 0;
      final initialDamagedBoxes = initialSnapshot?.damagedCartons ?? 0;

      await api.receiveStockGrnDurable(
        productId: sampleProd.id,
        supplierName: 'PepsiCo Hub Sangaria',
        invoiceNumber: 'CH-8812',
        batchNumber: 'B-8812',
        cartonsReceived: 80,
        loosePiecesReceived: 0,
        damagedCartons: 4, // 4 boxes crushed during transport
        damagedLoosePieces: 10,
        notes: 'Water damage on lower pallet',
        idempotencyKey: 'idem_grn_damaged_002',
      );

      final updatedSnapshot = await repo.getInventorySnapshot(sampleProd.id);
      // Godown sellable boxes must only increment by clean received boxes
      expect(updatedSnapshot?.godownCartons, initialGodownBoxes + 80);
      // Damaged boxes stored separately in quarantine storage
      expect(updatedSnapshot?.damagedCartons, initialDamagedBoxes + 4);
      expect(updatedSnapshot?.damagedLoosePieces, 10);

      // Sellable stock calculation in memory must never expose damaged boxes as available for kirana booking
      final memoryProd = api.products.firstWhere((p) => p.id == sampleProd.id);
      expect(memoryProd.godownStockBoxes, initialGodownBoxes + 80);
      expect(memoryProd.totalStockBoxes, memoryProd.godownStockBoxes + memoryProd.carStockBoxes);
    });

    test('3. Reversal posts INWARD_REVERSAL offsetting ledger row without deleting history', () async {
      final sampleProd = api.products.first;

      await api.receiveStockGrnDurable(
        productId: sampleProd.id,
        supplierName: 'Haldiram Snacks Bikaner',
        invoiceNumber: 'INV-BIK-102',
        batchNumber: 'B-102',
        cartonsReceived: 30,
        loosePiecesReceived: 0,
        damagedCartons: 0,
        damagedLoosePieces: 0,
        notes: 'Mistakenly entered twice',
        idempotencyKey: 'idem_grn_rev_003',
      );

      final movementsBefore = await repo.getMovementsForProduct(sampleProd.id);
      final originalMovement = movementsBefore.firstWhere((m) => m.invoiceNumber == 'INV-BIK-102');

      // Issue reversal
      await api.reverseGrnMovementDurable(
        movementId: originalMovement.id,
        reason: 'Duplicate entry created by warehouse clerk',
        idempotencyKey: 'idem_rev_action_003',
      );

      final movementsAfter = await repo.getMovementsForProduct(sampleProd.id);
      // Original movement must still exist in ledger!
      expect(movementsAfter.any((m) => m.id == originalMovement.id), isTrue);

      // Offset movement must be recorded
      final reversalMovement = movementsAfter.firstWhere((m) => m.movementType == 'INWARD_REVERSAL');
      expect(reversalMovement.cartonDelta, -30);
      expect(reversalMovement.reason, contains('Duplicate entry created by warehouse clerk'));

      // Total count of movements increased by 1 (append-only ledger)
      expect(movementsAfter.length, movementsBefore.length + 1);
    });

    test('4. Offline durable outbox mutation STOCK_INWARD is written atomically', () async {
      final sampleProd = api.products.first;

      await api.receiveStockGrnDurable(
        productId: sampleProd.id,
        supplierName: 'Britannia Industries Jaipur',
        invoiceNumber: 'BRIT-8842',
        batchNumber: 'BATCH-44',
        cartonsReceived: 100,
        loosePiecesReceived: 12,
        damagedCartons: 2,
        damagedLoosePieces: 0,
        notes: 'Monsoon shipment arrived damp',
        idempotencyKey: 'idem_grn_outbox_004',
      );

      final pendingMutations = await db.outboxDao.getPendingQueue();
      final grnMutations = pendingMutations.where(
        (m) => m.mutationType == MutationType.stockInward.toDbValue(),
      ).toList();

      expect(grnMutations.isNotEmpty, isTrue);
      final mutation = grnMutations.first;
      expect(mutation.idempotencyKey, 'idem_grn_outbox_004');

      final payload = StockInwardMutationPayload.fromCanonicalJson(mutation.payloadJson);
      expect(payload.productId, sampleProd.id);
      expect(payload.supplierName, 'Britannia Industries Jaipur');
      expect(payload.receivedCartons, 100);
      expect(payload.damagedCartons, 2);
    });
  });
}
