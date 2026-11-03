import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/services/sync_worker.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('RouteFlow Phase C2 — Mobile Sync Worker & Outbox HTTP Wire Protocol', () {
    late AppDatabase db;
    const testOrgId = 'comp_1';
    const testUserId = 'usr_sales_101';
    const testBaseUrl = 'https://api.routeflow.in';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<OutboxMutationEntry> insertTestMutation({
      required String id,
      required int sequenceOrder,
      required String idempotencyKey,
      required String mutationType,
      required Map<String, dynamic> payload,
      String? provisionalId,
    }) async {
      return db.outboxDao.insertOrderMutationAtomic(
        id: id,
        organizationId: testOrgId,
        userId: testUserId,
        idempotencyKey: idempotencyKey,
        mutationType: mutationType,
        payloadJson: jsonEncode(payload),
        provisionalBusinessId: provisionalId ?? 'PROV-$id',
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
    }

    test('1. Outbox sends mutations in strict sequence_order with Bearer auth', () async {
      await insertTestMutation(
        id: 'mut_shop_01',
        sequenceOrder: 1,
        idempotencyKey: 'idem_shop_01',
        mutationType: 'CREATE_RETAILER',
        payload: {'shopName': 'Balaji Kirana', 'phone': '9829012345'},
      );

      await insertTestMutation(
        id: 'mut_order_02',
        sequenceOrder: 2,
        idempotencyKey: 'idem_order_02',
        mutationType: 'CREATE_ORDER',
        payload: {'retailerId': 'PROV-mut_shop_01', 'totalPaise': 50000},
      );

      bool inspectedPayload = false;

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), '$testBaseUrl/sync/push');
        expect(request.headers['Authorization'], 'Bearer test_valid_access_token');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['organizationId'], testOrgId);
        expect(body['userId'], testUserId);

        final mutations = body['mutations'] as List<dynamic>;
        expect(mutations.length, 2);
        // Strict FIFO ordering verification
        expect(mutations[0]['sequenceOrder'], 1);
        expect(mutations[0]['mutationId'], 'mut_shop_01');
        expect(mutations[1]['sequenceOrder'], 2);
        expect(mutations[1]['mutationId'], 'mut_order_02');

        inspectedPayload = true;

        return http.Response(
          jsonEncode({
            'success': true,
            'processedCount': 2,
            'results': [
              {
                'mutationId': 'mut_shop_01',
                'status': 'COMMITTED',
                'serverBusinessId': 'ret_srv_101',
                'serverSequence': 4001,
              },
              {
                'mutationId': 'mut_order_02',
                'status': 'COMMITTED',
                'serverBusinessId': 'ord_srv_202',
                'serverSequence': 4002,
              },
            ],
          }),
          200,
        );
      });

      final worker = SyncWorker(
        db: db,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'test_valid_access_token',
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );

      expect(inspectedPayload, true);
      expect(result.success, true);
      expect(result.syncedCount, 2);
    });

    test('2. HTTP 200 marks SQLite mutations as SYNCED with timestamp', () async {
      final mut = await insertTestMutation(
        id: 'mut_sync_200',
        sequenceOrder: 1,
        idempotencyKey: 'idem_sync_200',
        mutationType: 'CREATE_RETAILER',
        payload: {'shopName': 'Kripa Store'},
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'results': [
              {
                'mutationId': mut.id,
                'status': 'COMMITTED',
                'serverBusinessId': 'ret_kripa_999',
                'serverSequence': 5001,
              }
            ],
          }),
          200,
        );
      });

      final worker = SyncWorker(
        db: db,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'test_token',
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(result.success, true);
      expect(result.syncedCount, 1);

      // Verify persistent SQLite state
      final updated = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals(mut.id))).getSingle();
      expect(updated.syncStatus, 'SYNCED');
      expect(updated.syncedAtEpochMs, isNotNull);
      expect(updated.syncedAtEpochMs! > 0, true);
    });

    test('3. Network error / timeout retries and does NOT mark synced', () async {
      final mut = await insertTestMutation(
        id: 'mut_net_fail',
        sequenceOrder: 1,
        idempotencyKey: 'idem_net_fail',
        mutationType: 'CREATE_ORDER',
        payload: {'items': []},
      );

      final mockClient = MockClient((request) async {
        throw const SocketException('No route to host');
      });

      final worker = SyncWorker(
        db: db,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'test_token',
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(result.success, false);
      expect(result.syncedCount, 0);
      expect(worker.state, SyncWorkerState.errorBackoff);

      // Verify SQLite state: not synced! Marked RETRYABLE_FAILURE with future retry timestamp
      final updated = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals(mut.id))).getSingle();
      expect(updated.syncStatus, 'RETRYABLE_FAILURE');
      expect(updated.syncedAtEpochMs, isNull);
      expect(updated.attemptCount, 1);
      expect(updated.lastErrorCode, 'NETWORK_TIMEOUT');
      expect(updated.nextRetryAtMs, isNotNull);
      expect(updated.nextRetryAtMs! > DateTime.now().millisecondsSinceEpoch - 1000, true);
    });

    test('4. HTTP 409 Conflict marks FAILED_PERMANENT and explains to user', () async {
      final mut = await insertTestMutation(
        id: 'mut_conflict_409',
        sequenceOrder: 1,
        idempotencyKey: 'idem_conflict_409',
        mutationType: 'CREATE_ORDER',
        payload: {'tampered': true},
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'IDEMPOTENCY_PAYLOAD_MISMATCH',
            'mutationId': mut.id,
            'message': 'Idempotency key was previously registered with different payload.',
          }),
          409,
        );
      });

      final worker = SyncWorker(
        db: db,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'test_token',
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(result.success, false);
      expect(result.hasPermanentFailure, true);
      expect(result.errorMessage, contains('Idempotency key was previously registered'));

      // Verify SQLite state: FAILED_PERMANENT, not synced
      final updated = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals(mut.id))).getSingle();
      expect(updated.syncStatus, 'FAILED_PERMANENT');
      expect(updated.syncedAtEpochMs, isNull);
      expect(updated.lastErrorCode, 'IDEMPOTENCY_PAYLOAD_MISMATCH');
    });

    test('5. HTTP 401 triggers token refresh and retries batch successfully', () async {
      final mut = await insertTestMutation(
        id: 'mut_auth_401',
        sequenceOrder: 1,
        idempotencyKey: 'idem_auth_401',
        mutationType: 'CREATE_RETAILER',
        payload: {'shopName': 'Refreshed Store'},
      );

      int attempts = 0;
      bool refreshTriggered = false;
      String activeToken = 'expired_token';

      final mockClient = MockClient((request) async {
        attempts++;
        if (request.headers['Authorization'] == 'Bearer expired_token') {
          return http.Response(jsonEncode({'error': 'Token expired'}), 401);
        }
        if (request.headers['Authorization'] == 'Bearer fresh_valid_token') {
          return http.Response(
            jsonEncode({
              'success': true,
              'results': [
                {
                  'mutationId': mut.id,
                  'status': 'COMMITTED',
                  'serverBusinessId': 'ret_refreshed_1',
                  'serverSequence': 6001,
                }
              ],
            }),
            200,
          );
        }
        return http.Response('Forbidden', 403);
      });

      final worker = SyncWorker(
        db: db,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => activeToken,
        refreshTokenTrigger: () async {
          refreshTriggered = true;
          activeToken = 'fresh_valid_token';
          return true;
        },
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(refreshTriggered, true);
      expect(attempts, 2, reason: 'Should attempt with expired token, then retry with fresh token');
      expect(result.success, true);
      expect(result.syncedCount, 1);

      // Verify SQLite state is SYNCED
      final updated = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals(mut.id))).getSingle();
      expect(updated.syncStatus, 'SYNCED');
    });

    test('6. HTTP 401 with failed refresh pauses sync runner for user login', () async {
      await insertTestMutation(
        id: 'mut_unauth_pause',
        sequenceOrder: 1,
        idempotencyKey: 'idem_unauth_pause',
        mutationType: 'CREATE_RETAILER',
        payload: {'shopName': 'Never Synced'},
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Token expired'}), 401);
      });

      final worker = SyncWorker(
        db: db,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'stale_token',
        refreshTokenTrigger: () async => false, // Refresh fails (session revoked)
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(result.success, false);
      expect(result.authRequired, true);
      expect(worker.state, SyncWorkerState.pausedAuthRequired);
    });
  });
}
