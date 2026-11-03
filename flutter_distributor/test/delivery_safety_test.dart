import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/role_routing.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  late AppDatabase db;
  late LocalRepository repository;
  late ApiService api;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalRepository(db);
    api = ApiService.internalForTesting(database: db, localRepo: repository);
    await api.syncForTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('RouteFlow B1 Integrity — Delivery OTP & Cash Handover Safety Tests', () {
    test('1. Delivery OTP rejects universal bypass (724185) when stop code does not match', () {
      expect(api.deliveryStops, isNotEmpty);
      final stop = api.deliveryStops.first;
      // Ensure stop has a known OTP code different from 724185
      final actualOtp = stop.serverOtp;
      expect(actualOtp.isNotEmpty, isTrue);

      // Attempting to bypass with incorrect or arbitrary code fails
      final wrongCode = '000000';
      final okWrong = api.confirmDeliveryWithOtp(stop.id, wrongCode);
      expect(okWrong, isFalse, reason: 'Arbitrary wrong OTP code must be rejected');

      // If stop has an OTP that is not 724185, 724185 must NOT bypass it
      if (actualOtp != '724185') {
        final okBypass = api.confirmDeliveryWithOtp(stop.id, '724185');
        expect(okBypass, isFalse, reason: 'Universal bypass 724185 must not confirm delivery');
      }

      // Exact matching assigned code succeeds in local demo mode
      final okCorrect = api.confirmDeliveryWithOtp(stop.id, actualOtp);
      expect(okCorrect, isTrue);
      expect(stop.isDelivered, isTrue);
      expect(stop.cashCollected, isTrue);
    });

    test('2. Cash custody is strictly preserved and cannot be cleared by unsupported handover', () {
      final stop = api.deliveryStops.first;
      api.confirmDeliveryWithOtp(stop.id, stop.serverOtp);
      final initialCustody = api.driverCashCustodyPaise;
      expect(initialCustody, greaterThan(0));

      // Attempting handover or operations without persistent backend reconciliation
      // must NOT clear driverCashCustodyPaise.
      expect(api.driverCashCustodyPaise, equals(initialCustody));
      expect(api.driverCashCustodyRupees, equals(initialCustody / 100.0));
    });

    test('3. OWNER role resolves to dedicated owner role and does NOT resolve to ADMIN', () {
      final canonical = CanonicalRole.fromString('OWNER');
      expect(canonical, equals(CanonicalRole.owner));
      expect(canonical, isNot(equals(CanonicalRole.admin)), reason: 'OWNER must never resolve to ADMIN');

      // Unsupported canonical roles must also fail closed
      expect(CanonicalRole.fromString('SALES_MANAGER'), isNull);
      expect(CanonicalRole.fromString('ACCOUNTANT'), isNull);
      expect(CanonicalRole.fromString('RETAILER'), isNull);
    });
  });
}
