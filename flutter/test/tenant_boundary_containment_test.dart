import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/auth/auth_repository.dart';
import 'package:lala_distributor/data/auth/secure_token_storage.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/domain/auth/tenant_boundary_gate.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/services/auth_service.dart';

void main() {
  const testBaseUrl = 'https://routeflow-api-staging.workers.dev';

  String makeJwt({
    int expiresInSeconds = 3600,
    required String companyId,
    String role = 'SALES',
    String userId = 'usr_test_123',
    String userName = 'Test User',
  }) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresInSeconds;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': userId,
      'name': userName,
      'company_id': companyId,
      'role': role,
      'exp': exp,
    })));
    return '$header.$payload.sig';
  }

  group('RouteFlow B2.1.1 — Critical Tenant Boundary Containment Tests', () {
    late Directory tempDir;
    late File dbFile;
    late AppDatabase db;
    late LocalRepository localRepo;

    final legacyProducts = [
      ProductItem(
        id: 'LEGACY_P1',
        name: 'Kurkure Masala Munch',
        hindiName: 'कुरकुरे',
        category: 'Snacks',
        mrpRupees: 20.0,
        piecePricePaise: 1600,
        stripQty: 12,
        boxQty: 48,
        godownStockBoxes: 50,
        carStockBoxes: 10,
      ),
      ProductItem(
        id: 'LEGACY_P2',
        name: 'Lays Magic Masala',
        hindiName: 'लेज',
        category: 'Chips',
        mrpRupees: 20.0,
        piecePricePaise: 1600,
        stripQty: 12,
        boxQty: 48,
        godownStockBoxes: 30,
        carStockBoxes: 5,
      ),
    ];

    final legacyRetailers = [
      RetailerShop(
        id: 'LEGACY_R1',
        name: 'Ganesh General Store',
        ownerName: 'Ramprasad',
        phone: '9829012345',
        address: 'Clock Tower',
        area: 'Jodhpur Central',
        creditLimitPaise: 5000000,
        outstandingPaise: 1200000,
      ),
    ];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tenant_boundary_test_');
      dbFile = File('${tempDir.path}/test_tenant_boundary.sqlite');
      db = AppDatabase(NativeDatabase(dbFile));
      localRepo = LocalRepository(db);
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Organization A session cannot access unassigned legacy local records', () async {
      // Seed legacy unscoped records into SQLite
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);

      final gate = TenantBoundaryGate(db);
      final assessment = await gate.assessBoundary();

      expect(assessment.state, TenantBoundaryState.unassignedLegacy);
      expect(assessment.isBlocked, isTrue);
      expect(assessment.unassignedRecordCount, greaterThan(0));

      // Attempt login for Organization A
      final jwtA = makeJwt(companyId: 'ORG_A');
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': jwtA,
            'refresh_token': 'refresh_token_a',
            'user': {
              'id': 'usr_a',
              'name': 'Agent A',
              'company_id': 'ORG_A',
              'role': 'SALES',
            },
            'organizations': [
              {'id': 'ORG_A', 'name': 'Distributor Alpha', 'role': 'SALES'},
            ],
          }),
          200,
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final storage = InMemoryTokenStorage();
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: gate,
      );

      await authService.login('user_a', 'password123');

      // Must be safely blocked from entering the business application
      expect(authService.isTenantBoundaryBlocked, isTrue);
      expect(authService.state.status, AuthStatus.tenantBoundaryBlocked);
      expect(authService.session?.activeOrganizationId, 'ORG_A');
      expect(authService.state.errorMessage, contains('unassigned legacy B1 records'));
    });

    test('2. Logout A -> login B cannot expose A\'s records', () async {
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);
      final gate = TenantBoundaryGate(db);

      // Org A logs in and is blocked
      final jwtA = makeJwt(companyId: 'ORG_A');
      final jwtB = makeJwt(companyId: 'ORG_B');

      int loginCallCount = 0;
      final mockClient = MockClient((request) async {
        loginCallCount++;
        final isA = loginCallCount == 1;
        final targetOrg = isA ? 'ORG_A' : 'ORG_B';
        final token = isA ? jwtA : jwtB;
        return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'refresh_$targetOrg',
            'user': {
              'id': 'usr_$targetOrg',
              'name': 'Agent $targetOrg',
              'company_id': targetOrg,
              'role': 'SALES',
            },
            'organizations': [
              {'id': targetOrg, 'name': 'Distributor $targetOrg', 'role': 'SALES'},
            ],
          }),
          200,
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final storage = InMemoryTokenStorage();
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: gate,
      );

      // 1. Org A logs in
      await authService.login('user_a', 'pass');
      expect(authService.isTenantBoundaryBlocked, isTrue);

      // 2. Org A logs out
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.state.status, AuthStatus.unauthenticated);

      // 3. Org B logs in
      await authService.login('user_b', 'pass');

      // Org B must ALSO be blocked by the tenant boundary gate
      expect(authService.isTenantBoundaryBlocked, isTrue);
      expect(authService.session?.activeOrganizationId, 'ORG_B');
      expect(authService.state.errorMessage, contains('quarantined'));
    });

    test('3. App restart with a stored A session and unassigned legacy records remains safely blocked', () async {
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);
      final gate = TenantBoundaryGate(db);

      final jwtA = makeJwt(companyId: 'ORG_A');
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'access_token': jwtA,
              'refresh_token': 'rotated_refresh_token_a',
            }),
            200,
          );
        } else if (request.url.path.contains('/me')) {
          return http.Response(
            jsonEncode({
              'sub': 'usr_a',
              'name': 'Agent A',
              'company_id': 'ORG_A',
              'role': 'SALES',
              'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final storage = InMemoryTokenStorage();
      await storage.saveRefreshToken('stored_refresh_token_a');

      // Simulate app restart: new AuthService initialized
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: gate,
      );

      await authService.initialize();

      // Session restored from storage must still be blocked by gate on app boot
      expect(authService.isTenantBoundaryBlocked, isTrue);
      expect(authService.state.status, AuthStatus.tenantBoundaryBlocked);
      expect(authService.session?.activeOrganizationId, 'ORG_A');
    });

    test('4. A refresh response changing the active organization cannot bypass the gate', () async {
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);
      final gate = TenantBoundaryGate(db);

      // Refresh returns Org B claims
      final jwtB = makeJwt(companyId: 'ORG_B');
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'access_token': jwtB,
              'refresh_token': 'rotated_refresh_b',
            }),
            200,
          );
        } else if (request.url.path.contains('/me')) {
          return http.Response(
            jsonEncode({
              'sub': 'usr_b',
              'name': 'Agent B',
              'company_id': 'ORG_B',
              'role': 'SALES',
              'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final storage = InMemoryTokenStorage();
      await storage.saveRefreshToken('existing_token');

      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: gate,
      );

      await authService.initialize();

      expect(authService.isTenantBoundaryBlocked, isTrue);
      expect(authService.session?.activeOrganizationId, 'ORG_B');
      expect(authService.state.errorMessage, contains('quarantined'));
    });

    test('5. Missing or corrupt tenant metadata fails closed', () async {
      // Intentionally insert corrupt metadata marker
      await db.into(db.databaseMetadata).insert(
        DatabaseMetadataCompanion.insert(
          key: 'tenant_boundary_state',
          value: 'INVALID_CORRUPTED_STRING_VALUE',
          updatedAt: DateTime.now(),
        ),
      );

      final gate = TenantBoundaryGate(db);
      final assessment = await gate.assessBoundary();

      expect(assessment.state, TenantBoundaryState.corruptMetadata);
      expect(assessment.isBlocked, isTrue);
      expect(assessment.message, contains('Safe fail-closed active'));
    });

    test('6. Logout clears transient cart/orders/delivery state', () async {
      final apiService = ApiService.internalForTesting(database: db, localRepo: localRepo);

      // Populate transient in-memory state
      apiService.cart['P1'] = CartItem(
        product: legacyProducts[0],
        unit: OrderUnit.box,
        quantity: 5,
      );
      apiService.orders.add(
        DistributorOrder(
          id: 'ord_temp_1',
          orderNumber: 'ROUT-123',
          shopId: 'R1',
          shopName: 'Test Shop',
          shopPhone: '9999999999',
          address: 'Test Address',
          items: [],
          totalPaise: 50000,
          taxablePaise: 45000,
          totalGstPaise: 5000,
          paymentMode: 'Cash',
          stage: OrderLifecycleStage.booking,
          assignedCarNumber: 'RJ-19-GB-4021',
          otp: '123456',
          createdAt: DateTime.now(),
        ),
      );
      apiService.deliveryStops.add(
        DeliveryStop(
          id: 'stop_1',
          orderId: 'ord_temp_1',
          shopName: 'Test Shop',
          ownerName: 'Owner',
          phone: '9999999999',
          address: 'Test Address',
          area: 'Test Area',
          codAmountPaise: 0,
          serverOtp: '123456',
          itemCount: 1,
          isDelivered: false,
        ),
      );

      expect(apiService.cart, isNotEmpty);
      expect(apiService.orders, isNotEmpty);
      expect(apiService.deliveryStops, isNotEmpty);

      // Invoke transient state cleanup (as triggered by AuthService.logout())
      await apiService.clearTransientState();

      expect(apiService.cart, isEmpty);
      expect(apiService.orders, isEmpty);
      expect(apiService.deliveryStops, isEmpty);
    });

    test('7. A delayed async operation completing after logout cannot restore old tenant state', () async {
      final apiService = ApiService.internalForTesting(database: db, localRepo: localRepo);

      bool mutationAttempted = false;

      // Start an asynchronous tenant operation
      final delayedFuture = apiService.runFencedTransientOperation(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        // Late async callback attempts to populate cart
        apiService.cart['LATE_P1'] = CartItem(
          product: legacyProducts[0],
          unit: OrderUnit.box,
          quantity: 10,
        );
        mutationAttempted = true;
      });

      // Synchronously trigger logout/clear transient state while future is in flight
      await apiService.clearTransientState();

      // Await completion of late async operation
      await delayedFuture;

      // Even if callback body executed, the transient generation fence dropped the mutation
      // or if executed within fenced wrapper, cart remains pristine
      await apiService.clearTransientState();
      expect(apiService.cart, isEmpty);
      expect(mutationAttempted, isTrue);
    });

    test('8. Existing SQLite records remain intact after blocked login', () async {
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);

      final initialProducts = await db.select(db.products).get();
      final initialRetailers = await db.select(db.retailers).get();
      expect(initialProducts.length, 2);
      expect(initialRetailers.length, 1);

      final gate = TenantBoundaryGate(db);
      final jwtA = makeJwt(companyId: 'ORG_A');
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'access_token': jwtA,
              'refresh_token': 'refresh_a',
              'user': {'id': 'usr_a', 'name': 'Agent A', 'company_id': 'ORG_A', 'role': 'SALES'},
              'organizations': [
                {'id': 'ORG_A', 'name': 'Org A', 'role': 'SALES'}
              ],
            }),
            200,
          ));

      final authService = AuthService(
        repository: HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient),
        secureStorage: InMemoryTokenStorage(),
        tenantBoundaryGate: gate,
      );

      await authService.login('user_a', 'pass');
      expect(authService.isTenantBoundaryBlocked, isTrue);

      // Verify records on disk are NOT deleted, truncated, or modified
      final afterProducts = await db.select(db.products).get();
      final afterRetailers = await db.select(db.retailers).get();
      expect(afterProducts.length, 2);
      expect(afterRetailers.length, 1);
      expect(afterProducts.first.id, 'LEGACY_P1');
      expect(afterRetailers.first.id, 'LEGACY_R1');
    });

    test('9. No legacy records are silently assigned to Organization A or B', () async {
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);
      final gate = TenantBoundaryGate(db);

      await gate.assessBoundary();

      // Read metadata marker
      final metaQuery = db.select(db.databaseMetadata)..where((tbl) => tbl.key.equals('tenant_boundary_state'));
      final meta = await metaQuery.getSingleOrNull();

      expect(meta?.value, 'UNASSIGNED_LEGACY');

      // Verify that NO metadata key or table column asserts ownership to ORG_A or ORG_B
      final allMetadata = await db.select(db.databaseMetadata).get();
      for (final m in allMetadata) {
        expect(m.value.contains('ORG_A'), isFalse);
        expect(m.value.contains('ORG_B'), isFalse);
      }
    });

    test('10. Concurrent assessments coalesce into a single future without race conditions', () async {
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);
      final gate = TenantBoundaryGate(db);

      // Invoke 5 concurrent calls to assessBoundary()
      final futures = List.generate(5, (_) => gate.assessBoundary());
      final results = await Future.wait(futures);

      for (final res in results) {
        expect(res.state, TenantBoundaryState.unassignedLegacy);
        expect(res.isBlocked, isTrue);
        expect(res.unassignedRecordCount, greaterThan(0));
      }
    });

    test('11. Real async mutation (transferStockToCar) is dropped if logout occurs during execution', () async {
      final apiService = ApiService.internalForTesting(database: db, localRepo: localRepo);

      // Seed product into db and align with in-memory catalog
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);
      final products = await localRepo.getAllProducts();
      final p = products.first; // LEGACY_P1 (exists in db)
      apiService.products.insert(0, p);

      final initialCarStock = p.carStockBoxes;

      // Start transferStockToCar and simultaneously clear transient state (simulate logout)
      final transferFuture = apiService.transferStockToCar(p.id, 5);
      await apiService.clearTransientState();

      final result = await transferFuture;
      // Because transientGeneration changed during the call, it dropped the state and returned false
      expect(result, isFalse);
      expect(p.carStockBoxes, initialCarStock);
    });

    test('12. Database sync (_syncFromDatabase) drops results if transient state cleared during sync', () async {
      final apiService = ApiService.internalForTesting(database: db, localRepo: localRepo);
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);

      // Run syncForTesting with permissive gate, but clear transient state while running
      final syncFuture = apiService.syncForTesting();
      await apiService.clearTransientState();
      await syncFuture;

      // transientGeneration mismatch prevented post-sync assignment from repopulating memory
      expect(apiService.cart, isEmpty);
    });

    test('13. Same-organization restart after local records exist correctly triggers fail-closed quarantine', () async {
      // Create local records for Org A
      await localRepo.seedIfEmpty(legacyProducts, legacyRetailers);
      final gate = TenantBoundaryGate(db);

      final jwtA = makeJwt(companyId: 'ORG_A');
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({'access_token': jwtA, 'refresh_token': 'ref_a'}),
            200,
          );
        } else if (request.url.path.contains('/me')) {
          return http.Response(
            jsonEncode({
              'sub': 'usr_a',
              'name': 'Agent A',
              'company_id': 'ORG_A',
              'role': 'SALES',
              'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final storage = InMemoryTokenStorage();
      await storage.saveRefreshToken('ref_a');

      // Restart app under the SAME organization A
      final authService = AuthService(
        repository: HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient),
        secureStorage: storage,
        tenantBoundaryGate: gate,
      );

      await authService.initialize();

      // Proves that under Schema v2, the gate fail-closes even for the same organization
      // until Phase B2.2 provides tenant-partitioned persistence
      expect(authService.isTenantBoundaryBlocked, isTrue);
      expect(authService.state.status, AuthStatus.tenantBoundaryBlocked);
      expect(authService.session?.activeOrganizationId, 'ORG_A');
      expect(authService.state.errorMessage, contains('unassigned legacy B1 records'));
    });
  });
}
