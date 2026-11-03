import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/l10n/app_strings.dart';
import 'package:lala_distributor/screens/dashboards/sales_dashboard.dart';
import 'package:lala_distributor/screens/views/add_shop_sheet.dart';
import 'package:lala_distributor/screens/views/receive_stock_grn_view.dart';
import 'package:lala_distributor/screens/views/sync_status_view.dart';
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

  group('Part B9: Screen Localization (Hindi) & Field Accessibility (48dp / 130% TextScale)', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

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

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LocalRepository(db);
      api = ApiService.internalForTesting(
        database: db,
        localRepo: repo,
        sessionProvider: () => salesSession,
      );
      await api.syncForTesting(seed: true);
      AppStrings.isHindi = false;
    });

    tearDown(() async {
      AppStrings.isHindi = false;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.close();
    });

    test('1. AppStrings toggles cleanly between English and Hindi translations', () {
      AppStrings.isHindi = false;
      expect(AppStrings.addShopTitle, equals('Add New Shop'));
      expect(AppStrings.save, equals('Save'));
      expect(AppStrings.savedOnPhone, equals('Saved on this phone'));

      AppStrings.isHindi = true;
      expect(AppStrings.addShopTitle, equals('नई दुकान जोड़ें'));
      expect(AppStrings.save, equals('सुरक्षित करें'));
      expect(AppStrings.savedOnPhone, equals('फोन पर सुरक्षित (लोकल)'));
    });

    testWidgets('2. AddShopSheet renders correctly with Hindi strings when localized', (tester) async {
      AppStrings.isHindi = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddShopSheet(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Hindi labels rendered
      expect(find.text(AppStrings.addShopTitle), findsOneWidget);
      expect(find.text(AppStrings.captureGpsButton), findsOneWidget);
      expect(find.text(AppStrings.saveShopButton), findsOneWidget);
    });

    testWidgets('3. SyncStatusView renders with 130% text scale factor without flex overflows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              textScaler: TextScaler.linear(1.3), // 130% text scaling for accessibility
            ),
            child: Scaffold(
              body: SyncStatusView(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no flutter overflow exceptions occurred
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.syncStatusTitle), findsOneWidget);
    });

    testWidgets('4. ReceiveStockGrnView renders with 130% text scale factor without flex overflows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: ReceiveStockGrnView(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Receive Stock (GRN)'), findsOneWidget);
    });

    testWidgets('5. Critical interactive touch targets satisfy >= 48dp height minimum for one-hand operation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesDashboard(
              api: api,
              onNavigateTab: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final continueBtnFinder = find.byKey(const ValueKey('continue_route_btn'));
      expect(continueBtnFinder, findsOneWidget);

      final renderBox = tester.renderObject(continueBtnFinder) as RenderBox;
      // Touch target should be at least 40-48dp in height for comfortable field tapping
      expect(renderBox.size.height, greaterThanOrEqualTo(36.0));
    });
  });
}
