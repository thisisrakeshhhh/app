/// Canonical and domain models for RouteFlow Authentication & Organization Membership.
library;

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticatedWithoutOrg,
  orgSelectionRequired,
  orgSwitching,
  authenticated,
  tenantBoundaryBlocked,
  tokenRefreshing,
  sessionExpired,
  membershipRevoked,
  networkUnavailable,
  loggingOut,
}

class OrganizationMembership {
  final String id;
  final String name;
  final String role;
  final bool isActive;

  const OrganizationMembership({
    required this.id,
    required this.name,
    required this.role,
    this.isActive = true,
  });

  factory OrganizationMembership.fromJson(Map<String, dynamic> json) {
    return OrganizationMembership(
      id: json['id'] as String? ?? json['organization_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Organization',
      role: (json['role'] as String? ?? 'SALES').toUpperCase(),
      isActive: json['is_active'] != null ? json['is_active'] == 1 || json['is_active'] == true : true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'is_active': isActive ? 1 : 0,
  };

  @override
  String toString() => 'OrganizationMembership(id: $id, name: $name, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationMembership &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          role == other.role;

  @override
  int get hashCode => Object.hash(id, name, role);
}

class UserSession {
  final String userId;
  final String name;
  final String activeOrganizationId;
  final String activeRole;
  final List<OrganizationMembership> organizations;
  final DateTime? tokenExpiresAt;

  const UserSession({
    required this.userId,
    required this.name,
    required this.activeOrganizationId,
    required this.activeRole,
    required this.organizations,
    this.tokenExpiresAt,
  });

  OrganizationMembership? get activeMembership {
    try {
      return organizations.firstWhere((o) => o.id == activeOrganizationId);
    } catch (_) {
      return null;
    }
  }

  String get activeOrganizationName => activeMembership?.name ?? 'Distributor Organization';

  UserSession copyWith({
    String? userId,
    String? name,
    String? activeOrganizationId,
    String? activeRole,
    List<OrganizationMembership>? organizations,
    DateTime? tokenExpiresAt,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      activeOrganizationId: activeOrganizationId ?? this.activeOrganizationId,
      activeRole: activeRole ?? this.activeRole,
      organizations: organizations ?? this.organizations,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
    );
  }

  @override
  String toString() =>
      'UserSession(userId: $userId, name: $name, orgId: $activeOrganizationId, role: $activeRole)';
}

class AuthState {
  final AuthStatus status;
  final UserSession? session;
  final String? errorMessage;
  final bool isSwitchingOrg;

  const AuthState({
    required this.status,
    this.session,
    this.errorMessage,
    this.isSwitchingOrg = false,
  });

  const AuthState.unauthenticated([String? error])
      : status = AuthStatus.unauthenticated,
        session = null,
        errorMessage = error,
        isSwitchingOrg = false;

  const AuthState.authenticating()
      : status = AuthStatus.authenticating,
        session = null,
        errorMessage = null,
        isSwitchingOrg = false;

  const AuthState.authenticated(UserSession userSession)
      : status = AuthStatus.authenticated,
        session = userSession,
        errorMessage = null,
        isSwitchingOrg = false;

  const AuthState.tenantBoundaryBlocked(UserSession userSession, String reason)
      : status = AuthStatus.tenantBoundaryBlocked,
        session = userSession,
        errorMessage = reason,
        isSwitchingOrg = false;

  const AuthState.orgSelectionRequired(UserSession userSession)
      : status = AuthStatus.orgSelectionRequired,
        session = userSession,
        errorMessage = null,
        isSwitchingOrg = false;

  const AuthState.orgSwitching(UserSession userSession)
      : status = AuthStatus.orgSwitching,
        session = userSession,
        errorMessage = null,
        isSwitchingOrg = true;

  const AuthState.sessionExpired([String? error])
      : status = AuthStatus.sessionExpired,
        session = null,
        errorMessage = error ?? 'Session has expired. Please sign in again.',
        isSwitchingOrg = false;

  const AuthState.membershipRevoked([String? error])
      : status = AuthStatus.membershipRevoked,
        session = null,
        errorMessage = error ?? 'Your access to this organization has been revoked by the distributor administrator.',
        isSwitchingOrg = false;

  const AuthState.networkUnavailable(UserSession? cachedSession)
      : status = AuthStatus.networkUnavailable,
        session = cachedSession,
        errorMessage = 'Network connection unavailable. Operating in offline mode.',
        isSwitchingOrg = false;

  bool get isAuthenticated =>
      (status == AuthStatus.authenticated || status == AuthStatus.tenantBoundaryBlocked) &&
      session != null &&
      session!.activeOrganizationId.isNotEmpty;

  bool get isTenantBoundaryBlocked => status == AuthStatus.tenantBoundaryBlocked;

  bool get requiresOrgSelection => status == AuthStatus.orgSelectionRequired;
}
