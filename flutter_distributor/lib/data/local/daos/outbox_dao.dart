import 'package:drift/drift.dart';
import '../app_database.dart';

part 'outbox_dao.g.dart';

/// Data Access Object for local outbox operations.
///
/// CRITICAL ARCHITECTURAL CONSTRAINTS:
/// 1. Every query must strictly filter by [organizationId] and [userId]
///    to prevent cross-user leakage in the application layer.
/// 2. Atomic dual-writes: [insertMutationAtomic] executes inside a SQLite
///    transaction so that business intent and outbox rows either both commit
///    or both roll back.
/// 3. Zero network calls or background workers reside in this DAO.
@DriftAccessor(tables: [OutboxMutations])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  final AppDatabase db;

  OutboxDao(this.db) : super(db);

  /// Atomically inserts an outbox mutation and optionally executes a linked
  /// local business transaction (e.g. updating local inventory or order records).
  ///
  /// If either the outbox insert or the [businessOperation] throws, the entire
  /// transaction rolls back, leaving zero partial state.
  Future<void> insertMutationAtomic({
    required OutboxMutationsCompanion mutation,
    Future<void> Function()? businessOperation,
  }) async {
    return db.transaction(() async {
      await into(db.outboxMutations).insert(mutation);
      if (businessOperation != null) {
        await businessOperation();
      }
    });
  }

  /// Retrieves all pending or retryable mutations strictly scoped to the active
  /// [organizationId] and [userId], ordered deterministically by [sequenceOrder],
  /// [createdAtEpochMs], and stable mutation UUID [id] ascending.
  Future<List<OutboxMutationEntry>> getPendingMutations({
    required String organizationId,
    required String userId,
  }) async {
    final query = select(db.outboxMutations)
      ..where((tbl) =>
          tbl.organizationId.equals(organizationId) &
          tbl.userId.equals(userId) &
          (tbl.syncStatus.equals('PENDING') |
              tbl.syncStatus.equals('RETRYABLE_FAILURE')))
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.sequenceOrder),
        (tbl) => OrderingTerm.asc(tbl.createdAtEpochMs),
        (tbl) => OrderingTerm.asc(tbl.id),
      ]);
    return query.get();
  }

  /// Transactionally allocates sequence_order and inserts an order mutation atomically.
  /// Enforces that sequence calculation and insertion occur inside the exact same
  /// SQLite write lock, preventing race conditions and sequence collisions.
  Future<OutboxMutationEntry> insertOrderMutationAtomic({
    required String id,
    required String organizationId,
    required String userId,
    required String idempotencyKey,
    required String mutationType,
    required String payloadJson,
    required String provisionalBusinessId,
    required int createdAtEpochMs,
    Future<void> Function()? businessOperation,
  }) async {
    return db.transaction(() async {
      final maxExp = db.outboxMutations.sequenceOrder.max();
      final query = selectOnly(db.outboxMutations)
        ..addColumns([maxExp])
        ..where(db.outboxMutations.organizationId.equals(organizationId));
      final result = await query.getSingle();
      final nextSeq = (result.read(maxExp) ?? 0) + 1;

      final companion = OutboxMutationsCompanion.insert(
        id: id,
        organizationId: organizationId,
        userId: userId,
        idempotencyKey: idempotencyKey,
        mutationType: mutationType,
        payloadJson: payloadJson,
        sequenceOrder: nextSeq,
        provisionalBusinessId: Value(provisionalBusinessId),
        createdAtEpochMs: createdAtEpochMs,
      );

      await into(db.outboxMutations).insert(companion);

      if (businessOperation != null) {
        await businessOperation();
      }

      return (select(db.outboxMutations)..where((tbl) => tbl.id.equals(id)))
          .getSingle();
    });
  }

  /// Retrieves a specific mutation by its [id], enforcing ownership matching
  /// [organizationId] and [userId]. Returns null if not found or unauthorized.
  Future<OutboxMutationEntry?> getMutationById({
    required String id,
    required String organizationId,
    required String userId,
  }) async {
    final query = select(db.outboxMutations)
      ..where((tbl) =>
          tbl.id.equals(id) &
          tbl.organizationId.equals(organizationId) &
          tbl.userId.equals(userId));
    return query.getSingleOrNull();
  }

  /// Looks up a mutation by [idempotencyKey] across the table to detect duplicate keys.
  Future<OutboxMutationEntry?> getMutationByIdempotencyKey(
      String idempotencyKey) async {
    final query = select(db.outboxMutations)
      ..where((tbl) => tbl.idempotencyKey.equals(idempotencyKey));
    return query.getSingleOrNull();
  }

  /// Retrieves all pending mutations in the outbox.
  Future<List<OutboxMutationEntry>> getPendingQueue() async {
    final query = select(db.outboxMutations)
      ..where((tbl) =>
          tbl.syncStatus.equals('PENDING') |
          tbl.syncStatus.equals('RETRYABLE_FAILURE'))
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.sequenceOrder),
        (tbl) => OrderingTerm.asc(tbl.createdAtEpochMs),
      ]);
    return query.get();
  }

  /// Counts pending mutations strictly scoped to [organizationId] and [userId].
  Future<int> countPending({
    required String organizationId,
    required String userId,
  }) async {
    final countExp = db.outboxMutations.id.count();
    final query = selectOnly(db.outboxMutations)
      ..addColumns([countExp])
      ..where(db.outboxMutations.organizationId.equals(organizationId) &
          db.outboxMutations.userId.equals(userId) &
          (db.outboxMutations.syncStatus.equals('PENDING') |
              db.outboxMutations.syncStatus.equals('RETRYABLE_FAILURE')));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Diagnostic/admin counter across all users (for quarantine and device diagnostics).
  Future<int> countAllPendingAcrossUsers() async {
    final countExp = db.outboxMutations.id.count();
    final query = selectOnly(db.outboxMutations)
      ..addColumns([countExp])
      ..where(db.outboxMutations.syncStatus.equals('PENDING') |
          db.outboxMutations.syncStatus.equals('RETRYABLE_FAILURE'));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Computes the next monotonic sequence order for an organization.
  Future<int> getNextSequenceOrder(String organizationId) async {
    final maxExp = db.outboxMutations.sequenceOrder.max();
    final query = selectOnly(db.outboxMutations)
      ..addColumns([maxExp])
      ..where(db.outboxMutations.organizationId.equals(organizationId));
    final result = await query.getSingle();
    final maxVal = result.read(maxExp);
    return (maxVal ?? 0) + 1;
  }

  /// Non-destructive forward quarantine mechanism.
  ///
  /// Rather than dropping the outbox table on rollback or schema conflict,
  /// this renames the table to a timestamped quarantine table, guaranteeing
  /// that pending user intent is NEVER permanently destroyed.
  Future<void> quarantineOutboxTable(String reason) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final quarantineName = 'outbox_mutations_quarantine_$timestamp';
    await db.customStatement('ALTER TABLE outbox_mutations RENAME TO $quarantineName;');
    // Record quarantine metadata
    await db.into(db.databaseMetadata).insertOnConflictUpdate(
          DatabaseMetadataCompanion(
            key: Value('outbox_quarantine_$timestamp'),
            value: Value('Quarantined at $timestamp. Reason: $reason'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Updates outbox mutation to SYNCED upon authentic server HTTP 200 acknowledgment.
  Future<void> markSynced({
    required String id,
    required int syncedAtEpochMs,
  }) async {
    await (update(db.outboxMutations)..where((tbl) => tbl.id.equals(id))).write(
      OutboxMutationsCompanion(
        syncStatus: const Value('SYNCED'),
        syncedAtEpochMs: Value(syncedAtEpochMs),
      ),
    );
  }

  /// Updates outbox mutation to FAILED_PERMANENT upon HTTP 409 conflict or unrecoverable error.
  Future<void> markFailedPermanent({
    required String id,
    required String errorCode,
  }) async {
    await (update(db.outboxMutations)..where((tbl) => tbl.id.equals(id))).write(
      OutboxMutationsCompanion(
        syncStatus: const Value('FAILED_PERMANENT'),
        lastErrorCode: Value(errorCode),
      ),
    );
  }

  /// Records retryable failure (network outage/timeout) with exponential backoff timestamp.
  Future<void> markRetryableFailure({
    required String id,
    required String errorCode,
    required int nextRetryAtMs,
  }) async {
    final existing = await (select(db.outboxMutations)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    final newAttempts = (existing?.attemptCount ?? 0) + 1;
    await (update(db.outboxMutations)..where((tbl) => tbl.id.equals(id))).write(
      OutboxMutationsCompanion(
        syncStatus: const Value('RETRYABLE_FAILURE'),
        attemptCount: Value(newAttempts),
        lastErrorCode: Value(errorCode),
        nextRetryAtMs: Value(nextRetryAtMs),
      ),
    );
  }

  /// Retrieves all mutations requiring user attention (permanently failed or server-rejected).
  Future<List<OutboxMutationEntry>> getFailedMutations() async {
    final query = select(db.outboxMutations)
      ..where((tbl) => tbl.syncStatus.equals('FAILED_PERMANENT'))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.createdAtEpochMs),
      ]);
    return query.get();
  }

  /// Cancels and removes a failed mutation from the outbox queue.
  Future<void> cancelMutation(String id) async {
    await (delete(db.outboxMutations)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Resets a failed mutation back to PENDING so the user can re-try sync.
  Future<void> resetFailedToPending(String id) async {
    await (update(db.outboxMutations)..where((tbl) => tbl.id.equals(id))).write(
      const OutboxMutationsCompanion(
        syncStatus: Value('PENDING'),
        attemptCount: Value(0),
        nextRetryAtMs: Value(null),
      ),
    );
  }

  /// Transactionally rewrites provisional business IDs upon server 200 acceptance.
  ///
  /// Updates the outbox mutation entry, replaces matching provisional references in
  /// pending dependent outbox mutation payloads, and updates matching local retailer records.
  Future<void> rewriteProvisionalId({
    required String provisionalId,
    required String serverBusinessId,
    required String organizationId,
  }) async {
    await transaction(() async {
      // 1. Update the mutation's own provisional record
      await (update(db.outboxMutations)
            ..where((tbl) => tbl.provisionalBusinessId.equals(provisionalId)))
          .write(OutboxMutationsCompanion(
        provisionalBusinessId: Value(serverBusinessId),
      ));

      // 2. Rewrite dependent references in payloadJson of pending mutations
      final pending = await (select(db.outboxMutations)
            ..where((tbl) =>
                tbl.organizationId.equals(organizationId) &
                (tbl.syncStatus.equals('PENDING') | tbl.syncStatus.equals('RETRYABLE_FAILURE'))))
          .get();

      for (final m in pending) {
        if (m.payloadJson.contains(provisionalId)) {
          final updatedPayloadJson = m.payloadJson.replaceAll(provisionalId, serverBusinessId);
          await (update(db.outboxMutations)..where((tbl) => tbl.id.equals(m.id))).write(
            OutboxMutationsCompanion(
              payloadJson: Value(updatedPayloadJson),
            ),
          );
        }
      }

      // 3. Update local retailers record if applicable
      await db.customStatement(
        'UPDATE retailers SET id = ? WHERE id = ?;',
        [serverBusinessId, provisionalId],
      );
    });
  }
}
