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

    final snapshotMap = {for (var s in snapshots) s.productId: s};

    return products.map((p) {
      final snap = snapshotMap[p.id];
      return ProductItem(
        id: p.id,
        name: p.name,
        hindiName: p.hindiName,
        category: p.category,
        mrpRupees: p.mrpRupees,
        piecePricePaise: p.piecePricePaise,
        stripQty: p.stripQty,
        boxQty: p.boxQty,
        gstRate: p.gstRate,
        godownStockBoxes: snap?.godownCartons ?? 0,
        carStockBoxes: snap?.carCartons ?? 0,
        badge: p.badge,
        imageUrl: p.imageUrl,
      );
    }).toList();
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
