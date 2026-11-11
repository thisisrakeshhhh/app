import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/auth/auth_repository.dart';
import 'package:lala_distributor/data/auth/secure_token_storage.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/tenant_boundary_gate.dart';
import 'package:lala_distributor/features/sales/screens/sales_earn_view.dart';
import 'package:lala_distributor/features/sales/screens/sales_more_view.dart';
import 'package:lala_distributor/features/sales/screens/sales_shell.dart';
import 'package:lala_distributor/l10n/app_language.dart';
import 'package:lala_distributor/l10n/language_controller.dart';
import 'package:lala_distributor/screens/dashboards/admin_dashboard.dart';
import 'package:lala_distributor/screens/dashboards/delivery_dashboard.dart';
import 'package:lala_distributor/screens/dashboards/sales_dashboard.dart';
import 'package:lala_distributor/screens/dashboards/warehouse_dashboard.dart';
import 'package:lala_distributor/screens/role_shell.dart';
import 'package:lala_distributor/screens/views/sales_subviews.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/services/auth_service.dart';

void main() {
  const testBaseUrl = 'https://routeflow-api-staging.workers.dev';

  String makeJwt({String companyId = 'comp_jodhpur', required String role, required String name}) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'usr_isolation_test',
      'name': name,
      'company_id': companyId,
      'role': role,
      'exp': exp,
    })));
    return '$header.$payload.fake_sig';
  }

  group('RouteFlow Role Isolation & Sales V2 Shell Tests', () {
    late AppDatabase db;
    late LocalRepository repo;
    late ApiService api;

    setUp(() {
      LanguageController.instance.setLanguage(AppLanguage.en);
      db = AppDatabase(NativeDatabase.memory());
      repo = LocalRepository(db);
      api = ApiService.internalForTesting(database: db, localRepo: repo, seed: true);
    });

    tearDown(() async {
      await db.close();
    });

    AuthService createAuthWithRole(String role, String name) {
      final jwt = makeJwt(role: role, name: name);
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'refresh_$role',
            'user': {'id': 'usr_$role', 'name': name, 'company_id': 'comp_jodhpur', 'role': role},
            'organizations': [{'id': 'comp_jodhpur', 'name': 'Jodhpur FMCG Depot', 'role': role}],
          }),
          200,
        );
      });

      final authRepo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final storage = InMemoryTokenStorage();
      return AuthService(
        repository: authRepo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );
    }

    testWidgets('1. OWNER role never mounts SalesShell or sales tabs', (tester) async {
      final authService = createAuthWithRole('OWNER', 'Rakesh Agarwal');
      await authService.login('dist_owner', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService, salesV2Enabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboard), findsOneWidget);
      expect(find.byType(SalesShell), findsNothing);
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.text('Shops'), findsNothing);
      expect(find.text('Earn'), findsNothing);
    });

    testWidgets('2. ADMIN role never mounts SalesShell or sales tabs', (tester) async {
      final authService = createAuthWithRole('ADMIN', 'Rajesh Sharma');
      await authService.login('dist_admin', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService, salesV2Enabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboard), findsOneWidget);
      expect(find.byType(SalesShell), findsNothing);
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.text('Shops'), findsNothing);
      expect(find.text('Earn'), findsNothing);
    });

    testWidgets('3. WAREHOUSE role never mounts SalesShell or sales tabs', (tester) async {
      final authService = createAuthWithRole('WAREHOUSE', 'Mukesh Godown');
      await authService.login('warehouse_user', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService, salesV2Enabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WarehouseDashboard), findsOneWidget);
      expect(find.byType(SalesShell), findsNothing);
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.text('Shops'), findsNothing);
      expect(find.text('Earn'), findsNothing);
    });

    testWidgets('4. DELIVERY role never mounts SalesShell or sales tabs', (tester) async {
      final authService = createAuthWithRole('DELIVERY', 'Suresh Driver');
      await authService.login('delivery_user', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService, salesV2Enabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryDashboard), findsOneWidget);
      expect(find.byType(SalesShell), findsNothing);
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.text('Shops'), findsNothing);
      expect(find.text('Earn'), findsNothing);
    });

    testWidgets('5. SALES role with salesV2Enabled=true mounts SalesShell with 4 tabs', (tester) async {
      final authService = createAuthWithRole('SALES', 'Vikram Rathore');
      await authService.login('sales_rep', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService, salesV2Enabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SalesShell), findsOneWidget);
      expect(find.byType(SalesDashboard), findsOneWidget);

      // Verify the 4 bottom navigation tabs are present
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Shops'), findsOneWidget);
      expect(find.text('Earn'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Verify other dashboards do not exist
      expect(find.byType(AdminDashboard), findsNothing);
      expect(find.byType(WarehouseDashboard), findsNothing);
      expect(find.byType(DeliveryDashboard), findsNothing);
    });

    testWidgets('6. SALES role with salesV2Enabled=false falls back to legacy 5 tabs', (tester) async {
      final authService = createAuthWithRole('SALES', 'Vikram Rathore');
      await authService.login('sales_rep', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService, salesV2Enabled: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SalesShell), findsNothing);
      expect(find.byType(SalesDashboard), findsOneWidget);

      // Verify the legacy 5 bottom navigation tabs are present
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('New Order'), findsWidgets);
      expect(find.text('Retailers'), findsWidgets);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('My Visits'), findsWidgets);
    });

    testWidgets('7. SalesShell tab switching navigates between Today, Shops, Earn, More', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SalesShell(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Starts at Today
      expect(find.byType(SalesDashboard), findsOneWidget);

      // Tap Shops
      await tester.tap(find.text('Shops'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesRetailersView), findsOneWidget);

      // Tap Earn
      await tester.tap(find.text('Earn'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesEarnView), findsOneWidget);
      expect(find.text('My Earnings & Performance'), findsOneWidget);

      // Tap More
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesMoreView), findsOneWidget);
      expect(find.text('Order History'), findsOneWidget);
      expect(find.text('Visits History'), findsOneWidget);
      expect(find.text('Rate List & Products'), findsOneWidget);
    });

    test('8. Feature flag persistence in local repository', () async {
      expect(api.salesV2Enabled, isFalse);
      api.setSalesV2Enabled(true);
      expect(api.salesV2Enabled, isTrue);

      final persisted = await repo.getMetadata('sales_v2_enabled');
      expect(persisted, 'true');

      api.setSalesV2Enabled(false);
      expect(api.salesV2Enabled, isFalse);
      final persistedFalse = await repo.getMetadata('sales_v2_enabled');
      expect(persistedFalse, 'false');
    });

    test('9. TenantBoundaryGate purgeLegacyQuarantine resets state to cleanEmpty', () async {
      final gate = TenantBoundaryGate(db);
      await gate.purgeLegacyQuarantine();
      final assessment = await gate.assessBoundary();
      expect(assessment.isBlocked, isFalse);
      expect(assessment.unassignedRecordCount, equals(0));
    });

    test('10. Owner staff management: createStaffMember assigns role and credentials', () async {
      final initialCount = api.staffList.length;
      final created = await api.createStaffMember(
        fullName: 'Ramesh Kumar',
        username: 'ramesh_sales',
        password: 'RouteFlow@2026!',
        role: 'SALES',
        beatId: 'Sardarpura Market',
      );
      expect(created, isTrue);
      expect(api.staffList.length, equals(initialCount + 1));
      final member = api.staffList.firstWhere((s) => s.username == 'ramesh_sales');
      expect(member.fullName, equals('Ramesh Kumar'));
      expect(member.role, equals('SALES'));
      expect(member.isActive, isTrue);

      // Toggle status
      await api.toggleStaffStatus(member.id);
      final updated = api.staffList.firstWhere((s) => s.username == 'ramesh_sales');
      expect(updated.isActive, isFalse);
    });

    test('11. Owner Godown analytics & profit calculation', () {
      expect(api.totalGodownBoxes, greaterThan(0));
      expect(api.totalGodownValuationRupees, greaterThan(0));
      expect(api.totalGodownEstimatedProfitRupees, greaterThan(0));

      final firstProduct = api.products.first;
      final margin = api.getProductMarginPercent(firstProduct);
      expect(margin, greaterThanOrEqualTo(0.0));
      expect(margin, lessThanOrEqualTo(100.0));
    });
  });
}
