import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/models/models.dart';

void main() {
  test('App restart persistence: preserves modified stock and retailer visits across process restarts', () async {
    final tempDir = await Directory.systemTemp.createTemp('routidrow_restart_test_');
    final dbFile = File('${tempDir.path}/test_restart.sqlite');
    AppDatabase? db2;

    try {
      // ----------------------------------------------------
      // Session 1: Initial App Launch & User Modifications
      // ----------------------------------------------------
      var db1 = AppDatabase(NativeDatabase(dbFile));
      var repo1 = LocalRepository(db1);

      final initialProducts = [
        ProductItem(
          id: 'P1',
          name: 'Kurkure Masala',
          hindiName: 'कुरकुरे',
          category: 'Snacks',
          mrpRupees: 20.0,
          piecePricePaise: 1600,
          stripQty: 12,
          boxQty: 48,
          godownStockBoxes: 100,
          carStockBoxes: 10,
        ),
      ];

      final initialRetailers = [
        RetailerShop(
          id: 'R1',
          name: 'Ganesh Kirana',
          ownerName: 'Ramprasad',
          phone: '9829012345',
          address: 'Station Rd',
          area: 'Clock Tower',
          creditLimitPaise: 5000000,
          outstandingPaise: 1000000,
        ),
      ];

      // Simulate startup sync
      await repo1.seedIfEmpty(initialProducts, initialRetailers);

      // User performs work: restocks P1 with 25 boxes, updates visit for R1
      await repo1.recordStockMovement(
        productId: 'P1',
        movementType: 'INWARD',
        cartonDelta: 25,
        loosePieceDelta: 0,
        reason: 'Restock shipment Basni',
        newGodownCartons: 125,
        newGodownLoosePieces: 0,
        newCarCartons: 10,
        newCarLoosePieces: 0,
      );

      await repo1.updateRetailerVisit(
        'R1',
        totalTimeSpentSeconds: 780,
        visitCountToday: 2,
        visitedToday: true,
      );

      // Close session 1 (simulating app quit / process termination)
      await db1.close();

      // ----------------------------------------------------
      // Session 2: Fresh Process Restart
      // ----------------------------------------------------
      db2 = AppDatabase(NativeDatabase(dbFile));
      var repo2 = LocalRepository(db2);

      // Startup sequence runs again on restart
      await repo2.seedIfEmpty(initialProducts, initialRetailers);

      final reloadedProducts = await repo2.getAllProducts();
      final reloadedRetailers = await repo2.getAllRetailers();
      final reloadedSnapshot = await repo2.getInventorySnapshot('P1');
      final reloadedMovements = await repo2.getMovementsForProduct('P1');

      // Verify data was NOT overwritten with initial seed values:
      expect(reloadedProducts.length, equals(1));
      expect(reloadedProducts.first.godownStockBoxes, equals(125),
          reason: 'Godown stock must reflect restock (125), not initial seed (100)');
      expect(reloadedSnapshot!.godownCartons, equals(125));

      expect(reloadedRetailers.length, equals(1));
      expect(reloadedRetailers.first.totalTimeSpentSeconds, equals(780),
          reason: 'Visit duration must survive restart');
      expect(reloadedRetailers.first.visitCountToday, equals(2));
      expect(reloadedRetailers.first.visitedToday, isTrue);

      expect(reloadedMovements.length, equals(2));
      final movementTypes = reloadedMovements.map((m) => m.movementType).toList();
      expect(movementTypes, containsAll(['OPENING_BALANCE', 'INWARD']));

      final inwardMov = reloadedMovements.firstWhere((m) => m.movementType == 'INWARD');
      expect(inwardMov.cartonDelta, equals(25));

      final openingMov = reloadedMovements.firstWhere((m) => m.movementType == 'OPENING_BALANCE');
      expect(openingMov.cartonDelta, equals(110)); // 100 godown + 10 car
    } finally {
      if (db2 != null) {
        await db2.close();
      }
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  });
}
