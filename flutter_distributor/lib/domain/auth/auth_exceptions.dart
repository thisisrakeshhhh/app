/// Typed, recoverable domain exceptions for RouteFlow authentication and authorization.
library;

class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException([super.message = 'Invalid username or password'])
      : super(code: 'INVALID_CREDENTIALS');
}

class AccountDisabledException extends AuthException {
  const AccountDisabledException([super.message = 'User account has been disabled'])
      : super(code: 'ACCOUNT_DISABLED');
}

class SessionRevokedException extends AuthException {
  const SessionRevokedException([super.message = 'Session has been revoked or expired'])
      : super(code: 'SESSION_REVOKED');
}

class UnauthenticatedException extends AuthException {
  const UnauthenticatedException([super.message = 'No active user session found'])
      : super(code: 'UNAUTHENTICATED');
}

class RefreshTokenReuseException extends AuthException {
  const RefreshTokenReuseException([super.message = 'Refresh token reuse detected. Session revoked for security.'])
      : super(code: 'TOKEN_REUSE_DETECTED');
}

class UnauthorizedOrganizationException extends AuthException {
  const UnauthorizedOrganizationException([super.message = 'Account is not an active member of target organization'])
      : super(code: 'UNAUTHORIZED_ORGANIZATION');
}

class MembershipRevokedException extends AuthException {
  const MembershipRevokedException([super.message = 'Membership in organization has been revoked by distributor'])
      : super(code: 'MEMBERSHIP_REVOKED');
}

class NetworkUnavailableException extends AuthException {
  const NetworkUnavailableException([super.message = 'Network connection unavailable. Operation cannot be completed.'])
      : super(code: 'NETWORK_UNAVAILABLE');
}

class RateLimitedException extends AuthException {
  const RateLimitedException([super.message = 'Too many requests. Please wait before retrying.'])
      : super(code: 'RATE_LIMITED');
}

class MalformedTokenException extends AuthException {
  const MalformedTokenException([super.message = 'Authentication token response was malformed or missing required claims'])
      : super(code: 'MALFORMED_TOKEN');
}

class StaleOrganizationCredentialsException extends AuthException {
  const StaleOrganizationCredentialsException([super.message = 'Request blocked: organization credentials do not match active tenant'])
      : super(code: 'STALE_ORG_CREDENTIALS');
}

class KeystoreInaccessibleException extends AuthException {
  const KeystoreInaccessibleException([super.message = 'Android Keystore credentials inaccessible or invalidated. Safe re-authentication required.'])
      : super(code: 'KEYSTORE_INACCESSIBLE');
}

class OrganizationSwitchBlockedException extends AuthException {
  const OrganizationSwitchBlockedException([super.message = 'Multi-tenant organization switching is deferred to Phase B2.2 pending local multi-tenant database migration.'])
      : super(code: 'ORG_SWITCH_BLOCKED');
}

class TenantBoundaryException extends AuthException {
  const TenantBoundaryException([super.message = 'Access to local business data is blocked to prevent cross-tenant contamination. Unassigned legacy data present on device.'])
      : super(code: 'TENANT_BOUNDARY_BLOCKED');
}
