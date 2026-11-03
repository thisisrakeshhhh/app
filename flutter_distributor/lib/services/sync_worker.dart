import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/local/app_database.dart';
import 'auth_service.dart';

enum SyncWorkerState {
  idle,
  syncing,
  pausedAuthRequired,
  errorBackoff,
}

class SyncPushResult {
  final bool success;
  final int syncedCount;
  final bool authRequired;
  final bool hasPermanentFailure;
  final String? errorMessage;

  const SyncPushResult({
    required this.success,
    this.syncedCount = 0,
    this.authRequired = false,
    this.hasPermanentFailure = false,
    this.errorMessage,
  });

  factory SyncPushResult.empty() => const SyncPushResult(success: true, syncedCount: 0);

  factory SyncPushResult.success(int count) => SyncPushResult(success: true, syncedCount: count);

  factory SyncPushResult.authRequired() => const SyncPushResult(
        success: false,
        authRequired: true,
        errorMessage: 'Authentication expired. Please sign in again.',
      );

  factory SyncPushResult.permanentFailure(String message) => SyncPushResult(
        success: false,
        hasPermanentFailure: true,
        errorMessage: message,
      );

  factory SyncPushResult.networkError(String message) => SyncPushResult(
        success: false,
        errorMessage: message,
      );
}

/// Persistent Background Outbox Sync Worker for RouteFlow FMCG Mobile.
///
/// Integrates with SQLite Drift outbox, Cloudflare Workers D1 `POST /sync/push`,
/// and token rotation coordinator.
class SyncWorker extends ChangeNotifier {
  final AppDatabase db;
  final http.Client httpClient;
  final String baseUrl;
  final AuthService? authService;
  final Future<String?> Function()? accessTokenProvider;
  final Future<bool> Function()? refreshTokenTrigger;

  SyncWorkerState _state = SyncWorkerState.idle;
  String? _lastError;
  int _consecutiveNetworkFailures = 0;
  Timer? _periodicTimer;
  bool _isDisposed = false;

  SyncWorker({
    required this.db,
    required this.httpClient,
    required this.baseUrl,
    this.authService,
    this.accessTokenProvider,
    this.refreshTokenTrigger,
  });

  SyncWorkerState get state => _state;
  String? get lastError => _lastError;
  bool get isSyncing => _state == SyncWorkerState.syncing;

  /// Starts periodic sync runner (default every 15 seconds).
  void startPeriodicRunner({Duration interval = const Duration(seconds: 15)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => processPendingOutbox());
  }

