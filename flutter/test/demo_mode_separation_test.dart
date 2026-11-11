import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
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

  group('Part B3: Demo-Mode Separation (Fresh Install Starts Empty)', () {
    late AppDatabase db;
    late LocalRepository repo;

    const testSession = UserSession(
      userId: 'usr_owner_ramesh',
      name: 'Ramesh Lal',
      activeOrganizationId: 'org_jodhpur_dist',
      activeRole: 'OWNER',
      organizations: [
        OrganizationMembership(
          id: 'org_jodhpur_dist',
          name: 'Jodhpur FMCG Distributors',
          role: 'OWNER',
          isActive: true,
        ),
      ],
    );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LocalRepository(db);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. Fresh install starts completely empty without automatic demo seeding', () async {
      final api = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => testSession,
        seed: false, // Explicit fresh install without demo seed
      );
      await api.syncFromDatabaseDirect();

      expect(api.isDemoModeLoaded, isFalse);
      expect(api.products, isEmpty);
      expect(api.retailers, isEmpty);
      expect(api.orders, isEmpty);
    });

    test('2. User tapping Load Demo Data populates FMCG catalog and retailers and persists flag', () async {
      final api = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => testSession,
        seed: false,
      );
      await api.syncFromDatabaseDirect();

      expect(api.products, isEmpty);

      // Trigger user opt-in demo loading
      await api.loadDemoData();

      expect(api.isDemoModeLoaded, isTrue);
      expect(api.products.isNotEmpty, isTrue);
      expect(api.retailers.isNotEmpty, isTrue);

      // Verify persisted in SQLite metadata
      final meta = await repo.getMetadata('demo_mode_loaded');
      expect(meta, equals('true'));

      // Check that products are in SQLite
      final dbProducts = await repo.getAllProducts();
      expect(dbProducts.isNotEmpty, isTrue);
    });
  });
}
