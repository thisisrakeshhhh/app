import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/auth/auth_exceptions.dart';
import '../../domain/auth/auth_models.dart';
import '../../domain/auth/token_refresh_coordinator.dart';

/// Response payload from successful login.
class AuthLoginResponse {
  final String accessToken;
  final String refreshToken;
  final UserSession session;
  final DateTime? expiresAt;

  const AuthLoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.session,
    this.expiresAt,
  });
}

/// Response payload from successful organization switch.
class AuthSwitchOrgResponse {
  final String accessToken;
  final String organizationId;
  final String role;
  final DateTime? expiresAt;

  const AuthSwitchOrgResponse({
    required this.accessToken,
    required this.organizationId,
    required this.role,
    this.expiresAt,
  });
}

/// Contract for backend authentication operations.
abstract class AuthRepository {
  Future<AuthLoginResponse> login({
    required String username,
    required String password,
    String? deviceId,
  });

  Future<TokenRefreshResult> refreshToken({
    required String refreshToken,
  });

  Future<AuthSwitchOrgResponse> switchOrganization({
    required String organizationId,
    required String accessToken,
  });

  Future<void> logout({
    required String accessToken,
  });

  Future<Map<String, dynamic>> getCurrentUser({
    required String accessToken,
  });
}

/// Concrete implementation communicating with RouteFlow Cloudflare Worker backend.
class HttpAuthRepository implements AuthRepository {
  final String baseUrl;
  final http.Client _client;

  HttpAuthRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Parse JWT expiration claim if present, returning DateTime or null.
  static DateTime? parseTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      if (json.containsKey('exp') && json['exp'] is int) {
        return DateTime.fromMillisecondsSinceEpoch((json['exp'] as int) * 1000);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthLoginResponse> login({
    required String username,
    required String password,
    String? deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final payload = {
      'username': username.trim(),
      'password': password,
      'device_id': deviceId ?? 'flutter_device_b2',
    };

    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } on SocketException catch (_) {
      if (kDebugMode && _isDemoUser(username)) {
        return _buildDebugDemoResponse(username);
      }
      throw const NetworkUnavailableException('Unable to reach authentication server');
    } on http.ClientException catch (_) {
      if (kDebugMode && _isDemoUser(username)) {
        return _buildDebugDemoResponse(username);
      }
      throw const NetworkUnavailableException('Network error during login request');
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final userObj = data['user'] as Map<String, dynamic>?;

        if (accessToken == null || refreshToken == null || userObj == null) {
          throw const MalformedTokenException('Login response missing required token or user fields');
        }

        final orgsRaw = data['organizations'] as List<dynamic>? ?? [];
        final organizations = orgsRaw
            .map((e) => OrganizationMembership.fromJson(e as Map<String, dynamic>))
            .toList();

        final userId = userObj['id'] as String? ?? '';
        final userName = userObj['name'] as String? ?? username;
        final companyId = userObj['company_id'] as String? ?? (organizations.isNotEmpty ? organizations.first.id : '');
        final role = userObj['role'] as String? ?? (organizations.isNotEmpty ? organizations.first.role : 'SALES');

        final expiresAt = parseTokenExpiry(accessToken) ??
            DateTime.now().add(const Duration(seconds: 900));

        final session = UserSession(
          userId: userId,
          name: userName,
          activeOrganizationId: companyId,
          activeRole: role,
          organizations: organizations,
          tokenExpiresAt: expiresAt,
        );

        return AuthLoginResponse(
          accessToken: accessToken,
          refreshToken: refreshToken,
          session: session,
          expiresAt: expiresAt,
        );
      } catch (e) {
        if (e is AuthException) rethrow;
        throw MalformedTokenException('Failed to parse login response: $e');
      }
    } else if (response.statusCode == 401) {
      throw const InvalidCredentialsException('Invalid username or password');
    } else if (response.statusCode == 403) {
      throw const AccountDisabledException('Account is disabled');
    } else if (response.statusCode == 429) {
      throw const RateLimitedException('Too many login attempts. Please wait before retrying.');
    } else {
      throw AuthException(
        'Login failed with HTTP ${response.statusCode}: ${response.body}',
        code: 'HTTP_${response.statusCode}',
      );
    }
  }

  @override
  Future<TokenRefreshResult> refreshToken({required String refreshToken}) async {
    final uri = Uri.parse('$baseUrl/auth/refresh');
    final payload = {'refresh_token': refreshToken};

    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } on SocketException catch (_) {
      throw const NetworkUnavailableException('Unable to reach server during token refresh');
    } on http.ClientException catch (_) {
      throw const NetworkUnavailableException('Network error during token refresh');
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken == null || newRefreshToken == null) {
          throw const MalformedTokenException('Refresh response missing token pairs');
        }

        final expiresAt = parseTokenExpiry(newAccessToken) ??
            DateTime.now().add(const Duration(seconds: 900));