  /// Stops periodic sync runner.
  void stopRunner() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _periodicTimer?.cancel();
    super.dispose();
  }

  /// Triggers an immediate sync pass of pending outbox mutations.
  Future<SyncPushResult> processPendingOutbox({
    String? organizationId,
    String? userId,
    int limit = 50,
  }) async {
    if (_state == SyncWorkerState.syncing) {
      return SyncPushResult.empty();
    }

    final orgId = organizationId ?? authService?.activeOrganization?.id ?? 'comp_1';
    final uId = userId ?? authService?.session?.userId ?? 'usr_sales';

    // 1. Fetch pending queue strictly ordered by sequenceOrder and createdAt
    final pendingMutations = await db.outboxDao.getPendingMutations(
      organizationId: orgId,
      userId: uId,
    );

    if (pendingMutations.isEmpty) {
      _consecutiveNetworkFailures = 0;
      _setState(SyncWorkerState.idle);
      return SyncPushResult.empty();
    }

    final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
    final readyMutations = pendingMutations.where((m) {
      final nextRetry = m.nextRetryAtMs;
      return nextRetry == null || nextRetry <= nowEpochMs;
    }).take(limit).toList();

    if (readyMutations.isEmpty) {
      return SyncPushResult.empty();
    }

    _setState(SyncWorkerState.syncing);

    // 2. Obtain valid Bearer access token
    String? token = await _resolveAccessToken();
    if (token == null || token.isEmpty) {
      // Try refresh
      final refreshed = await _triggerTokenRefresh();
      if (!refreshed) {
        _setState(SyncWorkerState.pausedAuthRequired);
        return SyncPushResult.authRequired();
      }
      token = await _resolveAccessToken();
      if (token == null || token.isEmpty) {
        _setState(SyncWorkerState.pausedAuthRequired);
        return SyncPushResult.authRequired();
      }
    }

    return _sendBatch(
      readyMutations: readyMutations,
      orgId: orgId,
      userId: uId,
      token: token,
      isRetryAfterAuth: false,
    );
  }

  Future<SyncPushResult> _sendBatch({
    required List<OutboxMutationEntry> readyMutations,
    required String orgId,
    required String userId,
    required String token,
    required bool isRetryAfterAuth,
  }) async {
    final batchPayload = {
      'clientBatchId': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      'organizationId': orgId,
      'userId': userId,
      'clientTimestampEpochMs': DateTime.now().millisecondsSinceEpoch,
      'mutations': readyMutations.map((m) {
        dynamic parsedPayload;
        try {
          parsedPayload = jsonDecode(m.payloadJson);
        } catch (_) {
          parsedPayload = {};
        }

        return {
          'mutationId': m.id,
          'sequenceOrder': m.sequenceOrder,
          'idempotencyKey': m.idempotencyKey,
          'mutationType': m.mutationType,
          'provisionalBusinessId': m.provisionalBusinessId,
          'createdAtEpochMs': m.createdAtEpochMs,
          'payload': parsedPayload,
        };
      }).toList(),
    };

    final uri = Uri.parse('$baseUrl/sync/push');

    try {
      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'X-Device-Platform': 'Flutter-Android',
            },
            body: jsonEncode(batchPayload),
          )
          .timeout(const Duration(seconds: 15));

      // --- CASE 1: HTTP 200 OK (Authentic Server Confirmation) ---
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'] as List<dynamic>? ?? [];
        final resultMap = <String, dynamic>{};
        for (final r in results) {
          if (r is Map<String, dynamic>) {
            resultMap[r['mutationId'] as String? ?? ''] = r;
          }
        }

        int syncedCount = 0;
        int rejectedCount = 0;
        String? firstRejectionError;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        for (final m in readyMutations) {
          final res = resultMap[m.id];
          if (res != null) {
            final status = res['status'] as String?;
            if (status == 'COMMITTED') {
              await db.outboxDao.markSynced(id: m.id, syncedAtEpochMs: nowMs);
              syncedCount++;
            } else if (status == 'REJECTED') {
              rejectedCount++;
              final errCode = res['errorCode'] as String? ?? 'UNSUPPORTED_MUTATION_TYPE';
              final errMsg = res['errorMessage'] as String? ?? 'Mutation rejected by server';
              firstRejectionError ??= errMsg;
              await db.outboxDao.markFailedPermanent(
                id: m.id,
                errorCode: errCode,
              );
            }
          }
        }

        _consecutiveNetworkFailures = 0;
        _lastError = firstRejectionError;
        _setState(SyncWorkerState.idle);

        if (rejectedCount > 0 && syncedCount == 0) {
          return SyncPushResult.permanentFailure(firstRejectionError ?? 'Mutations rejected by server');
        }
        return SyncPushResult.success(syncedCount);
      }

      // --- CASE 2: HTTP 409 Conflict (Idempotency Payload Mismatch) ---
      if (response.statusCode == 409) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final failedMutationId = body['mutationId'] as String?;
        final message = body['message'] as String? ??
            'Idempotency conflict: this transaction was already registered with different data.';

        if (failedMutationId != null) {
          await db.outboxDao.markFailedPermanent(
            id: failedMutationId,
            errorCode: 'IDEMPOTENCY_PAYLOAD_MISMATCH',
          );
        } else {
          for (final m in readyMutations) {
            await db.outboxDao.markFailedPermanent(
              id: m.id,
              errorCode: 'IDEMPOTENCY_PAYLOAD_MISMATCH',
            );
          }
        }

        _lastError = message;
        _setState(SyncWorkerState.idle);
        return SyncPushResult.permanentFailure(message);
      }

      // --- CASE 3: HTTP 401 Unauthorized (Token Expired) ---
      if (response.statusCode == 401) {
        if (!isRetryAfterAuth) {
          final refreshed = await _triggerTokenRefresh();
          if (refreshed) {
            final freshToken = await _resolveAccessToken();
            if (freshToken != null && freshToken.isNotEmpty) {
              return _sendBatch(
                readyMutations: readyMutations,
                orgId: orgId,
                userId: userId,
                token: freshToken,
                isRetryAfterAuth: true,
              );
            }
          }
        }
        _lastError = 'Session expired. Please log in again.';
        _setState(SyncWorkerState.pausedAuthRequired);
        return SyncPushResult.authRequired();
      }

      // --- CASE 4: HTTP 403 Forbidden (RBAC / Tenant Mismatch) ---
      if (response.statusCode == 403) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final message = body['message'] as String? ?? 'Action forbidden by server permissions.';
        for (final m in readyMutations) {
          await db.outboxDao.markFailedPermanent(id: m.id, errorCode: 'FORBIDDEN_ROLE_ACTION');
        }
        _lastError = message;
        _setState(SyncWorkerState.idle);
        return SyncPushResult.permanentFailure(message);
      }

      // --- CASE 5: Server 5xx or unexpected 4xx ---
      return await _handleNetworkFailure(
        readyMutations: readyMutations,
        message: 'Server error: HTTP ${response.statusCode}',
      );
    } on SocketException catch (e) {
      return await _handleNetworkFailure(
        readyMutations: readyMutations,
        message: 'Network unreachable: ${e.message}',
      );
    } on TimeoutException catch (e) {
      return await _handleNetworkFailure(
        readyMutations: readyMutations,
        message: 'Network timed out: ${e.message}',
      );
    } catch (e) {
      return await _handleNetworkFailure(
        readyMutations: readyMutations,
        message: 'Unexpected network error: $e',
      );
    }
  }

  Future<SyncPushResult> _handleNetworkFailure({
    required List<OutboxMutationEntry> readyMutations,
    required String message,
  }) async {
    _consecutiveNetworkFailures++;
    // Exponential backoff: 1s * 2^(failures-1), capped at 30 seconds
    final backoffSeconds = min(30, pow(2, min(5, _consecutiveNetworkFailures - 1)).toInt());
    final nextRetryAtMs = DateTime.now().millisecondsSinceEpoch + (backoffSeconds * 1000);

    for (final m in readyMutations) {
      await db.outboxDao.markRetryableFailure(
        id: m.id,
        errorCode: 'NETWORK_TIMEOUT',
        nextRetryAtMs: nextRetryAtMs,
      );
    }

    _lastError = message;
    _setState(SyncWorkerState.errorBackoff);
    return SyncPushResult.networkError(message);
  }

  Future<String?> _resolveAccessToken() async {
    if (accessTokenProvider != null) {
      return accessTokenProvider!();
    }
    if (authService != null) {
      try {
        return await authService!.getValidAccessToken();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<bool> _triggerTokenRefresh() async {
    if (refreshTokenTrigger != null) {
      return refreshTokenTrigger!();
    }
    if (authService != null) {
      try {
        await authService!.getValidAccessToken();
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _setState(SyncWorkerState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }
}
