import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';

class ZeroNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access strictly forbidden in offline tests');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = ZeroNetworkHttpOverrides();

  group('Slice 6: Honest Sync Status & Order Timeline (Honesty Invariants)', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    const testSession = UserSession(
      userId: 'usr_sales_imran',
      name: 'Imran Khan',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'SALES',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
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
      await api.syncForTesting(seed: true);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Outbox mutations report honest PENDING / Saved-on-phone status until server acknowledgment', () async {
      final shop = api.retailers.first;
      final prod = api.products.first;

      api.selectShop(shop);
      api.addToCart(prod, OrderUnit.box, 1);

      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'COD',
        checkoutIdempotencyKey: 'idem_sync_honest_01',
      );

      // Verify order shows provisional ID
      expect(order.orderNumber.startsWith('LOCAL-ORD-'), isTrue);

      final pendingMutations = await db.outboxDao.getPendingQueue();
      expect(pendingMutations.isNotEmpty, isTrue);

      final orderMutation = pendingMutations.firstWhere((m) => m.provisionalBusinessId == order.id);
      expect(orderMutation.syncStatus, 'PENDING');
      expect(api.getHonestSyncStatusLabel(orderMutation.syncStatus), 'Saved on this phone (Offline Outbox)');
    });

    test('2. Order timeline displays provisional status with sequence order and never displays Synced to Cloud prematurely', () async {
      final shop = api.retailers.first;
      final prod = api.products.first;

      api.selectShop(shop);
      api.addToCart(prod, OrderUnit.box, 3);

      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'CASH',
        checkoutIdempotencyKey: 'idem_timeline_01',
      );

      final timeline = await api.getOrderAuditTimeline(order.id);
      expect(timeline.length, 3);

      // Step 1: Created locally
      expect(timeline[0].title, 'Booked on Device');
      expect(timeline[0].isCompleted, isTrue);

      // Step 2: Written to SQLite Outbox
      expect(timeline[1].title, 'Saved in Local Outbox');
      expect(timeline[1].isCompleted, isTrue);
      expect(timeline[1].subtitle, contains('Sequence #'));

      // Step 3: Server Sync Status
      expect(timeline[2].title, 'Cloud Sync');
      expect(timeline[2].isCompleted, isFalse);
      expect(timeline[2].subtitle, 'Pending upload to Cloudflare');
    });
  });
}
