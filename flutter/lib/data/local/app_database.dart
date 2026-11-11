import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'daos/outbox_dao.dart';

part 'app_database.g.dart';

@DataClassName('ProductEntry')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get hindiName => text()();
  TextColumn get category => text()();
  RealColumn get mrpRupees => real()();
  IntColumn get mrpPaise => integer().withDefault(const Constant(0))();
  IntColumn get piecePricePaise => integer()();
  IntColumn get stripQty => integer()();
  IntColumn get boxQty => integer()();
  RealColumn get gstRate => real().withDefault(const Constant(18.0))();
  TextColumn get badge => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().withDefault(const Constant(''))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RetailerEntry')
class Retailers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ownerName => text()();
  TextColumn get phone => text()();
  TextColumn get address => text()();
  TextColumn get area => text()();
  IntColumn get creditLimitPaise => integer()();
  IntColumn get outstandingPaise => integer()();
  BoolColumn get visitedToday => boolean().withDefault(const Constant(false))();
  IntColumn get totalTimeSpentSeconds =>
      integer().withDefault(const Constant(0))();
  IntColumn get visitCountToday => integer().withDefault(const Constant(0))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get classType => text().withDefault(const Constant('NEW'))();
  TextColumn get classSource => text().withDefault(const Constant('MANUAL'))();
  TextColumn get routeId => text().nullable()();
  TextColumn get shopType => text().withDefault(const Constant('KIRANA'))();
  TextColumn get gstin => text().nullable()();
  TextColumn get pincode => text().nullable()();
  TextColumn get landmark => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  TextColumn get createdByUserId => text().nullable()();
  RealColumn get locationAccuracyMeters => real().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InventorySnapshotEntry')
class InventorySnapshots extends Table {
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get godownCartons => integer().withDefault(const Constant(0))();
  IntColumn get godownLoosePieces => integer().withDefault(const Constant(0))();
  IntColumn get carCartons => integer().withDefault(const Constant(0))();
  IntColumn get carLoosePieces => integer().withDefault(const Constant(0))();
  IntColumn get damagedCartons => integer().withDefault(const Constant(0))();
  IntColumn get damagedLoosePieces => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}

@DataClassName('InventoryMovementEntry')
class InventoryMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get movementType =>
      text()(); // INWARD, TRANSFER_TO_CAR, OPEN_CARTON, DISPATCH, SALE, ADJUSTMENT, OPENING_BALANCE, WRITE_OFF, INWARD_REVERSAL
  IntColumn get cartonDelta => integer()();
  IntColumn get loosePieceDelta => integer()();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get locationId => text().nullable()();
  TextColumn get invoiceNumber => text().nullable()();
  TextColumn get batchNumber => text().nullable()();
  TextColumn get supplierName => text().nullable()();
  TextColumn get idempotencyKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DatabaseMetadataEntry')
class DatabaseMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('OutboxMutationEntry')
class OutboxMutations extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get userId => text()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get mutationType => text()();
  TextColumn get payloadJson => text()();
  IntColumn get sequenceOrder => integer()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('PENDING'))();
  TextColumn get provisionalBusinessId => text().nullable()();
  TextColumn get leaseToken => text().nullable()();
  IntColumn get leaseGeneration =>
      integer().withDefault(const Constant(0))();
  IntColumn get leaseExpiresAtMs => integer().nullable()();
  IntColumn get attemptCount =>
      integer().withDefault(const Constant(0))();
  TextColumn get lastErrorCode => text().nullable()();
  IntColumn get nextRetryAtMs => integer().nullable()();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get syncedAtEpochMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WarehouseHubEntry')
class WarehouseHubs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get address => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get capacityBoxes => integer().withDefault(const Constant(0))();
  IntColumn get activeStaffCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RouteEntry')
