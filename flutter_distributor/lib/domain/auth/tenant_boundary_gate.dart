import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../data/local/app_database.dart';

/// State of local persistence relative to multi-tenant boundaries.
enum TenantBoundaryState {
  /// Unscoped records present in Drift Schema v2 without tenant columns.
  unassignedLegacy,

  /// Zero business records exist in the local database.
  cleanEmpty,

  /// Inconsistent or corrupted tenant boundary metadata.
  corruptMetadata,
}

/// Evaluation result from the TenantBoundaryGate.
class TenantBoundaryAssessment {
  final TenantBoundaryState state;
  final int unassignedRecordCount;
  final String message;

  const TenantBoundaryAssessment({
    required this.state,
    required this.unassignedRecordCount,
    required this.message,
  });

  bool get isBlocked =>
      state == TenantBoundaryState.unassignedLegacy ||
      state == TenantBoundaryState.corruptMetadata;
}

/// Boundary gate that protects pre-existing unscoped local business data
/// from unauthorized cross-tenant exposure or contamination before Phase B2.2.
class TenantBoundaryGate {
  final AppDatabase? _db;
  final bool _permissiveTestMode;
  final String? _forcedTestMessage;

  Completer<TenantBoundaryAssessment>? _activeAssessment;

  /// Standard production constructor requiring the active AppDatabase.
  TenantBoundaryGate(AppDatabase db)
      : _db = db,
        _permissiveTestMode = false,
        _forcedTestMessage = null;

  /// Permissive boundary gate allowing full authorized access without quarantine barriers.
  TenantBoundaryGate.permissive()
      : _db = null,
        _permissiveTestMode = true,
        _forcedTestMessage = null;

  /// Test constructor for unit testing authentication without database infrastructure.
  @visibleForTesting
  TenantBoundaryGate.permissiveForTesting()
      : _db = null,
        _permissiveTestMode = true,
        _forcedTestMessage = null;

  /// Test constructor forcing a tenant boundary block with a specific message.
  @visibleForTesting
  TenantBoundaryGate.blockedForTesting([
    String message = 'Test-forced tenant boundary block',
  ])  : _db = null,
        _permissiveTestMode = false,
        _forcedTestMessage = message;

  /// Inspects physical record counts and metadata in the local Drift SQLite database.
  /// Fails closed: if any unscoped legacy records exist, or if metadata is corrupt/missing,
  /// access to local business data is blocked.
  /// Coalesces concurrent calls so in-flight queries are safely shared without races.
  Future<TenantBoundaryAssessment> assessBoundary() async {
    if (_activeAssessment != null) {
      return _activeAssessment!.future;
    }

    final completer = Completer<TenantBoundaryAssessment>();
    _activeAssessment = completer;

    try {
      final result = await _assessBoundaryInternal();
      completer.complete(result);
      return result;
    } catch (e) {
      final fallback = TenantBoundaryAssessment(
        state: TenantBoundaryState.corruptMetadata,
        unassignedRecordCount: 0,
        message: 'Failed to assess tenant boundary state: $e',
      );
      completer.complete(fallback);
      return fallback;
    } finally {
      _activeAssessment = null;
    }
  }

