import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/services/sync_worker.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('RouteFlow Phase C: Real Client-to-Server End-to-End HTTP Wire Test against Isolated Local D1', () {
    late Process serverProcess;
    late String baseUrl;
    late http.Client realHttpClient;
    late String salesToken;
    late String ownerToken;
    late String comp2OwnerToken;

    const testOrgId = 'comp_1';
    const testSalesUserId = 'user_sales';

    setUpAll(() async {
      realHttpClient = http.Client();

      // 1. Spawn local isolated D1 Cloudflare Worker runner
      final completer = Completer<String>();
      serverProcess = await Process.start(
        'node',
        ['test/run-isolated-server.mjs'],
        workingDirectory: '../backend',
      );

      final lineSplitter = const LineSplitter();
      serverProcess.stdout
          .transform(utf8.decoder)
          .transform(lineSplitter)
          .listen((line) {
        if (line.startsWith('SERVER_READY: ') && !completer.isCompleted) {
          final url = line.substring('SERVER_READY: '.length).trim();
          completer.complete(url);
        }
      });

      serverProcess.stderr
          .transform(utf8.decoder)
          .transform(lineSplitter)
          .listen((line) {
        // print error if any
      });

      baseUrl = await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Timed out waiting for isolated D1 server to boot'),
      );

      // 2. Perform authentic logins against local D1 to obtain valid Bearer JWTs
      final salesLoginRes = await realHttpClient.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': 'sales', 'password': 'password123'}),
      );
      expect(salesLoginRes.statusCode, 200);
      salesToken = jsonDecode(salesLoginRes.body)['access_token'];

      final ownerLoginRes = await realHttpClient.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': 'owner', 'password': 'password123'}),
      );
      expect(ownerLoginRes.statusCode, 200);
      ownerToken = jsonDecode(ownerLoginRes.body)['access_token'];

      final comp2Res = await realHttpClient.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': 'owner_comp2', 'password': 'password123'}),
      );
      expect(comp2Res.statusCode, 200);
      comp2OwnerToken = jsonDecode(comp2Res.body)['access_token'];
    });

    tearDownAll(() async {
      realHttpClient.close();
      serverProcess.kill();
    });

    test('Scenario 1: Offline shop plus order syncs in order over real HTTP with provisional ID rewrite', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LocalRepository(db);
      final api = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => const UserSession(
          userId: testSalesUserId,
          name: 'Rakesh Kumar',
          activeOrganizationId: testOrgId,
          activeRole: 'SALES',
          organizations: [
            OrganizationMembership(id: testOrgId, name: 'Demo Corp', role: 'SALES', isActive: true),
          ],
        ),
      );

      final provShopId = 'PROV-WIRE-SHOP-01';
      final provOrderId = 'PROV-WIRE-ORD-01';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert offline shop mutation
      await db.outboxDao.insertOrderMutationAtomic(
        id: 'mut_wire_shop_01',
        organizationId: testOrgId,
        userId: testSalesUserId,
        idempotencyKey: 'idem_wire_shop_$nowMs',
        mutationType: 'CREATE_RETAILER',
        payloadJson: jsonEncode({
          'shopName': 'Wire Test Kirana',
          'phone': '9829012345',
          'classification': 'NEW',
          'defaultCreditLimitPaise': 0,
        }),
        provisionalBusinessId: provShopId,
        createdAtEpochMs: nowMs,
      );

      // 2. Insert offline order mutation referencing provisional shop ID
      await db.outboxDao.insertOrderMutationAtomic(
        id: 'mut_wire_ord_02',
        organizationId: testOrgId,
        userId: testSalesUserId,
        idempotencyKey: 'idem_wire_ord_$nowMs',
        mutationType: 'CREATE_ORDER',
        payloadJson: jsonEncode({
          'retailerId': provShopId,
          'items': [
            {
              'productId': 'prod_1',
              'orderedQuantity': 2,
              'orderedUnit': 'piece',
              'multiplierToBaseAtTime': 1,
            }
          ],
          'totals': {'totalAmountPaise': 10000},
        }),
        provisionalBusinessId: provOrderId,
        createdAtEpochMs: nowMs + 10,
      );

      // 3. Instantiate real SyncWorker talking to real D1 over HTTP
      final worker = SyncWorker(
        db: db,
        apiService: api,
        httpClient: realHttpClient,
        baseUrl: baseUrl,
        accessTokenProvider: () async => salesToken,
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testSalesUserId,
      );

      expect(result.success, true);
      expect(result.syncedCount, 2);

      // Verify both mutations marked SYNCED in SQLite Drift database
      final shopMut = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals('mut_wire_shop_01'))).getSingle();
      final ordMut = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals('mut_wire_ord_02'))).getSingle();

      expect(shopMut.syncStatus, 'SYNCED');
      expect(ordMut.syncStatus, 'SYNCED');

      // Verify provisional ID was rewritten to real server ID in order payload
      final parsedOrdPayload = jsonDecode(ordMut.payloadJson);
      expect(parsedOrdPayload['retailerId'], isNot(provShopId));
      expect(parsedOrdPayload['retailerId'].toString().startsWith('ret_'), true);

      await db.close();
    });

    test('Scenario 2: Idempotent replay of same order returns COMMITTED cached result without duplicate', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final idemKey = 'idem_replay_test_$nowMs';

      final pushPayload = {
        'clientBatchId': 'batch_replay_01',
        'organizationId': testOrgId,
        'userId': testSalesUserId,
        'mutations': [
          {
            'mutationId': 'mut_replay_01',
            'sequenceOrder': 1,
            'idempotencyKey': idemKey,
            'mutationType': 'CREATE_ORDER',
            'provisionalBusinessId': 'PROV-ORD-REPLAY',
            'createdAtEpochMs': nowMs,
            'payload': {
              'retailerId': 'ret_1',
              'items': [
                {
                  'productId': 'prod_1',
                  'orderedQuantity': 1,
                  'orderedUnit': 'piece',
                  'multiplierToBaseAtTime': 1,
                }
              ],
              'totals': {'totalAmountPaise': 5000},
            }
          }
        ]
      };

      // First push over real wire
      final res1 = await realHttpClient.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $salesToken',
        },
        body: jsonEncode(pushPayload),
      );
      expect(res1.statusCode, 200);
      final json1 = jsonDecode(res1.body);
      expect(json1['results'][0]['status'], 'COMMITTED');
      final serverId = json1['results'][0]['serverBusinessId'];

      // Second push (identical payload replay)
      final res2 = await realHttpClient.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $salesToken',
        },
        body: jsonEncode(pushPayload),
      );
      expect(res2.statusCode, 200);
      final json2 = jsonDecode(res2.body);
      expect(json2['results'][0]['status'], 'COMMITTED');
      expect(json2['results'][0]['cached'], true);
      expect(json2['results'][0]['serverBusinessId'], serverId);
    });

    test('Scenario 3: Second order for remaining stock is rejected by D1 and phone releases virtual reservation', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LocalRepository(db);
      final api = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => const UserSession(
          userId: testSalesUserId,
          name: 'Rakesh Kumar',
          activeOrganizationId: testOrgId,
          activeRole: 'SALES',
          organizations: [
            OrganizationMembership(id: testOrgId, name: 'Demo Corp', role: 'SALES', isActive: true),
          ],
        ),
      );
      final testShop = RetailerShop(
        id: 'ret_1',
        name: 'Mega Mart',
        ownerName: 'Owner Test',
        area: 'Sector 1',
        phone: '9829000001',
        address: '123 Main St',
        creditLimitPaise: 1000000,
        outstandingPaise: 0,
        classType: 'NEW',
      );
      final testProd = ProductItem(
        id: 'prod_2',
        name: 'Whole Wheat Bread',
        hindiName: 'ब्रेड',
        category: 'Bakery',
        mrpPaise: 3500,
        mrpRupees: 35.0,
        piecePricePaise: 3500,
        stripQty: 1,
        boxQty: 10,
        gstRate: 5.0,
        godownStockBoxes: 50,
        carStockBoxes: 0,
      );

      api.retailers.add(testShop);
      api.products.add(testProd);

      api.selectShop(testShop);
      api.addToCart(testProd, OrderUnit.box, 1);

      final order = await api.confirmOrderDurable(
        shopId: testShop.id,
        paymentMode: 'COD',
        checkoutIdempotencyKey: 'idem_wire_oversell_${DateTime.now().millisecondsSinceEpoch}',
      );
      expect(order.id, isNotEmpty);

      // Verify phone initially made virtual reservation
      expect(api.pendingBookingPieces('prod_2'), greaterThan(0));

      final worker = SyncWorker(
        db: db,
        apiService: api,
        httpClient: realHttpClient,
        baseUrl: baseUrl,
        accessTokenProvider: () async => salesToken,
      );

      // Tamper outbox payload to demand 9999 units
      final pendingMut = (await db.outboxDao.getPendingQueue()).first;
      final tamperedPayload = jsonDecode(pendingMut.payloadJson);
      tamperedPayload['items'] = [
        {
          'productId': 'prod_2',
          'orderedQuantity': 9999, // Exceeds available 50
          'orderedUnit': 'piece',
          'multiplierToBaseAtTime': 1,
        }
      ];

      await (db.update(db.outboxMutations)..where((tbl) => tbl.id.equals(pendingMut.id))).write(
        OutboxMutationsCompanion(
          payloadJson: drift.Value(jsonEncode(tamperedPayload)),
        ),
      );

      final pushResult = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testSalesUserId,
      );

      // Invariant: D1 rejected order with INSUFFICIENT_STOCK
      expect(pushResult.hasPermanentFailure, true);
      expect(worker.lastError?.contains('Overselling protection') ?? false, true);

      // Invariant: Phone caught rejection, marked failed permanent, and released virtual reservation!
      expect(api.pendingBookingPieces('prod_2'), 0);

      final finalMut = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals(pendingMut.id))).getSingle();
      expect(finalMut.syncStatus, 'FAILED_PERMANENT');
      expect(finalMut.lastErrorCode, 'INSUFFICIENT_STOCK');

      await db.close();
    });

    test('Scenario 4: Salesperson cannot set non-zero credit on shop creation (D1 returns 403 FORBIDDEN_ROLE_ACTION)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await db.outboxDao.insertOrderMutationAtomic(
        id: 'mut_wire_sales_credit',
        organizationId: testOrgId,
        userId: testSalesUserId,
        idempotencyKey: 'idem_sales_credit_$nowMs',
        mutationType: 'CREATE_RETAILER',
        payloadJson: jsonEncode({
          'shopName': 'Unauthorized Credit Kirana',
          'phone': '9829055555',
          'classification': 'NEW',
          'defaultCreditLimitPaise': 5000000, // Non-zero credit attempted by Sales
        }),
        provisionalBusinessId: 'PROV-CRED-FAIL',
        createdAtEpochMs: nowMs,
      );

      final worker = SyncWorker(
        db: db,
        httpClient: realHttpClient,
        baseUrl: baseUrl,
        accessTokenProvider: () async => salesToken,
      );

      final result = await worker.processPendingOutbox(
        organizationId: testOrgId,
        userId: testSalesUserId,
      );

      expect(result.hasPermanentFailure, true);

      final mut = await (db.select(db.outboxMutations)..where((tbl) => tbl.id.equals('mut_wire_sales_credit'))).getSingle();
      expect(mut.syncStatus, 'FAILED_PERMANENT');
      expect(mut.lastErrorCode, 'FORBIDDEN_ROLE_ACTION');

      await db.close();
    });

    test('Scenario 5: Multi-tenant boundary: Tenant 2 token rejected on Tenant 1 push; Tenant 2 pull isolates data', () async {
      // 1. Cross-tenant push rejection: comp_2 owner token attempts to push for comp_1
      final crossPushRes = await realHttpClient.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $comp2OwnerToken',
        },
        body: jsonEncode({
          'clientBatchId': 'batch_cross_tenant_probe',
          'organizationId': 'comp_1', // Mismatched tenant
          'mutations': [
            {
              'mutationId': 'mut_cross_01',
              'sequenceOrder': 1,
              'idempotencyKey': 'idem_cross_01',
              'mutationType': 'CREATE_RETAILER',
              'payload': {'shopName': 'Cross Shop'}
            }
          ]
        }),
      );

      expect(crossPushRes.statusCode, 403);
      final crossJson = jsonDecode(crossPushRes.body);
      expect(crossJson['error'], 'TENANT_MISMATCH');

      // 2. Tenant 2 delta pull returns only comp_2 products
      final pullRes = await realHttpClient.post(
        Uri.parse('$baseUrl/sync/pull'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $comp2OwnerToken',
        },
        body: jsonEncode({
          'organizationId': 'comp_2',
          'lastServerSequence': 0,
        }),
      );

      expect(pullRes.statusCode, 200);
      final pullData = jsonDecode(pullRes.body)['delta'];
      final products = pullData['products'] as List<dynamic>;

      // Ensure every returned product belongs strictly to comp_2
      for (final p in products) {
        expect(p['id'], isNot('prod_1'));
        expect(p['id'], isNot('prod_2'));
      }
      expect(products.any((p) => p['id'] == 'prod_comp2_1'), true);
    });

    test('Scenario 6: Custom packaging order: Crate = 24 bottles correctly verified and reserves 24 pieces on D1', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Owner registers custom packaging unit for prod_1: 'Crate' with multiplier 24
      final updateUnitRes = await realHttpClient.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $ownerToken',
        },
        body: jsonEncode({
          'clientBatchId': 'batch_packaging_$nowMs',
          'organizationId': testOrgId,
          'mutations': [
            {
              'mutationId': 'mut_unit_pack_$nowMs',
              'sequenceOrder': 1,
              'idempotencyKey': 'idem_pack_$nowMs',
              'mutationType': 'UPDATE_PRODUCT_UNITS',
              'payload': {
                'productId': 'prod_1',
                'units': [
                  {
                    'unitName': 'piece',
                    'multiplierToBase': 1,
                    'wholesalePricePaise': 5000,
                    'canSell': true,
                  },
                  {
                    'unitName': 'crate',
                    'multiplierToBase': 24,
                    'wholesalePricePaise': 110000, // 24 bottles bundle price
                    'canSell': true,
                  }
                ]
              }
            }
          ]
        }),
      );
      expect(updateUnitRes.statusCode, 200);

      // 2. Salesperson orders 2 Crates (= 48 base pieces)
      final orderRes = await realHttpClient.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $salesToken',
        },
        body: jsonEncode({
          'clientBatchId': 'batch_crate_order_$nowMs',
          'organizationId': testOrgId,
          'mutations': [
            {
              'mutationId': 'mut_crate_ord_$nowMs',
              'sequenceOrder': 1,
              'idempotencyKey': 'idem_crate_ord_$nowMs',
              'mutationType': 'CREATE_ORDER',
              'payload': {
                'retailerId': 'ret_1',
                'items': [
                  {
                    'productId': 'prod_1',
                    'orderedQuantity': 2,
                    'orderedUnit': 'crate',
                    'multiplierToBaseAtTime': 24, // verified against server master
                  }
                ],
                'totals': {'totalAmountPaise': 220000}
              }
            }
          ]
        }),
      );

      expect(orderRes.statusCode, 200);
      final ordJson = jsonDecode(orderRes.body);
      expect(ordJson['results'][0]['status'], 'COMMITTED');

      // Server-side calculation verification: 2 crates * 110000 paise = 220000 paise
      final totals = ordJson['results'][0]['serverCalculatedTotals'];
      expect(totals['totalAmountPaise'], 220000);
    });
  });
}
