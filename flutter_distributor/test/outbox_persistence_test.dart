import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/daos/outbox_dao.dart';
import 'package:lala_distributor/domain/outbox/outbox_models.dart';

/// Test HTTP override that fails immediately if any network socket or client is created.
class ZeroNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw AssertionError('FATAL INVARIANT VIOLATION: Outbox code attempted a network request!');
  }
}

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    HttpOverrides.global = ZeroNetworkHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  group('RouteFlow Phase O1 — Durable Local Outbox Persistence Tests', () {
    late AppDatabase db;
    late OutboxDao outboxDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      outboxDao = OutboxDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // Criterion 1 & 2: Schema v2 to v3 Migration & B1 Data Integrity
    // -------------------------------------------------------------------------
    test(
        'Exit Criteria 1 & 2: Migration from v2 to v3 preserves existing B1 master data',
        () async {
      // 1. Setup a fresh in-memory database simulating Schema v2
      // We manually construct a database at v2 by creating tables up to v2
      final rawDb = AppDatabase(NativeDatabase.memory());
      final migrator = rawDb.createMigrator();

      // Create v1 tables
      await migrator.createTable(rawDb.products);
      await migrator.createTable(rawDb.retailers);
      await migrator.createTable(rawDb.inventorySnapshots);
      await migrator.createTable(rawDb.inventoryMovements);
      await migrator.createTable(rawDb.databaseMetadata);

      // Seed baseline B1 records
      final now = DateTime.now();
      await rawDb.into(rawDb.products).insert(
            ProductEntry(
              id: 'PROD-001',
              name: 'Jaipur Kurkure Masala',
              hindiName: 'जयपुर कुरकुरे',
              category: 'Snacks',
              mrpRupees: 20.0,
              mrpPaise: 2000,
              piecePricePaise: 1600,
              stripQty: 10,
              boxQty: 50,
              gstRate: 18.0,
              badge: 'POPULAR',
              imageUrl: '',
              isArchived: false,
              createdAt: now,
            ),
          );

      await rawDb.into(rawDb.retailers).insert(
            RetailerEntry(
              id: 'RET-001',
              name: 'Kripa Kirana Store',
              ownerName: 'Ramesh Sharma',
              phone: '9829012345',
              address: 'Shop 12, Johari Bazar',
              area: 'Johari Bazar',
              creditLimitPaise: 5000000,
              outstandingPaise: 125000,
              visitedToday: false,
              totalTimeSpentSeconds: 0,
              visitCountToday: 0,
              classType: 'NEW',
              classSource: 'MANUAL',
              shopType: 'KIRANA',
              status: 'ACTIVE',
              syncStatus: 'PENDING',
              createdAt: now,
            ),
          );

      await rawDb.into(rawDb.inventorySnapshots).insert(
            InventorySnapshotEntry(
              productId: 'PROD-001',
              godownCartons: 100,
              godownLoosePieces: 25,
              carCartons: 10,
              carLoosePieces: 5,
              damagedCartons: 0,
              damagedLoosePieces: 0,
              updatedAt: now,
            ),
          );

      await rawDb.into(rawDb.inventoryMovements).insert(
            InventoryMovementEntry(
              id: 'MOV-001',
              productId: 'PROD-001',
              movementType: 'INWARD',
              cartonDelta: 100,
              loosePieceDelta: 25,
              reason: 'Initial Inward',
              createdAt: now,
            ),
          );

      // 2. Execute migration from v2 to v3
      await rawDb.migration.onUpgrade(migrator, 2, 3);

      // 3. Verify B1 master data is completely intact
      final products = await rawDb.select(rawDb.products).get();
      expect(products.length, equals(1));
      expect(products.first.id, equals('PROD-001'));
      expect(products.first.name, equals('Jaipur Kurkure Masala'));
      expect(products.first.isArchived, isFalse);

      final retailers = await rawDb.select(rawDb.retailers).get();
      expect(retailers.length, equals(1));
      expect(retailers.first.id, equals('RET-001'));
      expect(retailers.first.outstandingPaise, equals(125000));

      final snapshots = await rawDb.select(rawDb.inventorySnapshots).get();
      expect(snapshots.length, equals(1));
      expect(snapshots.first.godownCartons, equals(100));

      final movements = await rawDb.select(rawDb.inventoryMovements).get();
      expect(movements.length, equals(1));
      expect(movements.first.id, equals('MOV-001'));

      // 4. Verify outbox_mutations table and index now exist and are usable
      final outboxTableCheck = await rawDb.customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='table' AND name='outbox_mutations';",
      ).getSingle();
      expect(outboxTableCheck.read<int>('count'), equals(1));

      final indexCheck = await rawDb.customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE type='index' AND name='idx_outbox_queue';",
      ).getSingle();
      expect(indexCheck.read<int>('count'), equals(1));

      await rawDb.close();
    });

    // -------------------------------------------------------------------------
    // Criterion 3: Atomic Dual-Write (Business Mutation + Outbox Record)
    // -------------------------------------------------------------------------
    test(
        'Exit Criterion 3: insertMutationAtomic successfully commits business update and outbox record together',
        () async {
      // Seed a retailer with 50,000 paise outstanding
      final now = DateTime.now();
      await db.into(db.retailers).insert(
            RetailerEntry(
              id: 'RET-ATOMIC',
              name: 'Atomic Kirana',
              ownerName: 'Suresh Kumar',
              phone: '9829099999',
              address: 'Mansarovar',
              area: 'Mansarovar',
              creditLimitPaise: 2000000,
              outstandingPaise: 50000,
              visitedToday: false,
              totalTimeSpentSeconds: 0,
              visitCountToday: 0,
              classType: 'NEW',
              classSource: 'MANUAL',
              shopType: 'KIRANA',
              status: 'ACTIVE',
              syncStatus: 'PENDING',
              createdAt: now,
            ),
          );

      final payload = CreateOrderMutationPayload(
        provisionalOrderId: 'ord_prov_001',
        retailerId: 'RET-ATOMIC',
        totalAmountPaise: 25000,
        paymentMode: 'COD',
        items: const [
          OrderItemPayload(
            productId: 'PROD-001',
            quantity: 2,
            pricePaiseAtTime: 12500,
          ),
        ],
        createdAtEpochMs: now.millisecondsSinceEpoch,
      );

      // Perform atomic dual-write: update retailer outstanding balance + queue outbox mutation
      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_atomic_1',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_uuid_001',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: payload.toCanonicalJson(),
          sequenceOrder: 1,
          provisionalBusinessId: const drift.Value('ord_prov_001'),
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
        businessOperation: () async {
          // Increase retailer outstanding balance locally
          await (db.update(db.retailers)..where((r) => r.id.equals('RET-ATOMIC'))).write(
            const RetailersCompanion(
              outstandingPaise: drift.Value(75000), // 50,000 + 25,000
            ),
          );
        },
      );

      // Assert outbox record was written
      final pending = await outboxDao.getPendingMutations(
        organizationId: 'org_alpha',
        userId: 'usr_alice',
      );
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('out_atomic_1'));
      expect(pending.first.idempotencyKey, equals('idemp_uuid_001'));
      expect(pending.first.syncStatus, equals('PENDING'));
      expect(pending.first.provisionalBusinessId, equals('ord_prov_001'));

      // Assert retailer balance was updated
      final updatedRetailer = await (db.select(db.retailers)
            ..where((r) => r.id.equals('RET-ATOMIC')))
          .getSingle();
      expect(updatedRetailer.outstandingPaise, equals(75000));
    });

    // -------------------------------------------------------------------------
    // Criterion 4: Atomic Rollback on Failure (All-or-Nothing)
    // -------------------------------------------------------------------------
    test(
        'Exit Criterion 4: Failed transaction rolls back both business operation and outbox record',
        () async {
      final now = DateTime.now();
      await db.into(db.retailers).insert(
            RetailerEntry(
              id: 'RET-FAILSAFE',
              name: 'Failsafe Kirana',
              ownerName: 'Mohan Lal',
              phone: '9829011111',
              address: 'Vaishali Nagar',
              area: 'Vaishali Nagar',
              creditLimitPaise: 2000000,
              outstandingPaise: 40000,
              visitedToday: false,
              totalTimeSpentSeconds: 0,
              visitCountToday: 0,
              classType: 'NEW',
              classSource: 'MANUAL',
              shopType: 'KIRANA',
              status: 'ACTIVE',
              syncStatus: 'PENDING',
              createdAt: now,
            ),
          );

      bool caughtException = false;
      try {
        await outboxDao.insertMutationAtomic(
          mutation: OutboxMutationsCompanion.insert(
            id: 'out_fail_1',
            organizationId: 'org_alpha',
            userId: 'usr_alice',
            idempotencyKey: 'idemp_fail_001',
            mutationType: MutationType.createOrder.toDbValue(),
            payloadJson: '{"test": "rollback"}',
            sequenceOrder: 2,
            createdAtEpochMs: now.millisecondsSinceEpoch,
          ),
          businessOperation: () async {
            // Modify retailer balance
            await (db.update(db.retailers)..where((r) => r.id.equals('RET-FAILSAFE'))).write(
              const RetailersCompanion(
                outstandingPaise: drift.Value(999999),
              ),
            );
            // Simulate sudden crash / validation abort mid-transaction
            throw Exception('SIMULATED_TRANSACTION_FAILURE');
          },
        );
      } catch (e) {
        caughtException = true;
      }

      expect(caughtException, isTrue);

      // Verify outbox mutation was completely rolled back (0 rows)
      final pending = await outboxDao.getPendingMutations(
        organizationId: 'org_alpha',
        userId: 'usr_alice',
      );
      expect(pending.where((m) => m.id == 'out_fail_1').isEmpty, isTrue);

      // Verify retailer balance remained completely unchanged at 40,000 (NOT 999,999)
      final retailer = await (db.select(db.retailers)
            ..where((r) => r.id.equals('RET-FAILSAFE')))
          .getSingle();
      expect(retailer.outstandingPaise, equals(40000));
    });

    // -------------------------------------------------------------------------
    // Criterion 5: Duplicate Key Rejection (ID & Idempotency Key)
    // -------------------------------------------------------------------------
    test(
        'Exit Criterion 5: Duplicate mutation IDs and duplicate idempotency keys are rejected',
        () async {
      final now = DateTime.now();

      // Insert initial mutation
      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_dup_1',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_unique_key_100',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: '{}',
          sequenceOrder: 1,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      // Attempt 1: Duplicate primary key `id`
      bool duplicateIdCaught = false;
      try {
        await outboxDao.insertMutationAtomic(
          mutation: OutboxMutationsCompanion.insert(
            id: 'out_dup_1', // Duplicate ID
            organizationId: 'org_alpha',
            userId: 'usr_alice',
            idempotencyKey: 'idemp_different_key',
            mutationType: MutationType.createOrder.toDbValue(),
            payloadJson: '{}',
            sequenceOrder: 2,
            createdAtEpochMs: now.millisecondsSinceEpoch,
          ),
        );
      } catch (_) {
        duplicateIdCaught = true;
      }
      expect(duplicateIdCaught, isTrue);

      // Attempt 2: Duplicate `idempotencyKey` with different ID
      bool duplicateKeyCaught = false;
      try {
        await outboxDao.insertMutationAtomic(
          mutation: OutboxMutationsCompanion.insert(
            id: 'out_dup_2', // Different ID
            organizationId: 'org_alpha',
            userId: 'usr_alice',
            idempotencyKey: 'idemp_unique_key_100', // DUPLICATE idempotencyKey
            mutationType: MutationType.createOrder.toDbValue(),
            payloadJson: '{}',
            sequenceOrder: 3,
            createdAtEpochMs: now.millisecondsSinceEpoch,
          ),
        );
      } catch (_) {
        duplicateKeyCaught = true;
      }
      expect(duplicateKeyCaught, isTrue);

      // Verify only the original single mutation exists
      final allPending = await outboxDao.getPendingMutations(
        organizationId: 'org_alpha',
        userId: 'usr_alice',
      );
      expect(allPending.length, equals(1));
      expect(allPending.first.id, equals('out_dup_1'));
    });

    // -------------------------------------------------------------------------
    // Criterion 6: Database Close & Reopen Durability
    // -------------------------------------------------------------------------
    test(
        'Exit Criterion 6: Queued outbox records survive database close and reopen',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('routeflow_durability_test');
      final dbPath = p.join(tempDir.path, 'durability_test.sqlite');
      final file = File(dbPath);

      // 1. Open persistent SQLite file database
      AppDatabase persistentDb = AppDatabase(NativeDatabase(file));
      OutboxDao persistentDao = OutboxDao(persistentDb);

      final now = DateTime.now();
      await persistentDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_persist_1',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_persist_1',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: jsonEncode({'order': 'Kurkure 5 cartons'}),
          sequenceOrder: 1,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      await persistentDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_persist_2',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_persist_2',
          mutationType: MutationType.recordCollection.toDbValue(),
          payloadJson: jsonEncode({'cashPaise': 50000}),
          sequenceOrder: 2,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      // 2. Explicitly close the database connection
      await persistentDb.close();

      // 3. Re-open database from the exact same disk file
      persistentDb = AppDatabase(NativeDatabase(file));
      persistentDao = OutboxDao(persistentDb);

      // 4. Assert records survived completely
      final recovered = await persistentDao.getPendingMutations(
        organizationId: 'org_alpha',
        userId: 'usr_alice',
      );

      expect(recovered.length, equals(2));
      expect(recovered[0].id, equals('out_persist_1'));
      expect(recovered[0].idempotencyKey, equals('idemp_persist_1'));
      expect(recovered[0].payloadJson, contains('Kurkure 5 cartons'));
      expect(recovered[1].id, equals('out_persist_2'));
      expect(recovered[1].idempotencyKey, equals('idemp_persist_2'));
      expect(recovered[1].payloadJson, contains('50000'));

      await persistentDb.close();
      await tempDir.delete(recursive: true);
    });

    // -------------------------------------------------------------------------
    // Criterion 7: User & Organization Scoping (Zero Cross-User Query Leakage)
    // -------------------------------------------------------------------------
    test(
        'Exit Criterion 7: Queries strictly isolate outbox records by organizationId and userId',
        () async {
      final now = DateTime.now();

      // Alice queues 2 mutations in Org Alpha
      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_alice_alpha_1',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_a1',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: '{"user": "alice"}',
          sequenceOrder: 1,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );
      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_alice_alpha_2',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_a2',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: '{"user": "alice_2"}',
          sequenceOrder: 2,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      // Bob queues 1 mutation in Org Alpha
      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_bob_alpha_1',
          organizationId: 'org_alpha',
          userId: 'usr_bob',
          idempotencyKey: 'idemp_b1',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: '{"user": "bob"}',
          sequenceOrder: 3,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      // Alice queues 1 mutation in Org Beta
      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_alice_beta_1',
          organizationId: 'org_beta',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_ab1',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: '{"org": "beta"}',
          sequenceOrder: 1,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      // 1. Query as Alice in Org Alpha: must return EXACTLY Alice's 2 mutations for Alpha
      final aliceAlpha = await outboxDao.getPendingMutations(
        organizationId: 'org_alpha',
        userId: 'usr_alice',
      );
      expect(aliceAlpha.length, equals(2));
      expect(aliceAlpha.map((m) => m.id), containsAll(['out_alice_alpha_1', 'out_alice_alpha_2']));
      expect(await outboxDao.countPending(organizationId: 'org_alpha', userId: 'usr_alice'), equals(2));

      // 2. Query as Bob in Org Alpha: must return EXACTLY Bob's 1 mutation (Alice's are invisible)
      final bobAlpha = await outboxDao.getPendingMutations(
        organizationId: 'org_alpha',
        userId: 'usr_bob',
      );
      expect(bobAlpha.length, equals(1));
      expect(bobAlpha.first.id, equals('out_bob_alpha_1'));
      expect(await outboxDao.countPending(organizationId: 'org_alpha', userId: 'usr_bob'), equals(1));

      // 3. Query as Alice in Org Beta: returns strictly Beta records
      final aliceBeta = await outboxDao.getPendingMutations(
        organizationId: 'org_beta',
        userId: 'usr_alice',
      );
      expect(aliceBeta.length, equals(1));
      expect(aliceBeta.first.id, equals('out_alice_beta_1'));

      // 4. Bob in Org Beta: returns 0 records
      final bobBeta = await outboxDao.getPendingMutations(
        organizationId: 'org_beta',
        userId: 'usr_bob',
      );
      expect(bobBeta.isEmpty, isTrue);

      // 5. Total pending across all users is 4
      expect(await outboxDao.countAllPendingAcrossUsers(), equals(4));
    });

    // -------------------------------------------------------------------------
    // Criterion 8: Zero Network Calls Invariant
    // -------------------------------------------------------------------------
    test(
        'Exit Criterion 8: Outbox code initiates zero network requests during all operations',
        () async {
      // ZeroNetworkHttpOverrides is installed in setUpAll.
      // If any part of the outbox code calls HttpClient or initiates an HTTP socket,
      // it throws AssertionError immediately.
      final now = DateTime.now();

      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_zero_net_1',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_zero_net_1',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: '{"test": "offline"}',
          sequenceOrder: 1,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      final pending = await outboxDao.getPendingMutations(
        organizationId: 'org_alpha',
        userId: 'usr_alice',
      );
      expect(pending.isNotEmpty, isTrue);
      // Test completes successfully without triggering ZeroNetworkHttpOverrides.
    });

    // -------------------------------------------------------------------------
    // Forward Quarantine Strategy (Non-Destructive Rollback Invariant)
    // -------------------------------------------------------------------------
    test(
        'Non-destructive Forward Quarantine preserves records without DROP TABLE',
        () async {
      final now = DateTime.now();
      await outboxDao.insertMutationAtomic(
        mutation: OutboxMutationsCompanion.insert(
          id: 'out_quarantine_1',
          organizationId: 'org_alpha',
          userId: 'usr_alice',
          idempotencyKey: 'idemp_q1',
          mutationType: MutationType.createOrder.toDbValue(),
          payloadJson: '{"precious": "business_intent_data"}',
          sequenceOrder: 1,
          createdAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );

      // Execute forward quarantine
      await outboxDao.quarantineOutboxTable('Simulated rollback safety drill');

      // Verify that a quarantine table exists and contains the preserved record
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'outbox_mutations_quarantine_%';",
      ).get();
      expect(tables.isNotEmpty, isTrue);

      final quarantineTableName = tables.first.read<String>('name');
      final quarantinedRows = await db.customSelect(
        'SELECT id, payload_json FROM $quarantineTableName WHERE id = ?;',
        variables: [drift.Variable.withString('out_quarantine_1')],
      ).getSingle();

      expect(quarantinedRows.read<String>('id'), equals('out_quarantine_1'));
      expect(quarantinedRows.read<String>('payload_json'), contains('precious'));
    });
  });
}