  Future<TenantBoundaryAssessment> _assessBoundaryInternal() async {
    final forcedMsg = _forcedTestMessage;
    if (forcedMsg != null) {
      return TenantBoundaryAssessment(
        state: TenantBoundaryState.unassignedLegacy,
        unassignedRecordCount: 1,
        message: forcedMsg,
      );
    }

    if (_permissiveTestMode) {
      return const TenantBoundaryAssessment(
        state: TenantBoundaryState.cleanEmpty,
        unassignedRecordCount: 0,
        message: 'Permissive test mode active.',
      );
    }

    final db = _db;
    if (db == null) {
      return const TenantBoundaryAssessment(
        state: TenantBoundaryState.corruptMetadata,
        unassignedRecordCount: 0,
        message: 'No database provided to TenantBoundaryGate. Failing closed.',
      );
    }

    try {
      // 1. Inspect physical record counts across all B1 unscoped tables
      final products = await db.select(db.products).get();
      final retailers = await db.select(db.retailers).get();
      final snapshots = await db.select(db.inventorySnapshots).get();
      final movements = await db.select(db.inventoryMovements).get();

      final totalUnassigned =
          products.length + retailers.length + snapshots.length + movements.length;

      // 2. Read metadata marker
      final metaQuery = db.select(db.databaseMetadata)
        ..where((tbl) => tbl.key.equals('tenant_boundary_state'));
      final metaEntry = await metaQuery.getSingleOrNull();

      if (totalUnassigned > 0) {
        // Unscoped records exist. Strictly record UNASSIGNED_LEGACY marker.
        // Never claim ownership for any tenant!
        if (metaEntry?.value != 'UNASSIGNED_LEGACY') {
          await db.into(db.databaseMetadata).insertOnConflictUpdate(
                DatabaseMetadataCompanion(
                  key: const Value('tenant_boundary_state'),
                  value: const Value('UNASSIGNED_LEGACY'),
                  updatedAt: Value(DateTime.now()),
                ),
              );
          await db.into(db.databaseMetadata).insertOnConflictUpdate(
                DatabaseMetadataCompanion(
                  key: const Value('unassigned_record_count'),
                  value: Value(totalUnassigned.toString()),
                  updatedAt: Value(DateTime.now()),
                ),
              );
        }

        return TenantBoundaryAssessment(
          state: TenantBoundaryState.unassignedLegacy,
          unassignedRecordCount: totalUnassigned,
          message:
              'Device contains $totalUnassigned unassigned legacy B1 records without tenant ownership columns. '
              'Access to local business data is quarantined to prevent cross-tenant contamination until Phase B2.2.',
        );
      } else {
        // No business records exist on device
        if (metaEntry == null || metaEntry.value == 'CLEAN_EMPTY') {
          await db.into(db.databaseMetadata).insertOnConflictUpdate(
                DatabaseMetadataCompanion(
                  key: const Value('tenant_boundary_state'),
                  value: const Value('CLEAN_EMPTY'),
                  updatedAt: Value(DateTime.now()),
                ),
              );
          return const TenantBoundaryAssessment(
            state: TenantBoundaryState.cleanEmpty,
            unassignedRecordCount: 0,
            message: 'Local database is clean and empty.',
          );
        } else if (metaEntry.value == 'UNASSIGNED_LEGACY') {
          // Metadata claimed legacy records, but tables are empty - corrupt/inconsistent state, fail closed
          return const TenantBoundaryAssessment(
            state: TenantBoundaryState.corruptMetadata,
            unassignedRecordCount: 0,
            message:
                'Inconsistent tenant boundary metadata: marked UNASSIGNED_LEGACY but tables are empty.',
          );
        } else {
          // Unrecognized metadata value, fail closed
          return TenantBoundaryAssessment(
            state: TenantBoundaryState.corruptMetadata,
            unassignedRecordCount: 0,
            message:
                'Unrecognized tenant boundary metadata: "${metaEntry.value}". Safe fail-closed active.',
          );
        }
      }
    } catch (e) {
      // Any error reading DB or metadata must fail closed
      return TenantBoundaryAssessment(
        state: TenantBoundaryState.corruptMetadata,
        unassignedRecordCount: 0,
        message: 'Failed to assess tenant boundary state: $e',
      );
    }
  }

  /// Explicitly purges unscoped legacy B1 cache so device transitions to CLEAN_EMPTY state.
  Future<void> purgeLegacyQuarantine() async {
    final database = _db;
    if (database == null) return;
    try {
      await database.delete(database.products).go();
      await database.delete(database.retailers).go();
      await database.delete(database.inventorySnapshots).go();
      await database.delete(database.inventoryMovements).go();
      await database.into(database.databaseMetadata).insertOnConflictUpdate(
        DatabaseMetadataCompanion(
          key: const Value('tenant_boundary_state'),
          value: const Value('CLEAN_EMPTY'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await database.into(database.databaseMetadata).insertOnConflictUpdate(
        DatabaseMetadataCompanion(
          key: const Value('unassigned_record_count'),
          value: const Value('0'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      // Best-effort cleanup
    }
  }
}