class Routes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get dayOfWeek => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RouteStopEntry')
class RouteStops extends Table {
  TextColumn get id => text()();
  TextColumn get routeId => text().references(Routes, #id)();
  TextColumn get retailerId => text().references(Retailers, #id)();
  IntColumn get stopSequence => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ClassSettingEntry')
class ClassSettings extends Table {
  TextColumn get className => text()();
  IntColumn get defaultCreditLimitPaise => integer()();
  IntColumn get creditDays => integer()();
  IntColumn get visitFrequencyDays => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {className};
}

@DataClassName('ProductUnitEntry')
class ProductUnits extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitName => text()();
  IntColumn get multiplierToBase => integer()();
  BoolColumn get isBaseUnit => boolean().withDefault(const Constant(false))();
  BoolColumn get allowLooseSale => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UnitPriceEntry')
class UnitPrices extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitName => text()();
  IntColumn get wholesalePricePaise => integer()();
  IntColumn get mrpPaise => integer()();
  IntColumn get minOrderQty => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocationEntry')
class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get locationType => text()(); // GODOWN, VAN, DAMAGED_QUARANTINE
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CartDraftEntry')
class CartDrafts extends Table {
  TextColumn get retailerId => text()();
  TextColumn get itemsJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {retailerId};
}

@DataClassName('VisitEntry')
class Visits extends Table {
  TextColumn get id => text()();
  TextColumn get retailerId => text().references(Retailers, #id)();
  TextColumn get userId => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get outcome => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'routidrow_clean.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [
    Products,
    Retailers,
    InventorySnapshots,
    InventoryMovements,
    DatabaseMetadata,
    OutboxMutations,
    WarehouseHubs,
    Routes,
    RouteStops,
    ClassSettings,
    ProductUnits,
    UnitPrices,
    Locations,
    CartDrafts,
    Visits,
  ],
  daos: [
    OutboxDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_outbox_queue ON outbox_mutations (organization_id, user_id, sync_status, next_retry_at_ms, sequence_order);',
        );
        await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_phone ON retailers (phone);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_gstin ON retailers (gstin);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_route_status ON retailers (route_id, status);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_products_cat_archived ON products (category, is_archived);');
        await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_route_stops_route_retailer ON route_stops (route_id, retailer_id);');
        await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_product_units_prod_unit ON product_units (product_id, unit_name);');
        await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_unit_prices_prod_unit ON unit_prices (product_id, unit_name);');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2 && to >= 2) {
          // Version 1 -> Version 2: Add isArchived column to products table
          await m.addColumn(products, products.isArchived);
        }
        if (from < 3 && to >= 3) {
          // Version 2 -> Version 3: Add additive OutboxMutations table
          await m.createTable(outboxMutations);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_outbox_queue ON outbox_mutations (organization_id, user_id, sync_status, next_retry_at_ms, sequence_order);',
          );
        }
        if (from < 4 && to >= 4) {
          // Version 3 -> Version 4: Add spatial coordinates to retailers and create WarehouseHubs table
          await m.addColumn(retailers, retailers.latitude);
          await m.addColumn(retailers, retailers.longitude);
          await m.createTable(warehouseHubs);
        }
        if (from < 5 && to >= 5) {
          // Version 4 -> Version 5: Add retailer classification, routes, packaging units, prices, locations, visits, drafts
          await m.addColumn(retailers, retailers.classType);
          await m.addColumn(retailers, retailers.classSource);
          await m.addColumn(retailers, retailers.routeId);
          await m.addColumn(retailers, retailers.shopType);
          await m.addColumn(retailers, retailers.gstin);
          await m.addColumn(retailers, retailers.pincode);
          await m.addColumn(retailers, retailers.landmark);
          await m.addColumn(retailers, retailers.status);
          await m.addColumn(retailers, retailers.createdByUserId);
          await m.addColumn(retailers, retailers.locationAccuracyMeters);
          await m.addColumn(retailers, retailers.syncStatus);

          await m.addColumn(inventorySnapshots, inventorySnapshots.damagedCartons);
          await m.addColumn(inventorySnapshots, inventorySnapshots.damagedLoosePieces);

          await m.addColumn(inventoryMovements, inventoryMovements.locationId);
          await m.addColumn(inventoryMovements, inventoryMovements.invoiceNumber);
          await m.addColumn(inventoryMovements, inventoryMovements.batchNumber);
          await m.addColumn(inventoryMovements, inventoryMovements.supplierName);
          await m.addColumn(inventoryMovements, inventoryMovements.idempotencyKey);

          await m.createTable(routes);
          await m.createTable(routeStops);
          await m.createTable(classSettings);
          await m.createTable(productUnits);
          await m.createTable(unitPrices);
          await m.createTable(locations);
          await m.createTable(cartDrafts);
          await m.createTable(visits);

          await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_phone ON retailers (phone);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_gstin ON retailers (gstin);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_route_status ON retailers (route_id, status);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_products_cat_archived ON products (category, is_archived);');
          await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_route_stops_route_retailer ON route_stops (route_id, retailer_id);');
          await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_product_units_prod_unit ON product_units (product_id, unit_name);');
          await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_unit_prices_prod_unit ON unit_prices (product_id, unit_name);');
        }
        if (from < 6 && to >= 6) {
          // Version 5 -> Version 6: Add mrp_paise to products and backfill from mrp_rupees
          await m.addColumn(products, products.mrpPaise);
          await customStatement('UPDATE products SET mrp_paise = CAST(ROUND(mrp_rupees * 100) AS INTEGER) WHERE mrp_paise = 0;');
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_outbox_org_seq ON outbox_mutations (organization_id, sequence_order);',
        );
      },
    );
  }
}