        return TokenRefreshResult(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt: expiresAt,
        );
      } catch (e) {
        if (e is AuthException) rethrow;
        throw MalformedTokenException('Failed to parse token refresh payload: $e');
      }
    } else if (response.statusCode == 401) {
      final body = response.body.toLowerCase();
      if (body.contains('reuse') || body.contains('revoked due to token reuse')) {
        throw const RefreshTokenReuseException(
          'Refresh token reuse detected. Active session has been revoked for security.',
        );
      }
      throw const SessionRevokedException('Session has expired or was revoked. Please log in again.');
    } else if (response.statusCode == 429) {
      throw const RateLimitedException('Rate limit reached during token refresh.');
    } else {
      throw AuthException(
        'Token refresh failed with HTTP ${response.statusCode}',
        code: 'HTTP_${response.statusCode}',
      );
    }
  }

  @override
  Future<AuthSwitchOrgResponse> switchOrganization({
    required String organizationId,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/switch-organization');
    final payload = {'organization_id': organizationId};

    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );
    } on SocketException catch (_) {
      throw const NetworkUnavailableException('Unable to reach server for organization switch');
    } on http.ClientException catch (_) {
      throw const NetworkUnavailableException('Network error during organization switch');
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final userObj = data['user'] as Map<String, dynamic>?;

        if (newAccessToken == null || userObj == null) {
          throw const MalformedTokenException('Switch organization response missing access token or user');
        }

        final targetCompanyId = userObj['company_id'] as String? ?? organizationId;
        final targetRole = userObj['role'] as String? ?? 'SALES';
        final expiresAt = parseTokenExpiry(newAccessToken) ??
            DateTime.now().add(const Duration(seconds: 900));

        return AuthSwitchOrgResponse(
          accessToken: newAccessToken,
          organizationId: targetCompanyId,
          role: targetRole,
          expiresAt: expiresAt,
        );
      } catch (e) {
        if (e is AuthException) rethrow;
        throw MalformedTokenException('Failed to parse switch organization response: $e');
      }
    } else if (response.statusCode == 403) {
      throw const UnauthorizedOrganizationException(
        'User is not an active member of this organization or access was revoked.',
      );
    } else if (response.statusCode == 401) {
      throw const SessionRevokedException('Session is invalid or expired. Cannot switch organization.');
    } else {
      throw AuthException(
        'Failed to switch organization: HTTP ${response.statusCode}',
        code: 'HTTP_${response.statusCode}',
      );
    }
  }

  @override
  Future<void> logout({required String accessToken}) async {
    final uri = Uri.parse('$baseUrl/auth/logout');
    try {
      await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
    } catch (e) {
      // Best-effort network logout; local teardown proceeds regardless
      if (kDebugMode) {
        debugPrint('Logout network call encountered error: $e');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getCurrentUser({required String accessToken}) async {
    final uri = Uri.parse('$baseUrl/me');
    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } on SocketException catch (_) {
      throw const NetworkUnavailableException('Unable to reach server to fetch user details');
    } on http.ClientException catch (_) {
      throw const NetworkUnavailableException('Network error during user fetch');
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw const SessionRevokedException('Access token expired or unauthorized');
    } else {
      throw AuthException(
        'Failed to fetch user details: HTTP ${response.statusCode}',
        code: 'HTTP_${response.statusCode}',
      );
    }
  }

  static bool _isDemoUser(String username) {
    final u = username.trim().toLowerCase();
    return u == 'sales_rep' ||
        u == 'sales' ||
        u == 'inventory_mgr' ||
        u == 'inventory' ||
        u == 'delivery_driver' ||
        u == 'delivery' ||
        u == 'dist_admin' ||
        u == 'admin' ||
        u == 'dist_owner' ||
        u == 'owner';
  }

  static AuthLoginResponse _buildDebugDemoResponse(String username) {
    final cleanUser = username.trim().toLowerCase();
    final role = switch (cleanUser) {
      'dist_owner' || 'owner' => 'OWNER',
      'delivery_driver' || 'delivery' => 'DELIVERY',
      'inventory_mgr' || 'inventory' => 'WAREHOUSE',
      'dist_admin' || 'admin' => 'ADMIN',
      _ => 'SALES',
    };
    final displayName = switch (cleanUser) {
      'dist_owner' || 'owner' => 'Rakesh Agarwal (Owner)',
      'delivery_driver' || 'delivery' => 'Suresh Yadav (Delivery)',
      'inventory_mgr' || 'inventory' => 'Mukesh Godown (Inventory)',
      'dist_admin' || 'admin' => 'Rajesh Sharma (Admin)',
      _ => 'Vikram Rathore (Sales)',
    };
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = nowSec + 86400;
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'usr_demo_$cleanUser',
      'name': displayName,
      'company_id': 'comp_jodhpur',
      'role': role,
      'exp': exp,
    })));
    final accessToken = '$header.$payload.debug_demo_signature';
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final organizations = [
      OrganizationMembership(
        id: 'comp_jodhpur',
        name: 'Jodhpur FMCG Depot',
        role: role,
        isActive: true,
      ),
    ];
    final session = UserSession(
      userId: 'usr_demo_$cleanUser',
      name: displayName,
      activeOrganizationId: 'comp_jodhpur',
      activeRole: role,
      organizations: organizations,
      tokenExpiresAt: expiresAt,
    );
    return AuthLoginResponse(
      accessToken: accessToken,
      refreshToken: 'debug_demo_refresh_token_$cleanUser',
      session: session,
      expiresAt: expiresAt,
    );
  }
}
