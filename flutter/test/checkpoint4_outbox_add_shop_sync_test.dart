import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/services/sync_worker.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Checkpoint 4: Outbox Add-Shop & Offline Sync Suite', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const testOrgId = 'comp_1';
    const testUserId = 'user_sales_101';
    const testBaseUrl = 'https://api.routeflow.test';

    const testSession = UserSession(
      userId: testUserId,
      name: 'Rakesh Kumar',
      activeOrganizationId: testOrgId,
      activeRole: 'SALES',
      organizations: [
        OrganizationMembership(
          id: testOrgId,
          name: 'RouteFlow FMCG Jodhpur',
          role: 'SALES',
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
        sessionProvider: () => testSession,
      );
      await api.syncForTesting(seed: false);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Offline Add-Shop creates local retailer with PENDING status and queues CREATE_RETAILER outbox mutation', () async {
      final newShop = await api.createRetailerDurable(
        name: 'Shree Krishna Provisions',
        ownerName: 'Gopal Lal',
        phone: '98290 12345',
        address: 'Nai Sadak, Clock Tower',
        area: 'Jodhpur',
        latitude: 26.2918,
        longitude: 73.0245,
      );

      expect(newShop.id, startsWith('ret_'));
      expect(newShop.syncStatus, 'PENDING');
      expect(newShop.classType, 'NEW');
      expect(newShop.creditLimitPaise, 0);

      // Verify in SQLite Drift table
      final storedRetailer = await repo.getRetailerById(newShop.id);
      expect(storedRetailer, isNotNull);
      expect(storedRetailer!.syncStatus, 'PENDING');
      expect(storedRetailer.name, 'Shree Krishna Provisions');

      // Verify in Outbox mutations table
      final pending = await db.outboxDao.getPendingMutations(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(pending.length, 1);
      expect(pending.first.mutationType, 'CREATE_RETAILER');
      expect(pending.first.provisionalBusinessId, newShop.id);
      expect(pending.first.syncStatus, 'PENDING');
    });

    test('2. Successful background sync rewrites provisional ID to server ID across SQLite and in-memory store', () async {
      final newShop = await api.createRetailerDurable(
        name: 'Marwar Traders',
        ownerName: 'Bhawani Singh',
        phone: '98290 54321',
        address: 'Station Road',
        area: 'Jodhpur',
      );

      final provId = newShop.id;
      const serverAssignedId = 'ret_srv_998877';

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/sync/push');
        expect(request.headers['Authorization'], 'Bearer valid_jwt_token');

        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final mutations = reqBody['mutations'] as List<dynamic>;
        expect(mutations.length, 1);
        expect(mutations.first['mutationType'], 'CREATE_RETAILER');
        expect(mutations.first['provisionalBusinessId'], provId);

        return http.Response(
          jsonEncode({
            'success': true,
            'clientBatchId': reqBody['clientBatchId'],
            'results': [
              {
                'mutationId': mutations.first['mutationId'],
                'status': 'COMMITTED',
                'provisionalBusinessId': provId,
                'serverBusinessId': serverAssignedId,
                'serverSequence': 42,
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final worker = SyncWorker(
        db: db,
        apiService: api,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'valid_jwt_token',
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );

      expect(result.success, true);
      expect(result.syncedCount, 1);

      // Verify outbox mutation marked SYNCED
      final pendingAfter = await db.outboxDao.getPendingMutations(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(pendingAfter.isEmpty, true);

      // Verify SQLite retailer ID rewritten to server ID and syncStatus updated to SYNCED
      final oldStore = await repo.getRetailerById(provId);
      expect(oldStore, isNull);

      final rewrittenStore = await repo.getRetailerById(serverAssignedId);
      expect(rewrittenStore, isNotNull);
      expect(rewrittenStore!.id, serverAssignedId);
      expect(rewrittenStore.syncStatus, 'SYNCED');

      // Verify in-memory ApiService retailer updated
      final inMemoryShop = api.retailers.firstWhere((r) => r.id == serverAssignedId);
      expect(inMemoryShop.id, serverAssignedId);
      expect(inMemoryShop.syncStatus, 'SYNCED');
    });

    test('3. Network connection drop triggers exponential backoff schedule and records RETRYABLE_FAILURE', () async {
      final newShop = await api.createRetailerDurable(
        name: 'Desert Provision Store',
        ownerName: 'Manish Dave',
        phone: '98290 77889',
        address: 'Bhadwasiya Road',
        area: 'Jodhpur',
      );
      expect(newShop.name, 'Desert Provision Store');

      int attemptCount = 0;
      final mockClient = MockClient((request) async {
        attemptCount++;
        throw const SocketException('Connection reset by peer');
      });

      final worker = SyncWorker(
        db: db,
        apiService: api,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'valid_jwt_token',
      );

      // 1st Failure: backoff = 1s
      final res1 = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(res1.success, false);
      expect(attemptCount, 1);
      expect(worker.state, SyncWorkerState.errorBackoff);

      var mutations = await db.outboxDao.getPendingMutations(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(mutations.first.syncStatus, 'RETRYABLE_FAILURE');
      expect(mutations.first.attemptCount, 1);
      final firstRetryAt = mutations.first.nextRetryAtMs!;
      expect(firstRetryAt, greaterThan(DateTime.now().millisecondsSinceEpoch - 2000));

      // Immediate call without forceRetry should be skipped due to backoff timer
      final resSkipped = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(resSkipped.syncedCount, 0);
      expect(attemptCount, 1); // No new network request made!

      // Manual or reconnect forceRetry bypasses backoff delay
      final resForced = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
        forceRetry: true,
      );
      expect(attemptCount, 2); // Force retry attempted!
      expect(resForced.success, false);

      mutations = await db.outboxDao.getPendingMutations(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(mutations.first.attemptCount, 2);
    });

    test('4. Conflict Resolution: 409 DUPLICATE_RETAILER_PHONE marks mutation and local retailer REJECTED without corrupting unrelated mutations', () async {
      // 1. Create duplicate shop
      final dupShop = await api.createRetailerDurable(
        name: 'Duplicate Phone Store',
        ownerName: 'Ramesh',
        phone: '98290 11111',
        address: 'Main Market',
        area: 'Jodhpur',
      );

      // 2. Mock server 409 Conflict with DUPLICATE_RETAILER_PHONE
      final mockClient = MockClient((request) async {
        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final mId = (reqBody['mutations'] as List).first['mutationId'];

        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'DUPLICATE_RETAILER_PHONE',
            'mutationId': mId,
            'existingRetailerId': 'ret_existing_original_01',
            'existingRetailerName': 'Original Shree Ram Kirana',
            'message': "Retailer with phone number '9829011111' already exists in your organization: 'Original Shree Ram Kirana' (ret_existing_original_01)",
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final worker = SyncWorker(
        db: db,
        apiService: api,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'valid_jwt_token',
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );

      expect(result.success, false);
      expect(result.hasPermanentFailure, true);

      // Verify outbox mutation marked FAILED_PERMANENT with DUPLICATE_RETAILER_PHONE
      final failedMutations = await db.outboxDao.getFailedMutations();
      final failed = failedMutations.firstWhere((m) => m.provisionalBusinessId == dupShop.id);
      expect(failed.syncStatus, 'FAILED_PERMANENT');
      expect(failed.lastErrorCode, 'DUPLICATE_RETAILER_PHONE');

      // Verify local SQLite retailer marked REJECTED
      final localStore = await repo.getRetailerById(dupShop.id);
      expect(localStore, isNotNull);
      expect(localStore!.syncStatus, 'REJECTED');

      // Verify in-memory retailer marked REJECTED
      final inMemoryShop = api.retailers.firstWhere((r) => r.id == dupShop.id);
      expect(inMemoryShop.syncStatus, 'REJECTED');
    });

    test('5. Dependent order placed offline for provisional shop is preserved and synced after shop creation commits', () async {
      // 1. Create offline shop
      final shop = await api.createRetailerDurable(
        name: 'Combined Offline Store',
        ownerName: 'Virendra',
        phone: '98290 66554',
        address: 'Mandore Beat',
        area: 'Jodhpur',
      );
      final provShopId = shop.id;

      // 2. Queue dependent order referencing provisional shop ID
      const provOrderId = 'PROV-ORD-DEP-01';
      await db.outboxDao.insertOrderMutationAtomic(
        id: 'mut_dep_order_01',
        organizationId: testOrgId,
        userId: testUserId,
        idempotencyKey: 'idem_dep_order_01',
        mutationType: 'CREATE_ORDER',
        payloadJson: jsonEncode({
          'retailerId': provShopId,
          'items': [
            {
              'productId': 'prod_sample_01',
              'orderedQuantity': 5,
              'orderedUnit': 'box',
              'multiplierToBaseAtTime': 24,
            }
          ],
          'totals': {'totalAmountPaise': 240000},
        }),
        provisionalBusinessId: provOrderId,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch + 10,
      );

      const serverAssignedShopId = 'ret_srv_confirmed_777';
      const serverAssignedOrderId = 'ord_srv_confirmed_888';

      final mockClient = MockClient((request) async {
        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final mutations = reqBody['mutations'] as List<dynamic>;

        // Verify batch ordering: shop mutation is first, order mutation is second
        expect(mutations.length, 2);
        expect(mutations[0]['mutationType'], 'CREATE_RETAILER');
        expect(mutations[1]['mutationType'], 'CREATE_ORDER');

        return http.Response(
          jsonEncode({
            'success': true,
            'clientBatchId': reqBody['clientBatchId'],
            'results': [
              {
                'mutationId': mutations[0]['mutationId'],
                'status': 'COMMITTED',
                'provisionalBusinessId': provShopId,
                'serverBusinessId': serverAssignedShopId,
                'serverSequence': 101,
              },
              {
                'mutationId': mutations[1]['mutationId'],
                'status': 'COMMITTED',
                'provisionalBusinessId': provOrderId,
                'serverBusinessId': serverAssignedOrderId,
                'serverSequence': 102,
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final worker = SyncWorker(
        db: db,
        apiService: api,
        httpClient: mockClient,
        baseUrl: testBaseUrl,
        accessTokenProvider: () async => 'valid_jwt_token',
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testUserId,
      );

      expect(result.success, true);
      expect(result.syncedCount, 2);

      // Verify both mutations marked SYNCED
      final pendingAfter = await db.outboxDao.getPendingMutations(
        organizationId: testOrgId,
        userId: testUserId,
      );
      expect(pendingAfter.isEmpty, true);

      // Verify SQLite retailer rewritten to server ID and marked SYNCED
      final shopInDb = await repo.getRetailerById(serverAssignedShopId);
      expect(shopInDb, isNotNull);
      expect(shopInDb!.syncStatus, 'SYNCED');
    });
  });
}
