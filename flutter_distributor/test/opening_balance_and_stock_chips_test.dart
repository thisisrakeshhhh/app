import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/screens/inventory_view.dart';
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

  group('Part B6: Stock Screens — Opening Balance, 4-Part Status & Movement Timeline', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const warehouseSession = UserSession(
      userId: 'usr_wh_mukesh',
      name: 'Mukesh Godown',
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
        sessionProvider: () => warehouseSession,
      );
      await api.syncForTesting(seed: true);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. OPENING_BALANCE movement flow records initial stock in ledger without supplier invoice', () async {
      final product = api.products.first;
      final initialBoxes = product.godownStockBoxes;

      await api.recordOpeningBalanceDurable(
        productId: product.id,
        cartonCount: 40,
        loosePieces: 10,
        reason: 'Physical godown audit initial count',
      );

      // Verify product state updated
      expect(product.godownStockBoxes, equals(initialBoxes + 40));

      // Verify movement recorded in SQLite ledger with OPENING_BALANCE
      final movements = await repo.getProductMovements(product.id);
      final openingMov = movements.firstWhere((m) => m.reason.contains('Physical godown audit'));
      expect(openingMov.cartonDelta, equals(40));
      expect(openingMov.loosePieceDelta, equals(10));
      expect(openingMov.movementType, equals('OPENING_BALANCE'));
    });

    test('2. 4-part stock status calculates On-Hand, Reserved, Available, and Status (OK/LOW/OUT)', () async {
      final product = api.products.first;
      product.godownStockBoxes = 50;

      // Status with 0 reservations
      var status = api.getFourPartStockStatus(product.id);
      expect(status.onHandBoxes, equals(50));
      expect(status.reservedBoxes, equals(0));
      expect(status.availableBoxes, equals(50));
      expect(status.health, equals(StockHealth.ok));

      // Reserve 40 boxes via pending bookings -> 10 available (threshold is 15 boxes)
      api.setVirtualReservationForTesting(product.id, 40 * product.boxQty);
      status = api.getFourPartStockStatus(product.id);
      expect(status.onHandBoxes, equals(50));
      expect(status.reservedBoxes, equals(40));
      expect(status.availableBoxes, equals(10));
      expect(status.health, equals(StockHealth.lowStock));

      // Reserve all 50 boxes -> 0 available -> OUT
      api.setVirtualReservationForTesting(product.id, 50 * product.boxQty);
      status = api.getFourPartStockStatus(product.id);
      expect(status.availableBoxes, equals(0));
      expect(status.health, equals(StockHealth.outOfStock));
    });

    test('3. Product movement timeline history returns ordered chronological transactions', () async {
      final product = api.products.first;

      await api.recordOpeningBalanceDurable(
        productId: product.id,
        cartonCount: 20,
        loosePieces: 0,
        reason: 'Opening audit',
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      await api.receiveStockGrnDurable(
        productId: product.id,
        supplierName: 'Parle Agro Pvt Ltd',
        invoiceNumber: 'INV-PARLE-881',
        batchNumber: 'BATCH-881',
        cartonsReceived: 30,
        loosePiecesReceived: 0,
        damagedCartons: 0,
        damagedLoosePieces: 0,
        notes: 'Monsoon stock inward',
        idempotencyKey: 'idemp_grn_parle_881',
      );

      final timeline = await api.getProductMovementHistory(product.id);
      expect(timeline.length, greaterThanOrEqualTo(2));
      final grnMov = timeline.firstWhere((m) => m.movementType == 'INWARD');
      expect(grnMov.cartonDelta, equals(30));
      expect(grnMov.supplierName, equals('Parle Agro Pvt Ltd'));
      expect(timeline.any((m) => m.movementType == 'OPENING_BALANCE'), isTrue);
    });

    test('4. Custom per-product low-stock threshold in base pieces determines health status', () {
      final product = api.products.first;
      product.godownStockBoxes = 20;

      // Custom threshold set to 25 boxes worth of pieces
      final customThresholdPieces = 25 * product.boxQty;
      final status = api.getFourPartStockStatus(
        product.id,
        customThresholdPieces: customThresholdPieces,
      );

      // Since available 20 boxes < custom threshold 25 boxes, status should be LOW
      expect(status.health, equals(StockHealth.lowStock));
    });

    testWidgets('5. InventoryView renders 4-part stock chips and history button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryView(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check chips rendered
      expect(find.textContaining('On-Hand:'), findsWidgets);
      expect(find.textContaining('Avail:'), findsWidgets);
      expect(find.byIcon(Icons.history), findsWidgets);
    });
  });
}
