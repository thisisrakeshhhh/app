import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/local/app_database.dart';
import 'api_service.dart';
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
  final ApiService? apiService;
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
    this.apiService,
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

    // Collect pending shop creation provisional IDs that have NOT yet synced
    final pendingShopProvisionalIds = <String>{};
    for (final m in pendingMutations) {
      if (m.mutationType == 'CREATE_RETAILER' &&
          m.provisionalBusinessId != null &&
          (m.syncStatus == 'PENDING' || m.syncStatus == 'RETRYABLE_FAILURE')) {
        pendingShopProvisionalIds.add(m.provisionalBusinessId!);
      }
    }

    final readyMutations = <OutboxMutationEntry>[];
    for (final m in pendingMutations) {
      final nextRetry = m.nextRetryAtMs;
      if (nextRetry != null && nextRetry > nowEpochMs) continue;

      if (m.mutationType == 'CREATE_ORDER') {
        String? orderRetailerId;
        try {
          final payload = jsonDecode(m.payloadJson);
          orderRetailerId = payload['retailer']?['id'] ?? payload['retailerId'];
        } catch (_) {}

        // If this order depends on a shop mutation that has not yet synced and is not earlier in this batch
        if (orderRetailerId != null && pendingShopProvisionalIds.contains(orderRetailerId)) {
          final shopAlreadyInBatch = readyMutations.any(
            (r) => r.mutationType == 'CREATE_RETAILER' && r.provisionalBusinessId == orderRetailerId,
          );
          if (!shopAlreadyInBatch) {
            // Hold order mutation back until its shop mutation is accepted
            continue;
          }
        }
      }

      readyMutations.add(m);
      if (readyMutations.length >= limit) break;
    }

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

  /// Pulls delta updates from POST /sync/pull and integrates them into local repository and ApiService.
  Future<bool> processPullDelta({
    String? organizationId,
    int? lastServerSequence,
    int limit = 100,
  }) async {
    final orgId = organizationId ?? authService?.activeOrganization?.id ?? 'comp_1';

    String? token = await _resolveAccessToken();
    if (token == null || token.isEmpty) {
      final refreshed = await _triggerTokenRefresh();
      if (!refreshed) return false;
      token = await _resolveAccessToken();
      if (token == null || token.isEmpty) return false;
    }

    final uri = Uri.parse('$baseUrl/sync/pull');
    try {
      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'organizationId': orgId,
              'lastServerSequence': lastServerSequence ?? 0,
              'limit': limit,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final delta = body['delta'] as Map<String, dynamic>? ?? {};

        // 1. Process Order Status Updates
        final orderUpdates = delta['orderStatusUpdates'] as List<dynamic>? ?? [];
        for (final u in orderUpdates) {
          if (u is Map<String, dynamic>) {
            final orderId = u['serverOrderId'] as String?;
            final newStageStr = u['newStage'] as String?;
            if (orderId != null && newStageStr != null && apiService != null) {
              apiService!.updateOrderStageFromServer(orderId, newStageStr);
            }
          }
        }

        // 2. Process Retailer Updates
        final retailerUpdates = delta['retailers'] as List<dynamic>? ?? [];
        for (final r in retailerUpdates) {
          if (r is Map<String, dynamic>) {
            final retId = r['id'] as String?;
            final rawCredit = r['creditLimitPaise'];
            final credit = rawCredit != null ? (rawCredit as num).toInt() : null;
            if (retId != null && apiService != null) {
              apiService!.updateRetailerFromServer(
                id: retId,
                creditLimitPaise: credit,
                classification: r['classification'] as String?,
              );
            }
          }
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SyncWorker processPullDelta error: $e');
      return false;
    }
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

              // Transactional provisional ID rewriting
              final serverBusinessId = res['serverBusinessId'] as String?;
              final provId = m.provisionalBusinessId;
              if (serverBusinessId != null &&
                  serverBusinessId.isNotEmpty &&
                  provId != null &&
                  provId.isNotEmpty &&
                  provId != serverBusinessId) {
                await db.outboxDao.rewriteProvisionalId(
                  provisionalId: provId,
                  serverBusinessId: serverBusinessId,
                  organizationId: orgId,
                );
                if (m.mutationType == 'CREATE_RETAILER') {
                  apiService?.rewriteProvisionalRetailerId(provId, serverBusinessId);
                } else if (m.mutationType == 'CREATE_ORDER') {
                  apiService?.rewriteProvisionalOrderId(provId, serverBusinessId);
                }
              }
            } else if (status == 'REJECTED') {
              rejectedCount++;
              final errCode = res['errorCode'] as String? ?? 'UNSUPPORTED_MUTATION_TYPE';
              final errMsg = res['errorMessage'] as String? ?? 'Mutation rejected by server';
              firstRejectionError ??= errMsg;
              await db.outboxDao.markFailedPermanent(
                id: m.id,
                errorCode: errCode,
              );

              // Virtual reservation release on rejected order
              if (m.mutationType == 'CREATE_ORDER') {
                final provId = m.provisionalBusinessId;
                if (provId != null) {
                  apiService?.releaseOrderReservation(provId, reason: errMsg);
                }
              }
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
          final failedMut = readyMutations.cast<OutboxMutationEntry?>().firstWhere(
                (m) => m?.id == failedMutationId,
                orElse: () => null,
              );
          if (failedMut?.mutationType == 'CREATE_ORDER' && failedMut?.provisionalBusinessId != null) {
            apiService?.releaseOrderReservation(failedMut!.provisionalBusinessId!, reason: message);
          }
        } else {
          for (final m in readyMutations) {
            await db.outboxDao.markFailedPermanent(
              id: m.id,
              errorCode: 'IDEMPOTENCY_PAYLOAD_MISMATCH',
            );
            if (m.mutationType == 'CREATE_ORDER' && m.provisionalBusinessId != null) {
              apiService?.releaseOrderReservation(m.provisionalBusinessId!, reason: message);
            }
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

      // --- CASE 4: HTTP 403 Forbidden or HTTP 400 Bad Request ---
      if (response.statusCode == 403 || response.statusCode == 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final message = body['message'] as String? ?? 'Action rejected by server permissions.';
        final errCode = body['error'] as String? ??
            (response.statusCode == 403 ? 'FORBIDDEN_ROLE_ACTION' : 'BAD_REQUEST');
        for (final m in readyMutations) {
          await db.outboxDao.markFailedPermanent(id: m.id, errorCode: errCode);
          if (m.mutationType == 'CREATE_ORDER' && m.provisionalBusinessId != null) {
            apiService?.releaseOrderReservation(m.provisionalBusinessId!, reason: message);
          }
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
