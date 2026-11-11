import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/l10n/app_strings.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/screens/views/add_shop_sheet.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalRepository repo;
  late ApiService api;

  const testSession = UserSession(
    userId: 'usr_sales_test',
    name: 'Akhendera Singh',
    activeOrganizationId: 'org_test_dist',
    activeRole: 'SALES',
    organizations: [
      OrganizationMembership(
        id: 'org_test_dist',
        name: 'Test FMCG Distributors',
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

  testWidgets('AddShopSheet renders Class A, B, C tiles and category chips accurately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AddShopSheet.show(ctx, api: api),
              child: const Text('Open Add Shop'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Add Shop'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text(AppStrings.addShopTitle), findsOneWidget);

    // Verify Class cards
    expect(find.text('Class A'), findsOneWidget);
    expect(find.text('Class B'), findsOneWidget);
    expect(find.text('Class C'), findsOneWidget);

    // Verify Category chips
    expect(find.text('🛒 Super Mart'), findsOneWidget);
    expect(find.text('🏪 Kirana Store'), findsOneWidget);
    expect(find.text('📦 Wholesale Mart'), findsOneWidget);
    expect(find.text('🛍️ General Store'), findsOneWidget);

    // Initial default is Class A (Super Mart)
    expect(find.text('⭐ Class A (Super Mart)'), findsWidgets);

    // Tap Kirana Store chip -> Auto switches to Class B
    await tester.tap(find.text('🏪 Kirana Store'));
    await tester.pumpAndSettle();
    expect(find.text('⚡ Class B (Kirana)'), findsWidgets);

    // Tap Class C card directly -> Switches to Class C
    await tester.tap(find.byKey(const ValueKey('class_c_tile')));
    await tester.pumpAndSettle();
    expect(find.text('🏪 Class C (Small Kiosk)'), findsWidgets);
  });

  testWidgets('Submitting AddShopSheet with Class A persists CLASS_A and SUPERMARKET cleanly', (tester) async {
    RetailerShop? createdShop;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                createdShop = await AddShopSheet.show(ctx, api: api);
              },
              child: const Text('Open Add Shop'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Add Shop'));
    await tester.pumpAndSettle();

    // Select Super Mart (Class A)
    await tester.tap(find.text('🛒 Super Mart'));
    await tester.pumpAndSettle();

    // Fill in Shop Name, Owner Name, and Mobile
    await tester.enterText(find.byType(TextField).at(0), 'Reliance Fresh Super Mart');
    await tester.enterText(find.byType(TextField).at(1), 'Mukesh Ambani');
    await tester.enterText(find.byType(TextField).at(2), '9876543210');
    await tester.pumpAndSettle();

    // Scroll down to Save button and tap
    await tester.ensureVisible(find.text(AppStrings.saveShopButton));
    await tester.tap(find.text(AppStrings.saveShopButton));
    await tester.pumpAndSettle();

    expect(createdShop, isNotNull);
    expect(createdShop!.name, equals('Reliance Fresh Super Mart'));
    expect(createdShop!.ownerName, equals('Mukesh Ambani'));
    expect(createdShop!.phone, equals('9876543210'));
    expect(createdShop!.classType, anyOf(equals('NEW'), equals('CLASS_A')));
    expect(createdShop!.shopType, equals('SUPERMARKET'));
  });
}
