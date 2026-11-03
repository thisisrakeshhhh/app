import 'package:drift/drift.dart';
import '../../models/models.dart';
import 'app_database.dart';

class LocalRepository {
  final AppDatabase db;

  LocalRepository(this.db);

  // Database Metadata
  Future<String?> getMetadata(String key) async {
    final query = db.select(db.databaseMetadata)
      ..where((tbl) => tbl.key.equals(key));
    final entry = await query.getSingleOrNull();
    return entry?.value;
  }

  Future<void> setMetadata(String key, String value) async {
    await db.into(db.databaseMetadata).insertOnConflictUpdate(
      DatabaseMetadataCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Products & Inventory Snapshots
  Future<List<ProductItem>> getAllProducts({bool includeArchived = false}) async {
    final query = db.select(db.products);
    if (!includeArchived) {
      query.where((tbl) => tbl.isArchived.equals(false));
    }
    final products = await query.get();
    final snapshots = await db.select(db.inventorySnapshots).get();
    final allUnits = await db.select(db.productUnits).get();
    final allPrices = await db.select(db.unitPrices).get();

    final snapshotMap = {for (var s in snapshots) s.productId: s};

    final unitsByProd = <String, Map<String, int>>{};
    for (var u in allUnits) {
      unitsByProd.putIfAbsent(u.productId, () => {})[u.unitName.toLowerCase()] = u.multiplierToBase;
    }

    final pricesByProd = <String, Map<String, int>>{};
    for (var pr in allPrices) {
      pricesByProd.putIfAbsent(pr.productId, () => {})[pr.unitName.toLowerCase()] = pr.wholesalePricePaise;
    }

    return products.map((p) {
      final snap = snapshotMap[p.id];
      return ProductItem(
        id: p.id,
        name: p.name,
        hindiName: p.hindiName,
        category: p.category,
        mrpPaise: p.mrpPaise > 0 ? p.mrpPaise : (p.mrpRupees * 100).round(),
        mrpRupees: p.mrpRupees,
        piecePricePaise: p.piecePricePaise,
        stripQty: p.stripQty,
        boxQty: p.boxQty,
        gstRate: p.gstRate,
        godownStockBoxes: snap?.godownCartons ?? 0,
        carStockBoxes: snap?.carCartons ?? 0,
        badge: p.badge,
        imageUrl: p.imageUrl,
        customUnitMultipliers: unitsByProd[p.id],
        customUnitPricesPaise: pricesByProd[p.id],
      );
    }).toList();
  }

  /// Backfills data-driven packaging units and wholesale prices for legacy products
  /// so that starting pricing matches existing formulas exactly down to the paise.
  Future<void> backfillLegacyProductUnitsAndPrices() async {
    final products = await db.select(db.products).get();
    final existingUnits = await db.select(db.productUnits).get();
    final prodsWithUnits = existingUnits.map((u) => u.productId).toSet();

    await db.transaction(() async {
      for (final p in products) {
        if (!prodsWithUnits.contains(p.id)) {
          final now = DateTime.now();
          // 1. Piece
          await db.into(db.productUnits).insertOnConflictUpdate(
            ProductUnitsCompanion(
              id: Value('unit_pcs_${p.id}'),
              productId: Value(p.id),
              unitName: const Value('piece'),
              multiplierToBase: const Value(1),
              isBaseUnit: const Value(true),
              allowLooseSale: const Value(true),
              createdAt: Value(now),
            ),
          );
          await db.into(db.unitPrices).insertOnConflictUpdate(
            UnitPricesCompanion(
              id: Value('price_pcs_${p.id}'),
              productId: Value(p.id),
              unitName: const Value('piece'),
              wholesalePricePaise: Value(p.piecePricePaise),
              mrpPaise: Value((p.mrpRupees * 100).round()),
              minOrderQty: const Value(1),
              updatedAt: Value(now),
            ),
          );

          // 2. Strip
          final stripMultiplier = p.stripQty > 0 ? p.stripQty : 1;
          final stripPrice = (p.piecePricePaise * stripMultiplier * 0.98).round();
          await db.into(db.productUnits).insertOnConflictUpdate(
            ProductUnitsCompanion(
              id: Value('unit_strip_${p.id}'),
              productId: Value(p.id),
              unitName: const Value('strip'),
              multiplierToBase: Value(stripMultiplier),
              isBaseUnit: const Value(false),
              allowLooseSale: const Value(true),
              createdAt: Value(now),
            ),
          );
          await db.into(db.unitPrices).insertOnConflictUpdate(
            UnitPricesCompanion(
              id: Value('price_strip_${p.id}'),
              productId: Value(p.id),
              unitName: const Value('strip'),
              wholesalePricePaise: Value(stripPrice),
              mrpPaise: Value(((p.mrpRupees * 100) * stripMultiplier).round()),
              minOrderQty: const Value(1),
              updatedAt: Value(now),
            ),
          );

          // 3. Box
          final boxMultiplier = p.boxQty > 0 ? p.boxQty : 1;
          final boxPrice = (p.piecePricePaise * boxMultiplier * 0.95).round();
          await db.into(db.productUnits).insertOnConflictUpdate(
            ProductUnitsCompanion(
              id: Value('unit_box_${p.id}'),
              productId: Value(p.id),
              unitName: const Value('box'),
              multiplierToBase: Value(boxMultiplier),
              isBaseUnit: const Value(false),
              allowLooseSale: const Value(true),
              createdAt: Value(now),
            ),
          );
          await db.into(db.unitPrices).insertOnConflictUpdate(
            UnitPricesCompanion(
              id: Value('price_box_${p.id}'),
              productId: Value(p.id),
              unitName: const Value('box'),
              wholesalePricePaise: Value(boxPrice),
              mrpPaise: Value(((p.mrpRupees * 100) * boxMultiplier).round()),
              minOrderQty: const Value(1),
              updatedAt: Value(now),
            ),
          );
        }
      }
    });
  }

  Future<void> saveProductUnits(String productId, List<ProductPackagingUnit> units) async {
    await db.transaction(() async {
      await (db.delete(db.productUnits)..where((tbl) => tbl.productId.equals(productId))).go();
      await (db.delete(db.unitPrices)..where((tbl) => tbl.productId.equals(productId))).go();

      final now = DateTime.now();
      for (final u in units) {
        await db.into(db.productUnits).insert(
          ProductUnitsCompanion(
            id: Value(u.id),
            productId: Value(productId),
            unitName: Value(u.unitName),
            multiplierToBase: Value(u.multiplierToBase),
            isBaseUnit: Value(u.isBaseUnit),
            allowLooseSale: Value(u.allowLooseSale),
            createdAt: Value(now),
          ),
        );
        await db.into(db.unitPrices).insert(
          UnitPricesCompanion(
            id: Value('price_${u.id}'),
            productId: Value(productId),
            unitName: Value(u.unitName),
            wholesalePricePaise: Value(u.wholesalePricePaise),
            mrpPaise: Value(u.mrpPaise),
            minOrderQty: Value(u.minOrderQty),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  Future<List<ProductPackagingUnit>> getProductUnits(String productId) async {
    final units = await (db.select(db.productUnits)..where((tbl) => tbl.productId.equals(productId))).get();
    final prices = await (db.select(db.unitPrices)..where((tbl) => tbl.productId.equals(productId))).get();
    final priceMap = {for (var p in prices) p.unitName.toLowerCase(): p};

    return units.map((u) {
      final pr = priceMap[u.unitName.toLowerCase()];
      return ProductPackagingUnit(
        id: u.id,
        productId: u.productId,
        unitName: u.unitName,
        multiplierToBase: u.multiplierToBase,
        isBaseUnit: u.isBaseUnit,
        allowLooseSale: u.allowLooseSale,
        wholesalePricePaise: pr?.wholesalePricePaise ?? 0,
        mrpPaise: pr?.mrpPaise ?? 0,
        minOrderQty: pr?.minOrderQty ?? 1,
      );
    }).toList();
  }

  Future<Map<String, int>> getUnitPrices(String productId) async {
    final prices = await (db.select(db.unitPrices)..where((tbl) => tbl.productId.equals(productId))).get();
    return {for (var p in prices) p.unitName.toLowerCase(): p.wholesalePricePaise};
  }

  Future<void> upsertProduct(ProductItem item) async {
    await db.transaction(() async {
      await db.into(db.products).insertOnConflictUpdate(
        ProductsCompanion(
          id: Value(item.id),
          name: Value(item.name),
          hindiName: Value(item.hindiName),
          category: Value(item.category),
          mrpRupees: Value(item.mrpRupees),
          mrpPaise: Value(item.mrpPaise),
          piecePricePaise: Value(item.piecePricePaise),
          stripQty: Value(item.stripQty),
          boxQty: Value(item.boxQty),
          gstRate: Value(item.gstRate),
          badge: Value(item.badge),
          imageUrl: Value(item.imageUrl),
          isArchived: const Value(false),
          createdAt: Value(DateTime.now()),
        ),
      );

      final existing = await (db.select(
        db.inventorySnapshots,
      )..where((tbl) => tbl.productId.equals(item.id))).getSingleOrNull();
      if (existing == null) {
        await db.into(db.inventorySnapshots).insert(
          InventorySnapshotsCompanion(
            productId: Value(item.id),
            godownCartons: Value(item.godownStockBoxes),
            godownLoosePieces: const Value(0),
            carCartons: Value(item.carStockBoxes),
            carLoosePieces: const Value(0),
            updatedAt: Value(DateTime.now()),
          ),
        );

        final totalInitialBoxes = item.godownStockBoxes + item.carStockBoxes;
        if (totalInitialBoxes > 0) {
          final existingOpening = await (db.select(db.inventoryMovements)
                ..where((tbl) =>
                    tbl.productId.equals(item.id) &
                    tbl.movementType.equals('OPENING_BALANCE')))
              .getSingleOrNull();

          if (existingOpening == null) {
            await db.into(db.inventoryMovements).insert(
              InventoryMovementsCompanion(
                id: Value('mov_opening_${item.id}'),
                productId: Value(item.id),
                movementType: const Value('OPENING_BALANCE'),
                cartonDelta: Value(totalInitialBoxes),
                loosePieceDelta: const Value(0),
                reason: const Value('Initial opening stock on product creation'),
                createdAt: Value(DateTime.now()),
              ),
            );
          }
        }
      }
    });
  }

  /// Soft-archives a product, hiding it from normal active catalogs while preserving
  /// all past inventory movements and snapshots for auditing.
  Future<void> archiveProduct(String productId) async {
    await (db.update(db.products)..where((tbl) => tbl.id.equals(productId)))
        .write(const ProductsCompanion(isArchived: Value(true)));
  }

  /// Restores a previously archived product back into active catalog service.
  Future<void> restoreProduct(String productId) async {
    await (db.update(db.products)..where((tbl) => tbl.id.equals(productId)))
        .write(const ProductsCompanion(isArchived: Value(false)));
  }

  /// Checks whether a product is currently archived.
  Future<bool> isProductArchived(String productId) async {
    final prod = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals(productId)))
        .getSingleOrNull();
    return prod?.isArchived ?? false;
  }

  /// Deletes a product safely. If historical movements exist, it soft-archives
  /// rather than destructively purging audit logs. If no movements exist (e.g. freshly created unstocked item),
  /// it cleans up the product and snapshot.
  Future<void> deleteProduct(String productId) async {
    final movements = await getMovementsForProduct(productId);
    if (movements.isNotEmpty) {
      await archiveProduct(productId);
      return;
    }

    await db.transaction(() async {
      await (db.delete(db.productUnits)
            ..where((tbl) => tbl.productId.equals(productId)))
          .go();
      await (db.delete(db.unitPrices)
            ..where((tbl) => tbl.productId.equals(productId)))
          .go();
      await (db.delete(
        db.inventorySnapshots,
      )..where((tbl) => tbl.productId.equals(productId))).go();
      await (db.delete(
        db.products,
      )..where((tbl) => tbl.id.equals(productId))).go();
    });
  }

  // Inventory Snapshots and Movements
  Future<InventorySnapshotEntry?> getInventorySnapshot(String productId) async {
    return (db.select(
      db.inventorySnapshots,
    )..where((tbl) => tbl.productId.equals(productId))).getSingleOrNull();
  }

  Future<List<InventoryMovementEntry>> getMovementsForProduct(
    String productId,
  ) async {
    final query = db.select(db.inventoryMovements)
      ..where((tbl) => tbl.productId.equals(productId))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.createdAt),
        (tbl) => OrderingTerm.desc(tbl.id),
      ]);
    return query.get();
  }

  Future<void> recordStockMovement({
    required String productId,
    required String movementType,
    required int cartonDelta,
    required int loosePieceDelta,
    required String reason,
    required int newGodownCartons,
    required int newGodownLoosePieces,
    required int newCarCartons,
    required int newCarLoosePieces,
  }) async {
    final product = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals(productId)))
        .getSingleOrNull();
    if (product == null) {
      throw StateError('Cannot record stock movement: Product $productId does not exist');
    }
    if (product.isArchived) {
      throw StateError(
          'Cannot record stock movement: Product $productId is archived. Restore before modifying stock.');
    }

    await db.transaction(() async {
      await db.into(db.inventorySnapshots).insertOnConflictUpdate(
        InventorySnapshotsCompanion(
          productId: Value(productId),
          godownCartons: Value(newGodownCartons),
          godownLoosePieces: Value(newGodownLoosePieces),
          carCartons: Value(newCarCartons),
          carLoosePieces: Value(newCarLoosePieces),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final movementId =
          'mov_${DateTime.now().microsecondsSinceEpoch}_$productId';
      await db.into(db.inventoryMovements).insert(
        InventoryMovementsCompanion(
          id: Value(movementId),
          productId: Value(productId),
          movementType: Value(movementType),
          cartonDelta: Value(cartonDelta),
          loosePieceDelta: Value(loosePieceDelta),
          reason: Value(reason),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Records a Goods Received Note (GRN) inward receipt, updating live inventory
  /// and posting immutable double-entry movement rows.
  Future<void> recordGrnReceipt({
    required String productId,
    required String supplierName,
    required String invoiceNumber,
    required String batchNumber,
    required int cartonsReceived,
    required int loosePiecesReceived,
    required int damagedCartons,
    required int damagedLoosePieces,
    required String notes,
    String? idempotencyKey,
  }) async {
    final product = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals(productId)))
        .getSingleOrNull();
    if (product == null) {
      throw StateError('Cannot record GRN receipt: Product $productId does not exist');
    }
    if (product.isArchived) {
      throw StateError(
          'Cannot record GRN receipt: Product $productId is archived. Restore before receiving stock.');
    }

    await db.transaction(() async {
      final current = await (db.select(db.inventorySnapshots)
            ..where((tbl) => tbl.productId.equals(productId)))
          .getSingleOrNull();

      final currentGodownCartons = current?.godownCartons ?? 0;
      final currentGodownLoose = current?.godownLoosePieces ?? 0;
      final currentCarCartons = current?.carCartons ?? 0;
      final currentCarLoose = current?.carLoosePieces ?? 0;
      final currentDamagedCartons = current?.damagedCartons ?? 0;
      final currentDamagedLoose = current?.damagedLoosePieces ?? 0;

      final updatedGodownCartons = currentGodownCartons + cartonsReceived;
      final updatedGodownLoose = currentGodownLoose + loosePiecesReceived;
      final updatedDamagedCartons = currentDamagedCartons + damagedCartons;
      final updatedDamagedLoose = currentDamagedLoose + damagedLoosePieces;

      await db.into(db.inventorySnapshots).insertOnConflictUpdate(
        InventorySnapshotsCompanion(
          productId: Value(productId),
          godownCartons: Value(updatedGodownCartons),
          godownLoosePieces: Value(updatedGodownLoose),
          carCartons: Value(currentCarCartons),
          carLoosePieces: Value(currentCarLoose),
          damagedCartons: Value(updatedDamagedCartons),
          damagedLoosePieces: Value(updatedDamagedLoose),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final now = DateTime.now();
      // 1. Post inward movement for received sellable stock
      final movementId = 'mov_grn_${now.microsecondsSinceEpoch}_$productId';
      await db.into(db.inventoryMovements).insert(
        InventoryMovementsCompanion(
          id: Value(movementId),
          productId: Value(productId),
          movementType: const Value('INWARD'),
          cartonDelta: Value(cartonsReceived),
          loosePieceDelta: Value(loosePiecesReceived),
          reason: Value(notes.isEmpty ? 'Inward GRN receipt' : notes),
          supplierName: Value(supplierName),
          invoiceNumber: Value(invoiceNumber),
          batchNumber: Value(batchNumber),
          idempotencyKey: Value(idempotencyKey),
          createdAt: Value(now),
        ),
      );

      // 2. If damaged stock arrived, post audit entry
      if (damagedCartons > 0 || damagedLoosePieces > 0) {
        final damagedMovementId = 'mov_dmg_${now.microsecondsSinceEpoch}_$productId';
        await db.into(db.inventoryMovements).insert(
          InventoryMovementsCompanion(
            id: Value(damagedMovementId),
            productId: Value(productId),
            movementType: const Value('DAMAGED_INWARD'),
            cartonDelta: Value(damagedCartons),
            loosePieceDelta: Value(damagedLoosePieces),
            reason: Value('Damaged stock reported during inward GRN: $notes'),
            supplierName: Value(supplierName),
            invoiceNumber: Value(invoiceNumber),
            batchNumber: Value(batchNumber),
            idempotencyKey: Value(idempotencyKey != null ? '${idempotencyKey}_dmg' : null),
            createdAt: Value(now),
          ),
        );
      }
    });
  }

  /// Offsets a previous inward GRN movement via an immutable INWARD_REVERSAL row,
  /// preserving historical records for complete ledger auditability.
  Future<void> reverseGrnMovement({
    required String movementId,
    required String reason,
    String? idempotencyKey,
  }) async {
    final original = await (db.select(db.inventoryMovements)
          ..where((tbl) => tbl.id.equals(movementId)))
        .getSingleOrNull();
    if (original == null) {
      throw StateError('Cannot reverse movement: Movement $movementId not found');
    }

    await db.transaction(() async {
      final current = await (db.select(db.inventorySnapshots)
            ..where((tbl) => tbl.productId.equals(original.productId)))
          .getSingleOrNull();

      final currentGodownCartons = current?.godownCartons ?? 0;
      final currentGodownLoose = current?.godownLoosePieces ?? 0;
      final currentCarCartons = current?.carCartons ?? 0;
      final currentCarLoose = current?.carLoosePieces ?? 0;
      final currentDamagedCartons = current?.damagedCartons ?? 0;
      final currentDamagedLoose = current?.damagedLoosePieces ?? 0;

      final updatedGodownCartons = currentGodownCartons - original.cartonDelta;
      final updatedGodownLoose = currentGodownLoose - original.loosePieceDelta;

      await db.into(db.inventorySnapshots).insertOnConflictUpdate(
        InventorySnapshotsCompanion(
          productId: Value(original.productId),
          godownCartons: Value(updatedGodownCartons),
          godownLoosePieces: Value(updatedGodownLoose),
          carCartons: Value(currentCarCartons),
          carLoosePieces: Value(currentCarLoose),
          damagedCartons: Value(currentDamagedCartons),
          damagedLoosePieces: Value(currentDamagedLoose),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final now = DateTime.now();
      final reversalId = 'mov_rev_${now.microsecondsSinceEpoch}_${original.productId}';
      await db.into(db.inventoryMovements).insert(
        InventoryMovementsCompanion(
          id: Value(reversalId),
          productId: Value(original.productId),
          movementType: const Value('INWARD_REVERSAL'),
          cartonDelta: Value(-original.cartonDelta),
          loosePieceDelta: Value(-original.loosePieceDelta),
          reason: Value('Reversal of movement $movementId: $reason'),
          supplierName: Value(original.supplierName),
          invoiceNumber: Value(original.invoiceNumber),
          batchNumber: Value(original.batchNumber),
          idempotencyKey: Value(idempotencyKey),
          createdAt: Value(now),
        ),
      );
    });
  }

  // Cart Drafts Persistence
  Future<void> saveCartDraft(String retailerId, String itemsJson) async {
    await db.into(db.cartDrafts).insertOnConflictUpdate(
      CartDraftsCompanion(
        retailerId: Value(retailerId),
        itemsJson: Value(itemsJson),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String?> getCartDraft(String retailerId) async {
    final row = await (db.select(db.cartDrafts)
          ..where((tbl) => tbl.retailerId.equals(retailerId)))
        .getSingleOrNull();
    return row?.itemsJson;
  }

  Future<void> deleteCartDraft(String retailerId) async {
    await (db.delete(db.cartDrafts)
          ..where((tbl) => tbl.retailerId.equals(retailerId)))
        .go();
  }

  // Field Visits
  Future<void> recordVisit({
    required String id,
    required String retailerId,
    required String userId,
    required String outcome,
    required String notes,
    required DateTime startTime,
    DateTime? endTime,
  }) async {
    await db.into(db.visits).insert(
      VisitsCompanion(
        id: Value(id),
        retailerId: Value(retailerId),
        userId: Value(userId),
        startTime: Value(startTime),
        endTime: Value(endTime ?? DateTime.now()),
        outcome: Value(outcome),
        notes: Value(notes),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<VisitEntry>> getVisitsForRetailer(String retailerId) async {
    final query = db.select(db.visits)
      ..where((tbl) => tbl.retailerId.equals(retailerId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.get();
  }

  // Retailers
  Future<List<RetailerShop>> getAllRetailers() async {
    final rows = await db.select(db.retailers).get();
    return rows
        .map(
          (r) => RetailerShop(
            id: r.id,
            name: r.name,
            ownerName: r.ownerName,
            phone: r.phone,
            address: r.address,
            area: r.area,
            creditLimitPaise: r.creditLimitPaise,
            outstandingPaise: r.outstandingPaise,
            visitedToday: r.visitedToday,
            totalTimeSpentSeconds: r.totalTimeSpentSeconds,
            visitCountToday: r.visitCountToday,
            latitude: r.latitude,
            longitude: r.longitude,
            classType: r.classType,
            classSource: r.classSource,
            routeId: r.routeId,
            shopType: r.shopType,
            gstin: r.gstin,
            pincode: r.pincode,
            landmark: r.landmark,
            status: r.status,
            createdByUserId: r.createdByUserId,
            locationAccuracyMeters: r.locationAccuracyMeters,
            syncStatus: r.syncStatus,
          ),
        )
        .toList();
  }

  Future<void> upsertRetailer(RetailerShop retailer) async {
    await db.into(db.retailers).insertOnConflictUpdate(
      RetailersCompanion(
        id: Value(retailer.id),
        name: Value(retailer.name),
        ownerName: Value(retailer.ownerName),
        phone: Value(retailer.phone),
        address: Value(retailer.address),
        area: Value(retailer.area),
        creditLimitPaise: Value(retailer.creditLimitPaise),
        outstandingPaise: Value(retailer.outstandingPaise),
        visitedToday: Value(retailer.visitedToday),
        totalTimeSpentSeconds: Value(retailer.totalTimeSpentSeconds),
        visitCountToday: Value(retailer.visitCountToday),
        latitude: Value(retailer.latitude),
        longitude: Value(retailer.longitude),
        classType: Value(retailer.classType),
        classSource: Value(retailer.classSource),
        routeId: Value(retailer.routeId),
        shopType: Value(retailer.shopType),
        gstin: Value(retailer.gstin),
        pincode: Value(retailer.pincode),
        landmark: Value(retailer.landmark),
        status: Value(retailer.status),
        createdByUserId: Value(retailer.createdByUserId),
        locationAccuracyMeters: Value(retailer.locationAccuracyMeters),
        syncStatus: Value(retailer.syncStatus),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateRetailerVisit(
    String retailerId, {
    required int totalTimeSpentSeconds,
    required int visitCountToday,
    required bool visitedToday,
  }) async {
    await (db.update(db.retailers)..where((tbl) => tbl.id.equals(retailerId)))
        .write(
          RetailersCompanion(
            totalTimeSpentSeconds: Value(totalTimeSpentSeconds),
            visitCountToday: Value(visitCountToday),
            visitedToday: Value(visitedToday),
          ),
        );
  }

  Future<RetailerEntry?> getRetailerById(String id) async {
    return (db.select(db.retailers)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> updateRetailerClassAndLimit(
    String retailerId, {
    required String newClass,
    required int creditLimitPaise,
    String? status,
  }) async {
    final companion = RetailersCompanion(
      classType: Value(newClass),
      creditLimitPaise: Value(creditLimitPaise),
      status: status != null ? Value(status) : const Value.absent(),
    );
    await (db.update(db.retailers)..where((tbl) => tbl.id.equals(retailerId)))
        .write(companion);
  }

  // Routes & Route Stops
  Future<void> insertRoute(RouteEntry entry) async {
    await db.into(db.routes).insertOnConflictUpdate(entry);
  }

  Future<List<RouteEntry>> getAllRoutes() async {
    return (db.select(db.routes)..where((tbl) => tbl.isActive.equals(true))).get();
  }

  Future<List<RouteStopEntry>> getRouteStops(String routeId) async {
    return (db.select(db.routeStops)
          ..where((tbl) => tbl.routeId.equals(routeId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.stopSequence)]))
        .get();
  }

  Future<void> addRouteStop({required String routeId, required String retailerId}) async {
    final existingStops = await getRouteStops(routeId);
    final nextSeq = existingStops.isEmpty ? 1 : (existingStops.last.stopSequence + 1);
    await db.into(db.routeStops).insertOnConflictUpdate(
      RouteStopEntry(
        id: 'stop_${DateTime.now().millisecondsSinceEpoch}_$nextSeq',
        routeId: routeId,
        retailerId: retailerId,
        stopSequence: nextSeq,
        createdAt: DateTime.now(),
      ),
    );
  }

  // Class Settings
  Future<List<ClassSettingEntry>> getAllClassSettings() async {
    return db.select(db.classSettings).get();
  }

  Future<ClassSettingEntry?> getClassSetting(String className) async {
    return (db.select(db.classSettings)..where((tbl) => tbl.className.equals(className))).getSingleOrNull();
  }

  Future<void> saveClassSetting(ClassSettingsCompanion companion) async {
    await db.into(db.classSettings).insertOnConflictUpdate(companion);
  }

  Future<void> seedDefaultClassSettingsIfEmpty() async {
    final existing = await db.select(db.classSettings).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    await db.transaction(() async {
      final defaults = [
        ClassSettingsCompanion(
          className: const Value('A'),
          defaultCreditLimitPaise: const Value(5000000), // ₹50,000
          creditDays: const Value(14),
          visitFrequencyDays: const Value(1),
          updatedAt: Value(now),
        ),
        ClassSettingsCompanion(
          className: const Value('B'),
          defaultCreditLimitPaise: const Value(2500000), // ₹25,000
          creditDays: const Value(7),
          visitFrequencyDays: const Value(2),
          updatedAt: Value(now),
        ),
        ClassSettingsCompanion(
          className: const Value('C'),
          defaultCreditLimitPaise: const Value(1000000), // ₹10,000
          creditDays: const Value(3),
          visitFrequencyDays: const Value(3),
          updatedAt: Value(now),
        ),
        ClassSettingsCompanion(
          className: const Value('D'),
          defaultCreditLimitPaise: const Value(0),
          creditDays: const Value(0),
          visitFrequencyDays: const Value(7),
          updatedAt: Value(now),
        ),
        ClassSettingsCompanion(
          className: const Value('NEW'),
          defaultCreditLimitPaise: const Value(0),
          creditDays: const Value(0),
          visitFrequencyDays: const Value(1),
          updatedAt: Value(now),
        ),
      ];

      for (var d in defaults) {
        await db.into(db.classSettings).insertOnConflictUpdate(d);
      }
    });
  }

  // Pre-seed data on initial installation
  Future<void> seedIfEmpty(
    List<ProductItem> seedProducts,
    List<RetailerShop> seedRetailers,
  ) async {
    final productCount = await db.select(db.products).get();
    if (productCount.isNotEmpty) return;

    await db.transaction(() async {
      for (final p in seedProducts) {
        await db.into(db.products).insert(
          ProductsCompanion(
            id: Value(p.id),
            name: Value(p.name),
            hindiName: Value(p.hindiName),
            category: Value(p.category),
            mrpRupees: Value(p.mrpRupees),
            piecePricePaise: Value(p.piecePricePaise),
            stripQty: Value(p.stripQty),
            boxQty: Value(p.boxQty),
            gstRate: Value(p.gstRate),
            badge: Value(p.badge),
            imageUrl: Value(p.imageUrl),
            isArchived: const Value(false),
            createdAt: Value(DateTime.now()),
          ),
        );
        await db.into(db.inventorySnapshots).insert(
          InventorySnapshotsCompanion(
            productId: Value(p.id),
            godownCartons: Value(p.godownStockBoxes),
            godownLoosePieces: const Value(0),
            carCartons: Value(p.carStockBoxes),
            carLoosePieces: const Value(0),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // Record OPENING_BALANCE movement in the same atomic transaction
        // Uses deterministic ID & checks existing to ensure complete idempotency
        final totalOpeningCartons = p.godownStockBoxes + p.carStockBoxes;
        if (totalOpeningCartons > 0) {
          final existingOpening = await (db.select(db.inventoryMovements)
                ..where((tbl) =>
                    tbl.productId.equals(p.id) &
                    tbl.movementType.equals('OPENING_BALANCE')))
              .getSingleOrNull();

          if (existingOpening == null) {
            await db.into(db.inventoryMovements).insert(
              InventoryMovementsCompanion(
                id: Value('mov_opening_${p.id}'),
                productId: Value(p.id),
                movementType: const Value('OPENING_BALANCE'),
                cartonDelta: Value(totalOpeningCartons),
                loosePieceDelta: const Value(0),
                reason: const Value('Initial opening inventory stock'),
                createdAt: Value(DateTime.now()),
              ),
            );
          }
        }
      }

      for (final r in seedRetailers) {
        await db.into(db.retailers).insert(
          RetailersCompanion(
            id: Value(r.id),
            name: Value(r.name),
            ownerName: Value(r.ownerName),
            phone: Value(r.phone),
            address: Value(r.address),
            area: Value(r.area),
            creditLimitPaise: Value(r.creditLimitPaise),
            outstandingPaise: Value(r.outstandingPaise),
            visitedToday: Value(r.visitedToday),
            totalTimeSpentSeconds: Value(r.totalTimeSpentSeconds),
            visitCountToday: Value(r.visitCountToday),
            latitude: Value(r.latitude),
            longitude: Value(r.longitude),
            classType: Value(r.classType),
            classSource: Value(r.classSource),
            routeId: Value(r.routeId),
            shopType: Value(r.shopType),
            gstin: Value(r.gstin),
            pincode: Value(r.pincode),
            landmark: Value(r.landmark),
            status: Value(r.status),
            createdByUserId: Value(r.createdByUserId),
            locationAccuracyMeters: Value(r.locationAccuracyMeters),
            syncStatus: Value(r.syncStatus),
            createdAt: Value(DateTime.now()),
          ),
        );
      }

      await db.into(db.databaseMetadata).insert(
        DatabaseMetadataCompanion(
          key: const Value('schema_initialized'),
          value: const Value('true'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // Warehouse Hubs
  Future<List<WarehouseHub>> getAllWarehouseHubs() async {
    final rows = await db.select(db.warehouseHubs).get();
    return rows
        .map(
          (w) => WarehouseHub(
            id: w.id,
            name: w.name,
            code: w.code,
            address: w.address,
            latitude: w.latitude,
            longitude: w.longitude,
            capacityBoxes: w.capacityBoxes,
            activeStaffCount: w.activeStaffCount,
          ),
        )
        .toList();
  }

  Future<void> upsertWarehouseHub(WarehouseHub hub) async {
    await db.into(db.warehouseHubs).insertOnConflictUpdate(
      WarehouseHubsCompanion(
        id: Value(hub.id),
        name: Value(hub.name),
        code: Value(hub.code),
        address: Value(hub.address),
        latitude: Value(hub.latitude),
        longitude: Value(hub.longitude),
        capacityBoxes: Value(hub.capacityBoxes),
        activeStaffCount: Value(hub.activeStaffCount),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> seedWarehouseHubsIfEmpty(List<WarehouseHub> seedHubs) async {
    final count = await db.select(db.warehouseHubs).get();
    if (count.isNotEmpty) return;
    await db.transaction(() async {
      for (final h in seedHubs) {
        await db.into(db.warehouseHubs).insert(
          WarehouseHubsCompanion(
            id: Value(h.id),
            name: Value(h.name),
            code: Value(h.code),
            address: Value(h.address),
            latitude: Value(h.latitude),
            longitude: Value(h.longitude),
            capacityBoxes: Value(h.capacityBoxes),
            activeStaffCount: Value(h.activeStaffCount),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}
