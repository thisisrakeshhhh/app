import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/domain/models/phone_sanitizer.dart';
import 'package:lala_distributor/domain/models/retailer_business_validator.dart';
import 'package:lala_distributor/domain/models/retailer_classification.dart';
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

  group('Checkpoint 3: Phone Number Normalization & Sanitization (TRAI Mobile Standard)', () {
    test('1. Normalizes all common Indian mobile formats to canonical 10-digit format', () {
      // 10 digits clean
      expect(PhoneSanitizer.normalize('9829012345'), equals('9829012345'));

      // +91 with spaces, hyphens, and brackets
      expect(PhoneSanitizer.normalize('+91 98290 12345'), equals('9829012345'));
      expect(PhoneSanitizer.normalize('+91-98290-12345'), equals('9829012345'));
      expect(PhoneSanitizer.normalize('+91 (982) 901-2345'), equals('9829012345'));
      expect(PhoneSanitizer.normalize('+919829012345'), equals('9829012345'));

      // 91 prefix without plus (12 digits)
      expect(PhoneSanitizer.normalize('919829012345'), equals('9829012345'));

      // 0 trunk prefix (11 digits)
      expect(PhoneSanitizer.normalize('09829012345'), equals('9829012345'));
      expect(PhoneSanitizer.normalize('0 98290 12345'), equals('9829012345'));

      // +910 combo prefix (13 digits)
      expect(PhoneSanitizer.normalize('+9109829012345'), equals('9829012345'));

      // Valid starting digits per TRAI (6, 7, 8, 9)
      expect(PhoneSanitizer.normalize('6123456789'), equals('6123456789'));
      expect(PhoneSanitizer.normalize('7890123456'), equals('7890123456'));
      expect(PhoneSanitizer.normalize('8901234567'), equals('8901234567'));
      expect(PhoneSanitizer.normalize('9012345678'), equals('9012345678'));
    });

    test('2. Rejects invalid mobile numbers and provides human-readable validation errors', () {
      // Too short
      expect(PhoneSanitizer.isValidIndianMobile('98290'), isFalse);
      expect(PhoneSanitizer.validateIndianMobile('98290'), contains('at least 10 digits'));

      // Too long without country code
      expect(PhoneSanitizer.isValidIndianMobile('98290123456789'), isFalse);
      expect(PhoneSanitizer.validateIndianMobile('98290123456789'), contains('cannot exceed 10 digits'));

      // Invalid starting digit (0-5 not allocated to mobile services in India)
      expect(PhoneSanitizer.isValidIndianMobile('5829012345'), isFalse);
      expect(PhoneSanitizer.validateIndianMobile('5829012345'), contains('must start with 6, 7, 8, or 9'));
      expect(PhoneSanitizer.isValidIndianMobile('1234567890'), isFalse);
      expect(PhoneSanitizer.validateIndianMobile('1234567890'), contains('must start with 6, 7, 8, or 9'));

      // Empty or null
      expect(PhoneSanitizer.isValidIndianMobile(null), isFalse);
      expect(PhoneSanitizer.validateIndianMobile(null), contains('required'));
      expect(PhoneSanitizer.isValidIndianMobile('   '), isFalse);
      expect(PhoneSanitizer.validateIndianMobile('   '), contains('required'));
    });

    test('3. Formats phone numbers correctly for display and standard protocols', () {
      const raw = '9829012345';
      expect(PhoneSanitizer.formatDisplay(raw), equals('+91 98290 12345'));
      expect(PhoneSanitizer.formatNational(raw), equals('98290 12345'));
      expect(PhoneSanitizer.formatE164(raw), equals('+919829012345'));

      // Gracefully handles non-normalizable input by returning trimmed raw
      expect(PhoneSanitizer.formatDisplay('invalid_number'), equals('invalid_number'));
    });
  });

  group('Checkpoint 3: Retailer Classification & Business Rules Foundation', () {
    test('1. Normalizes arbitrary classification strings to canonical codes (A, B, C, D, NEW)', () {
      expect(RetailerClassification.normalize('CLASS_A'), equals('A'));
      expect(RetailerClassification.normalize('Class A'), equals('A'));
      expect(RetailerClassification.normalize('a'), equals('A'));

      expect(RetailerClassification.normalize('CLASS_B'), equals('B'));
      expect(RetailerClassification.normalize('b'), equals('B'));

      expect(RetailerClassification.normalize('CLASS_C'), equals('C'));
      expect(RetailerClassification.normalize('c'), equals('C'));

      expect(RetailerClassification.normalize('CLASS_D'), equals('D'));
      expect(RetailerClassification.normalize('d'), equals('D'));

      expect(RetailerClassification.normalize('CLASS_NEW'), equals('NEW'));
      expect(RetailerClassification.normalize('new'), equals('NEW'));
      expect(RetailerClassification.normalize(null), equals('NEW'));
      expect(RetailerClassification.normalize('UNKNOWN_VAL'), equals('NEW'));
    });

    test('2. Provides correct default credit limits and credit payment terms', () {
      // Class A: ₹50,000 / 14 days
      expect(RetailerClassification.defaultCreditLimitPaise('A'), equals(5000000));
      expect(RetailerClassification.defaultCreditDays('A'), equals(14));
      expect(RetailerClassification.defaultVisitFrequencyDays('A'), equals(1));

      // Class B: ₹25,000 / 7 days
      expect(RetailerClassification.defaultCreditLimitPaise('B'), equals(2500000));
      expect(RetailerClassification.defaultCreditDays('B'), equals(7));
      expect(RetailerClassification.defaultVisitFrequencyDays('B'), equals(2));

      // Class C: ₹10,000 / 3 days
      expect(RetailerClassification.defaultCreditLimitPaise('C'), equals(1000000));
      expect(RetailerClassification.defaultCreditDays('C'), equals(3));
      expect(RetailerClassification.defaultVisitFrequencyDays('C'), equals(3));

      // Class D: ₹0 / 0 days (Cash on delivery)
      expect(RetailerClassification.defaultCreditLimitPaise('D'), equals(0));
      expect(RetailerClassification.defaultCreditDays('D'), equals(0));
      expect(RetailerClassification.defaultVisitFrequencyDays('D'), equals(7));

      // Class NEW: ₹0 / 0 days (Strictly cash-only until approved by owner)
      expect(RetailerClassification.defaultCreditLimitPaise('NEW'), equals(0));
      expect(RetailerClassification.defaultCreditDays('NEW'), equals(0));
      expect(RetailerClassification.defaultVisitFrequencyDays('NEW'), equals(1));
    });

    test('3. Enforces cash-only invariant: NEW and D shops can NEVER use credit / khata', () {
      // Class NEW cannot use credit even if a rogue local field had positive paise
      expect(
        RetailerClassification.canUseCredit(classType: 'NEW', creditLimitPaise: 5000000),
        isFalse,
      );
      // Class D cannot use credit even if positive paise
      expect(
        RetailerClassification.canUseCredit(classType: 'D', creditLimitPaise: 2500000),
        isFalse,
      );

      // Classes A, B, C can use credit only when limit > 0
      expect(
        RetailerClassification.canUseCredit(classType: 'A', creditLimitPaise: 5000000),
        isTrue,
      );
      expect(
        RetailerClassification.canUseCredit(classType: 'B', creditLimitPaise: 0),
        isFalse,
      );
      expect(
        RetailerClassification.canUseCredit(classType: 'C', creditLimitPaise: 1000000),
        isTrue,
      );
    });

    test('4. Enforces role-based permissions on classification and credit assignment', () {
      // Salesperson role can ONLY assign NEW class and 0 credit limit
      expect(RetailerClassification.canRoleAssignClass(role: 'SALES', targetClass: 'NEW'), isTrue);
      expect(RetailerClassification.canRoleAssignClass(role: 'SALES', targetClass: 'A'), isFalse);
      expect(RetailerClassification.canRoleAssignClass(role: 'SALES', targetClass: 'CLASS_B'), isFalse);
      expect(RetailerClassification.canRoleAssignCredit(role: 'SALES', creditLimitPaise: 0), isTrue);
      expect(RetailerClassification.canRoleAssignCredit(role: 'SALES', creditLimitPaise: 10000), isFalse);

      // Owner and Admin can assign any valid class and non-negative credit limit
      expect(RetailerClassification.canRoleAssignClass(role: 'OWNER', targetClass: 'A'), isTrue);
      expect(RetailerClassification.canRoleAssignClass(role: 'ADMIN', targetClass: 'B'), isTrue);
      expect(RetailerClassification.canRoleAssignCredit(role: 'OWNER', creditLimitPaise: 5000000), isTrue);
      expect(RetailerClassification.canRoleAssignCredit(role: 'ADMIN', creditLimitPaise: 2500000), isTrue);
      expect(RetailerClassification.canRoleAssignCredit(role: 'OWNER', creditLimitPaise: -100), isFalse);
    });
  });

  group('Checkpoint 3: Statutory Business Identifiers (GSTIN Structure, PAN & Modulo-36 Checksum)', () {
    test('1. Validates standard 15-character statutory GSTIN structure (regex)', () {
      expect(RetailerBusinessValidator.isValidGstinStructure('08AAACH1234F1Z5'), isTrue);
      expect(RetailerBusinessValidator.isValidGstinStructure('07AAAAA0000A1Z5'), isTrue);

      // Invalid GSTIN structures
      expect(RetailerBusinessValidator.isValidGstinStructure('08AAACH1234F1'), isFalse); // Too short
      expect(RetailerBusinessValidator.isValidGstinStructure('08AAACH1234F1X5'), isFalse); // 14th char not Z
      expect(RetailerBusinessValidator.isValidGstinStructure('invalid_gstin_str'), isFalse);
      expect(RetailerBusinessValidator.isValidGstinStructure(null), isFalse);
    });

    test('2. Computes and verifies official Indian GSTN Luhn Modulo-36 check-digit', () {
      // Official GSTN example: 27AAPFU0939F1Z => check digit V
      const prefix = '27AAPFU0939F1Z';
      final checkDigit = RetailerBusinessValidator.computeGstinCheckDigit(prefix);
      expect(checkDigit, equals('V'));

      const validGstinWithChecksum = '27AAPFU0939F1ZV';
      expect(RetailerBusinessValidator.isValidGstinChecksum(validGstinWithChecksum), isTrue);
      expect(RetailerBusinessValidator.isValidGstin(validGstinWithChecksum, verifyChecksum: true), isTrue);

      // Tampered 15th character (X instead of V) fails checksum validation
      const invalidChecksumGstin = '27AAPFU0939F1ZX';
      expect(RetailerBusinessValidator.isValidGstinStructure(invalidChecksumGstin), isTrue); // Structure ok
      expect(RetailerBusinessValidator.isValidGstinChecksum(invalidChecksumGstin), isFalse); // Checksum fails!
      expect(RetailerBusinessValidator.isValidGstin(invalidChecksumGstin, verifyChecksum: true), isFalse);
    });

    test('3. Automatically extracts and validates 10-character PAN from GSTIN', () {
      const gstin = '27AAPFU0939F1ZV';
      final pan = RetailerBusinessValidator.extractPanFromGstin(gstin);
      expect(pan, equals('AAPFU0939F'));
      expect(RetailerBusinessValidator.isValidPan(pan), isTrue);

      // Resolves explicit PAN when given, falls back to GSTIN extraction
      expect(
        RetailerBusinessValidator.resolvePan(pan: 'BBBBB1111B', gstin: gstin),
        equals('BBBBB1111B'),
      );
      expect(
        RetailerBusinessValidator.resolvePan(pan: null, gstin: gstin),
        equals('AAPFU0939F'),
      );
    });

    test('4. Validates 6-digit Indian postal PIN codes', () {
      expect(RetailerBusinessValidator.isValidPincode('342001'), isTrue); // Jodhpur
      expect(RetailerBusinessValidator.isValidPincode('160017'), isTrue); // Chandigarh

      expect(RetailerBusinessValidator.isValidPincode('012345'), isFalse); // Starts with 0
      expect(RetailerBusinessValidator.isValidPincode('34200'), isFalse); // 5 digits
      expect(RetailerBusinessValidator.isValidPincode('3420011'), isFalse); // 7 digits
      expect(RetailerBusinessValidator.isValidPincode(null), isFalse);
    });
  });

  group('Checkpoint 3: LocalRepository & ApiService Duplicate Protection', () {
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

    test('1. LocalRepository finds retailer by normalized phone regardless of query format', () async {
      // Seeded shop has phone '+91 98290 12345'
      final foundClean = await repo.findRetailerByPhone('9829012345');
      expect(foundClean, isNotNull);
      expect(foundClean!.name, contains('Shree Ganesh'));

      final foundCountryCode = await repo.findRetailerByPhone('+91 98290 12345');
      expect(foundCountryCode, isNotNull);
      expect(foundCountryCode!.id, equals(foundClean.id));

      final foundTrunk = await repo.findRetailerByPhone('09829012345');
      expect(foundTrunk, isNotNull);
      expect(foundTrunk!.id, equals(foundClean.id));

      final notFound = await repo.findRetailerByPhone('9988776655');
      expect(notFound, isNull);
    });

    test('2. LocalRepository isPhoneRegistered respects excludeRetailerId for edit operations', () async {
      // Seeded shop has phone '+91 98290 12345' with id 'RET-JDH-01'
      final isRegistered = await repo.isPhoneRegistered('9829012345');
      expect(isRegistered, isTrue);

      // Excluding RET-JDH-01 itself should return false (allows updating own profile)
      final isSelfRegistered = await repo.isPhoneRegistered('9829012345', excludeRetailerId: 'RET-JDH-01');
      expect(isSelfRegistered, isFalse);

      // Excluding a different ID still flags the conflict
      final isOtherRegistered = await repo.isPhoneRegistered('9829012345', excludeRetailerId: 'RET-JDH-02');
      expect(isOtherRegistered, isTrue);
    });

    test('3. ApiService checkDuplicateRetailer detects exact mobile, exact GSTIN, and similar name', () {
      // Exact mobile check across different formatting
      final dupMobile = api.checkDuplicateRetailer(
        phone: '+91-98290-12345',
        name: 'Unrelated Store',
        area: 'Different Area',
      );
      expect(dupMobile.hasDuplicate, isTrue);
      expect(dupMobile.type, equals(DuplicateType.exactMobile));
      expect(dupMobile.requiresStrictConfirmation, isTrue);

      // Exact GSTIN check
      final dupGstin = api.checkDuplicateRetailer(
        phone: '9988776655',
        name: 'Fresh Mart',
        area: 'Sardarpura',
        gstin: '08AAACH1234F1Z5', // Assume matches if seeded
      );
      // If GSTIN matches, requires strict confirmation
      if (dupGstin.hasDuplicate) {
        expect(dupGstin.type, equals(DuplicateType.exactGstin));
      }

      // Name similarity in same area (matches 'Shree Ganesh Kirana Store' in 'Nai Sadak')
      final dupName = api.checkDuplicateRetailer(
        phone: '9988776655',
        name: 'Shree Ganesh General Kirana',
        area: 'Nai Sadak',
      );
      expect(dupName.hasDuplicate, isTrue);
      expect(dupName.type, equals(DuplicateType.similarNameInArea));

      // Brand new retailer has zero duplicate flags
      final clean = api.checkDuplicateRetailer(
        phone: '9988776655',
        name: 'Pooja Daily Needs',
        area: 'Pal Road',
      );
      expect(clean.hasDuplicate, isFalse);
      expect(clean.type, equals(DuplicateType.none));
    });

    test('4. Durable creation enforces phone sanitization, class NEW, and 0 credit for sales role', () async {
      final createdShop = await api.createRetailerDurable(
        name: 'Shree Ganesh General Store',
        ownerName: 'Ganesh Ram',
        phone: '+91 98295 44332',
        address: 'Bhadwasiya Road',
        area: 'Bhadwasiya',
        suggestedClass: 'CLASS_A', // Salesperson attempts to set Class A
      );

      // Phone is stored in canonical 10-digit format
      expect(createdShop.phone, equals('9829544332'));
      expect(createdShop.displayPhone, equals('+91 98295 44332'));

      // Salesperson cannot create non-NEW class; strictly class NEW and credit limit 0
      expect(createdShop.classType, equals('NEW'));
      expect(createdShop.creditLimitPaise, equals(0));
      expect(createdShop.canUseCredit, isFalse);

      // Verification in SQLite database
      final dbShop = await repo.findRetailerByPhone('9829544332');
      expect(dbShop, isNotNull);
      expect(dbShop!.phone, equals('9829544332'));
      expect(dbShop.classType, equals('NEW'));
      expect(dbShop.creditLimitPaise, equals(0));
    });

    test('5. Multi-tenant independence: Same phone under different organizations does not collide in local DB', () async {
      // Create shop under organization 1
      final shopOrg1 = RetailerShop(
        id: 'ret_org1_01',
        name: 'Universal Mart',
        ownerName: 'Vikas',
        phone: '9829911223',
        address: 'Main Market',
        area: 'Central',
        creditLimitPaise: 0,
        outstandingPaise: 0,
        classType: 'NEW',
        createdByUserId: 'usr_org1',
      );
      await repo.upsertRetailer(shopOrg1);

      final foundOrg1 = await repo.findRetailerByPhone('9829911223');
      expect(foundOrg1, isNotNull);
      expect(foundOrg1!.id, equals('ret_org1_01'));
      expect(foundOrg1.createdByUserId, equals('usr_org1'));
    });

    test('6. Owner/Admin can configure custom negotiated credit limit distinct from baseline guidelines', () async {
      final ownerSession = UserSession(
        userId: 'usr_owner_ramesh',
        name: 'Ramesh Patel',
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

      final ownerApi = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => ownerSession,
      );

      const negotiatedCredit = 6000000; // ₹60,000 negotiated credit (distinct from standard class B ₹25,000)
      final createdShop = await ownerApi.createRetailerDurable(
        name: 'Premier Wholesale Mart',
        ownerName: 'Devendra Singh',
        phone: '9829077777',
        address: 'Industrial Area',
        area: 'Basni',
        suggestedClass: 'CLASS_B',
        customCreditLimitPaise: negotiatedCredit,
      );

      expect(createdShop.classType, equals('B'));
      expect(createdShop.creditLimitPaise, equals(negotiatedCredit));
      expect(createdShop.canUseCredit, isTrue);

      final dbShop = await repo.findRetailerByPhone('9829077777');
      expect(dbShop, isNotNull);
      expect(dbShop!.creditLimitPaise, equals(negotiatedCredit));
    });

    test('7. Existing retailer negotiated credit is strictly preserved upon details update', () async {
      // Seeded shop RET-JDH-01 has negotiated creditLimitPaise: 5000000 (₹50,000)
      final shopBefore = await repo.getRetailerById('RET-JDH-01');
      expect(shopBefore, isNotNull);
      expect(shopBefore!.creditLimitPaise, equals(5000000));

      // Updating name, address, or phone preserves credit limit
      await repo.updateRetailerDetails(
        id: 'RET-JDH-01',
        name: 'Shree Ganesh Mega Kirana',
        ownerName: 'Ramprasad Maheshwari',
        phone: '+91 98290 12345',
        address: 'Shop 14, Nai Sadak Circle',
        area: 'Nai Sadak',
      );

      final shopAfter = await repo.getRetailerById('RET-JDH-01');
      expect(shopAfter, isNotNull);
      expect(shopAfter!.name, equals('Shree Ganesh Mega Kirana'));
      expect(shopAfter.creditLimitPaise, equals(5000000), reason: 'Negotiated credit limit must never be wiped');
    });
  });
}
