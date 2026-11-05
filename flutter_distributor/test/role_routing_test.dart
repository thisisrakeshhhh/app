import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/auth/auth_repository.dart';
import 'package:lala_distributor/data/auth/secure_token_storage.dart';
import 'package:lala_distributor/domain/auth/role_routing.dart';
import 'package:lala_distributor/domain/auth/tenant_boundary_gate.dart';
import 'package:lala_distributor/l10n/app_language.dart';
import 'package:lala_distributor/l10n/language_controller.dart';
import 'package:lala_distributor/screens/dashboards/admin_dashboard.dart';
import 'package:lala_distributor/screens/dashboards/delivery_dashboard.dart';
import 'package:lala_distributor/screens/dashboards/role_blocked_view.dart';
import 'package:lala_distributor/screens/dashboards/sales_dashboard.dart';
import 'package:lala_distributor/screens/dashboards/warehouse_dashboard.dart';
import 'package:lala_distributor/screens/role_shell.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'package:lala_distributor/services/auth_service.dart';

void main() {
  const testBaseUrl = 'https://routeflow-api-staging.workers.dev';

  String makeJwt({String companyId = 'comp_jodhpur', required String role, required String name}) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'usr_role_test',
      'name': name,
      'company_id': companyId,
      'role': role,
      'exp': exp,
    })));
    return '$header.$payload.fake_sig';
  }

  group('RouteFlow Role Routing & Permission Matrix Tests', () {
    test('1. Role alias normalization maps to canonical roles', () {
      expect(CanonicalRole.fromString('SALES'), CanonicalRole.sales);
      expect(CanonicalRole.fromString('salesperson'), CanonicalRole.sales);
      expect(CanonicalRole.fromString('SALES_REP'), CanonicalRole.sales);

      expect(CanonicalRole.fromString('WAREHOUSE'), CanonicalRole.warehouse);
      expect(CanonicalRole.fromString('warehouse_manager'), CanonicalRole.warehouse);
      expect(CanonicalRole.fromString('INVENTORY'), CanonicalRole.warehouse);
      expect(CanonicalRole.fromString('inventory_mgr'), CanonicalRole.warehouse);

      expect(CanonicalRole.fromString('DELIVERY'), CanonicalRole.delivery);
      expect(CanonicalRole.fromString('delivery_executive'), CanonicalRole.delivery);
      expect(CanonicalRole.fromString('LOGISTICS'), CanonicalRole.delivery);
      expect(CanonicalRole.fromString('delivery_driver'), CanonicalRole.delivery);

      expect(CanonicalRole.fromString('ADMIN'), CanonicalRole.admin);
      expect(CanonicalRole.fromString('distributor_admin'), CanonicalRole.admin);
      expect(CanonicalRole.fromString('OPERATIONS_ADMIN'), CanonicalRole.admin);

      expect(CanonicalRole.fromString('OWNER'), CanonicalRole.owner);
      expect(CanonicalRole.fromString('distributor_owner'), CanonicalRole.owner);
      expect(CanonicalRole.fromString('DISTRIBUTOR_OWNER'), CanonicalRole.owner);
    });

    test('2. Unknown or unauthorized roles fail closed to null', () {
      expect(CanonicalRole.fromString(null), isNull);
      expect(CanonicalRole.fromString(''), isNull);
      expect(CanonicalRole.fromString('GUEST'), isNull);
      expect(CanonicalRole.fromString('SUPERUSER'), isNull);
      expect(CanonicalRole.fromString('ATTACKER'), isNull);
    });

    test('3. Permission matrix enforces role boundaries', () {
      // Sales
      expect(roleHasPermission(CanonicalRole.sales, RolePermission.createSalesOrders), isTrue);
      expect(roleHasPermission(CanonicalRole.sales, RolePermission.recordVisitCheckIn), isTrue);
      expect(roleHasPermission(CanonicalRole.sales, RolePermission.adjustGodownStock), isFalse);
      expect(roleHasPermission(CanonicalRole.sales, RolePermission.verifyDeliveryOtp), isFalse);

      // Warehouse
      expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.adjustGodownStock), isTrue);
      expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.pickAndPackOrders), isTrue);
      expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.createSalesOrders), isFalse);
      expect(roleHasPermission(CanonicalRole.warehouse, RolePermission.recordCashCollection), isFalse);

      // Delivery
      expect(roleHasPermission(CanonicalRole.delivery, RolePermission.verifyDeliveryOtp), isTrue);
      expect(roleHasPermission(CanonicalRole.delivery, RolePermission.recordCashCollection), isTrue);
      expect(roleHasPermission(CanonicalRole.delivery, RolePermission.createSalesOrders), isFalse);
      expect(roleHasPermission(CanonicalRole.delivery, RolePermission.manageProducts), isFalse);

      // Admin
      expect(roleHasPermission(CanonicalRole.admin, RolePermission.viewOrgOverview), isTrue);
      expect(roleHasPermission(CanonicalRole.admin, RolePermission.manageProducts), isTrue);
      expect(roleHasPermission(CanonicalRole.admin, RolePermission.viewReports), isTrue);
      // Admin cannot execute sovereign financial governance
      expect(roleHasPermission(CanonicalRole.admin, RolePermission.modifyCreditLimits), isFalse);
      expect(roleHasPermission(CanonicalRole.admin, RolePermission.settleDriverCash), isFalse);
      expect(roleHasPermission(CanonicalRole.admin, RolePermission.viewFinancialProfitLedger), isFalse);
      expect(roleHasPermission(CanonicalRole.admin, RolePermission.authorizeStockWriteOff), isFalse);

      // Owner has complete sovereign authority across all operations and finance
      expect(roleHasPermission(CanonicalRole.owner, RolePermission.modifyCreditLimits), isTrue);
      expect(roleHasPermission(CanonicalRole.owner, RolePermission.settleDriverCash), isTrue);
      expect(roleHasPermission(CanonicalRole.owner, RolePermission.viewFinancialProfitLedger), isTrue);
      expect(roleHasPermission(CanonicalRole.owner, RolePermission.authorizeStockWriteOff), isTrue);
      expect(roleHasPermission(CanonicalRole.owner, RolePermission.createSalesOrders), isTrue);
      expect(roleHasPermission(CanonicalRole.owner, RolePermission.adjustGodownStock), isTrue);
      expect(roleHasPermission(CanonicalRole.owner, RolePermission.verifyDeliveryOtp), isTrue);
    });

    test('4. assertRolePermission throws RoleAuthorizationException when permission missing', () {
      expect(
        () => assertRolePermission(CanonicalRole.sales, RolePermission.adjustGodownStock),
        throwsA(isA<RoleAuthorizationException>()),
      );

      expect(
        () => assertRolePermission(CanonicalRole.warehouse, RolePermission.createSalesOrders),
        throwsA(isA<RoleAuthorizationException>()),
      );

      expect(
        () => assertRolePermission(CanonicalRole.sales, RolePermission.createSalesOrders),
        returnsNormally,
      );
    });
  });

  group('RouteFlow RoleShell Widget & Dashboard Routing Tests', () {
    late ApiService api;

    setUp(() {
      LanguageController.instance.setLanguage(AppLanguage.en);
      api = ApiService();
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

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final storage = InMemoryTokenStorage();
      return AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );
    }

    testWidgets('5. SALES role mounts SalesDashboard with 5 sales tabs', (tester) async {
      final authService = createAuthWithRole('SALES', 'Vikram Rathore');
      await authService.login('sales_rep', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      // Check App Bar Role Badge & Name
      expect(find.text('SALES'), findsWidgets);
      expect(find.text('Vikram Rathore'), findsOneWidget);

      // Check Sales Dashboard Landing Content
      expect(find.byType(SalesDashboard), findsOneWidget);
      expect(find.text("TODAY'S ASSIGNED BEAT"), findsOneWidget);
      expect(find.text('Booked Orders'), findsOneWidget);

      // Check 5 Sales Navigation Items & Quick Actions
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('New Order'), findsWidgets);
      expect(find.text('Retailers'), findsWidgets);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('My Visits'), findsWidgets);

      // Verify no other dashboard or manual role picker exists
      expect(find.byType(WarehouseDashboard), findsNothing);
      expect(find.byType(DeliveryDashboard), findsNothing);
      expect(find.byType(AdminDashboard), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('6. WAREHOUSE role mounts WarehouseDashboard with 5 warehouse tabs', (tester) async {
      final authService = createAuthWithRole('WAREHOUSE', 'Mukesh Godown');
      await authService.login('inventory_mgr', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      // Check App Bar Role Badge & Name
      expect(find.text('WAREHOUSE'), findsWidgets);
      expect(find.text('Mukesh Godown'), findsOneWidget);

      // Check Warehouse Dashboard Landing Content
      expect(find.byType(WarehouseDashboard), findsOneWidget);
      expect(find.text('CENTRAL FMCG GODOWN'), findsOneWidget);
      expect(find.textContaining('Basni Industrial Area Phase II'), findsOneWidget);
      expect(find.text('Godown Stock'), findsWidgets);

      // Check 5 Warehouse Navigation Items
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Godown Stock'), findsWidgets);
      expect(find.text('Inward'), findsWidgets);
      expect(find.text('Pick & Pack'), findsWidgets);
      expect(find.text('Load Van'), findsOneWidget);

      // Verify no other dashboard or manual role switcher exists
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.byType(DeliveryDashboard), findsNothing);
      expect(find.byType(AdminDashboard), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('7. DELIVERY role mounts DeliveryDashboard with 5 delivery tabs', (tester) async {
      final authService = createAuthWithRole('DELIVERY', 'Suresh Yadav');
      await authService.login('delivery_driver', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      // Check App Bar Role Badge & Name
      expect(find.text('DELIVERY'), findsWidgets);
      expect(find.text('Suresh Yadav'), findsOneWidget);

      // Check Delivery Dashboard Landing Content
      expect(find.byType(DeliveryDashboard), findsOneWidget);
      expect(find.text('ASSIGNED DELIVERY VEHICLE'), findsOneWidget);
      expect(find.text('Cash Custody'), findsOneWidget);

      // Check 5 Delivery Navigation Items
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Trips'), findsWidgets);
      expect(find.text('Stops'), findsOneWidget);
      expect(find.text('Collections'), findsWidgets);
      expect(find.text('Handover'), findsWidgets);

      // Verify no other dashboard exists
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.byType(WarehouseDashboard), findsNothing);
      expect(find.byType(AdminDashboard), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('8. ADMIN role mounts AdminDashboard with 7 admin tabs', (tester) async {
      final authService = createAuthWithRole('ADMIN', 'Rajesh Sharma');
      await authService.login('dist_admin', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      // Check App Bar Role Badge & Name
      expect(find.text('ADMIN'), findsWidgets);
      expect(find.text('Rajesh Sharma'), findsOneWidget);

      // Check Admin Dashboard Landing Content
      expect(find.byType(AdminDashboard), findsOneWidget);
      expect(find.text('DISTRIBUTOR EXECUTIVE OVERVIEW'), findsOneWidget);
      expect(find.textContaining('Delivered Sales Turnover'), findsOneWidget);
      expect(find.text('ESTIMATE ONLY'), findsOneWidget);

      // Check Admin Navigation Items
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Retailers'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);

      // Verify no other dashboard exists
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.byType(WarehouseDashboard), findsNothing);
      expect(find.byType(DeliveryDashboard), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('8b. OWNER role mounts Control Room with 7 tabs and OWNER badge', (tester) async {
      final authService = createAuthWithRole('OWNER', 'Rakesh Agarwal');
      await authService.login('dist_owner', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      // Check App Bar Role Badge & Name
      expect(find.text('OWNER'), findsWidgets);
      expect(find.text('Rakesh Agarwal'), findsOneWidget);

      // Check Dashboard Landing Content
      expect(find.byType(AdminDashboard), findsOneWidget);
      expect(find.text('DISTRIBUTOR EXECUTIVE OVERVIEW'), findsOneWidget);
      expect(find.textContaining('Delivered Sales Turnover'), findsOneWidget);

      // Check Navigation Items
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Retailers'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);

      // Verify no other dashboard exists
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.byType(WarehouseDashboard), findsNothing);
      expect(find.byType(DeliveryDashboard), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('9. Unknown role fails closed to RoleBlockedView', (tester) async {
      final authService = createAuthWithRole('UNSUPPORTED_ROLE_XYZ', 'Unknown User');
      await authService.login('test_unknown', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RoleBlockedView), findsOneWidget);
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Role Not Authorized'), findsOneWidget);
      expect(find.textContaining('FAIL-CLOSED POLICY'), findsOneWidget);

      // Verify no dashboard is rendered
      expect(find.byType(SalesDashboard), findsNothing);
      expect(find.byType(WarehouseDashboard), findsNothing);
      expect(find.byType(DeliveryDashboard), findsNothing);
      expect(find.byType(AdminDashboard), findsNothing);
    });

    testWidgets('10. Logout button terminates session and returns unauthenticated', (tester) async {
      final authService = createAuthWithRole('SALES', 'Vikram Rathore');
      await authService.login('sales_rep', 'RouteFlow@2026!');

      await tester.pumpWidget(
        MaterialApp(
          home: RoleShell(api: api, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(authService.isAuthenticated, isTrue);

      // Tap logout icon button
      final logoutBtn = find.byTooltip('Sign Out');
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(authService.isAuthenticated, isFalse);
    });
  });
}
