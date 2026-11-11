import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_exceptions.dart';
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

  group('Part B2: Credit Limit & Class Governance Security Enforcement', () {
    late AppDatabase db;
    late LocalRepository repo;

    const salesSession = UserSession(
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

    const ownerSession = UserSession(
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

    test('1. Salesperson session is strictly blocked from modifying retailer credit limit directly in service/repository', () async {
      final salesApi = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => salesSession,
      );
      await salesApi.syncForTesting(seed: true);

      final shop = salesApi.retailers.first;
      final originalCreditLimit = shop.creditLimitPaise;

      // Salesperson attempts to raise credit limit
      expect(
        () async => await salesApi.updateRetailerCreditLimit(shop.id, originalCreditLimit + 5000000),
        throwsA(isA<UnauthorizedRoleException>()),
      );

      // Verify that data layer in SQLite was NOT mutated
      final refreshedShop = await repo.getRetailerById(shop.id);
      expect(refreshedShop!.creditLimitPaise, equals(originalCreditLimit));
    });

    test('2. Salesperson session is strictly blocked from modifying class settings', () async {
      final salesApi = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => salesSession,
      );
      await salesApi.syncForTesting(seed: true);

      expect(
        () async => await salesApi.updateClassSetting(
          className: 'Class B',
          defaultCreditLimitPaise: 9900000,
          creditDays: 30,
          visitFrequencyDays: 7,
        ),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('3. Sovereign OWNER session can successfully modify credit limits and class settings', () async {
      final ownerApi = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => ownerSession,
      );
      await ownerApi.syncForTesting(seed: true);

      final shop = ownerApi.retailers.first;
      await ownerApi.updateRetailerCreditLimit(shop.id, 7500000);

      expect(shop.creditLimitPaise, equals(7500000));
      final dbShop = await repo.getRetailerById(shop.id);
      expect(dbShop!.creditLimitPaise, equals(7500000));

      await ownerApi.updateClassSetting(
        className: 'Class B',
        defaultCreditLimitPaise: 3500000,
        creditDays: 14,
        visitFrequencyDays: 7,
      );

      final setting = await repo.getClassSetting('Class B');
      expect(setting?.defaultCreditLimitPaise, equals(3500000));
      expect(setting?.creditDays, equals(14));
    });
  });
}
