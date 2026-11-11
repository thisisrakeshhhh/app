import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/auth/auth_repository.dart';
import 'package:lala_distributor/data/auth/secure_token_storage.dart';
import 'package:lala_distributor/domain/auth/tenant_boundary_gate.dart';
import 'package:lala_distributor/screens/login_view.dart';
import 'package:lala_distributor/screens/organization_select_view.dart';
import 'package:lala_distributor/services/auth_service.dart';
import 'package:lala_distributor/theme/airbnb_theme.dart';

void main() {
  const testBaseUrl = 'https://routeflow-api-staging.workers.dev';

  String makeJwt({String companyId = 'comp_jodhpur', String role = 'SALES'}) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'usr_ui_test',
      'name': 'UI Tester',
      'company_id': companyId,
      'role': role,
      'exp': exp,
    })));
    return '$header.$payload.fake_sig';
  }

  group('Auth UI & Organization Switching Widget Tests', () {
    testWidgets('1. LoginView renders branded elements, input fields and debug chips', (tester) async {
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: MockClient((_) async => http.Response('', 200)));
      final storage = InMemoryTokenStorage();
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AirbnbTheme.lightTheme,
          home: LoginView(authService: authService),
        ),
      );

      expect(find.text('ROUTIDROW'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Debug Quick-Fill'), findsOneWidget);
      expect(find.text('Sales Rep'), findsOneWidget);
      expect(find.text('Distributor Admin'), findsOneWidget);
    });

    testWidgets('2. LoginView validates empty inputs', (tester) async {
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: MockClient((_) async => http.Response('', 200)));
      final storage = InMemoryTokenStorage();
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AirbnbTheme.lightTheme,
          home: LoginView(authService: authService),
        ),
      );

      // Tap Sign In without entering credentials
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('3. LoginView debug chip populates username and user submits credentials', (tester) async {
      final jwt = makeJwt();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'demo_refresh_token',
            'user': {'id': 'usr_demo', 'name': 'Demo Rep', 'company_id': 'comp_jodhpur', 'role': 'SALES'},
            'organizations': [{'id': 'comp_jodhpur', 'name': 'Jodhpur Depot', 'role': 'SALES'}],
          }),
          200,
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final storage = InMemoryTokenStorage();
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      var loginCallbackTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AirbnbTheme.lightTheme,
          home: LoginView(
            authService: authService,
            onLoginSuccess: () => loginCallbackTriggered = true,
          ),
        ),
      );

      // Tap 'Sales Rep' debug chip
      await tester.tap(find.text('Sales Rep'));
      await tester.pump();

      expect(find.text('sales_rep'), findsOneWidget);

      // Enter password
      await tester.enterText(find.byType(TextFormField).at(1), 'valid_pass_123');
      await tester.pump();

      // Tap Sign In
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(authService.isAuthenticated, isTrue);
      expect(loginCallbackTriggered, isTrue);
    });

    testWidgets('4. OrganizationSelectSheet displays active membership and locks unmigrated tenants behind Phase B2.2', (tester) async {
      final jodhpurJwt = makeJwt(companyId: 'comp_jodhpur', role: 'SALES');

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'access_token': jodhpurJwt,
              'refresh_token': 'ref_test',
              'user': {'id': 'usr_1', 'name': 'User 1', 'company_id': 'comp_jodhpur', 'role': 'SALES'},
              'organizations': [
                {'id': 'comp_jodhpur', 'name': 'Jodhpur FMCG Hub', 'role': 'SALES'},
                {'id': 'comp_jaipur', 'name': 'Jaipur Logistics Hub', 'role': 'WAREHOUSE'},
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final storage = InMemoryTokenStorage();
      final authService = AuthService(
        repository: HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient),
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.login('user', 'pass');

      await tester.pumpWidget(
        MaterialApp(
          theme: AirbnbTheme.lightTheme,
          home: Scaffold(
            body: OrganizationSelectSheet(authService: authService),
          ),
        ),
      );

      expect(find.text('Distributor Organizations'), findsOneWidget);
      expect(find.text('Jodhpur FMCG Hub'), findsOneWidget);
      expect(find.text('Jaipur Logistics Hub'), findsOneWidget);

      // Active org has check circle
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Non-active org has lock badge
      expect(find.text('B2.2 Scope'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      // Tap Jaipur triggers safe blocked notice
      await tester.tap(find.text('Jaipur Logistics Hub'));
      await tester.pumpAndSettle();

      // Error message indicates B2.2 scope deferral
      expect(find.textContaining('Phase B2.2'), findsOneWidget);
      // Active org remains unchanged
      expect(authService.session?.activeOrganizationId, 'comp_jodhpur');
    });
  });
}
