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
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}

@DataClassName('InventoryMovementEntry')
class InventoryMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get movementType =>
      text()(); // INWARD, TRANSFER_TO_CAR, OPEN_CARTON, DISPATCH, SALE, ADJUSTMENT
  IntColumn get cartonDelta => integer()();
  IntColumn get loosePieceDelta => integer()();
  TextColumn get reason => text().withDefault(const Constant(''))();
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
  ],
  daos: [
    OutboxDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_outbox_queue ON outbox_mutations (organization_id, user_id, sync_status, next_retry_at_ms, sequence_order);',
        );
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
