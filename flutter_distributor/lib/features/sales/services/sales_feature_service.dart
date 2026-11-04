import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../data/local/local_repository.dart';
import '../../../services/api_service.dart';

/// Central feature service for Sales role operations.
/// Takes ApiService and optional LocalRepository to avoid bloating ApiService.
class SalesFeatureService extends ChangeNotifier {
  final ApiService api;
  final LocalRepository? localRepo;

  final Set<String> _extraVisitShopIds = {};
  bool _isInitialized = false;

  SalesFeatureService({
    required this.api,
    this.localRepo,
  });

  bool get isInitialized => _isInitialized;
  Set<String> get extraVisitShopIds => Set.unmodifiable(_extraVisitShopIds);

  /// Key for storing today's extra visits in local storage to survive app restart.
  String _todayExtraVisitsKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'sales_extra_visits_${y}_${m}_$d';
  }

  /// Initialize service, restoring today's persisted extra visits.
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (localRepo != null) {
      try {
        final key = _todayExtraVisitsKey();
        final raw = await localRepo!.getMetadata(key);
        if (raw != null && raw.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(raw);
          _extraVisitShopIds.addAll(decoded.map((e) => e.toString()));
          // Mirror into api service for backwards compatibility with existing views
          for (final id in _extraVisitShopIds) {
            api.addExtraVisitShop(id);
          }
        }
      } catch (e) {
        debugPrint('[SalesFeatureService] Error restoring extra visits: $e');
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Add a shop as an extra visit for today.
  Future<void> addExtraVisit(String shopId) async {
    _extraVisitShopIds.add(shopId);
    api.addExtraVisitShop(shopId);
    await _persistExtraVisits();
    notifyListeners();
  }

  /// Remove a shop from today's extra visits.
  Future<void> removeExtraVisit(String shopId) async {
    _extraVisitShopIds.remove(shopId);
    api.removeExtraVisitShop(shopId);
    await _persistExtraVisits();
    notifyListeners();
  }

  /// Whether a shop is part of today's schedule (assigned or extra visit).
  bool isShopInTodaySchedule(String shopId) {
    if (_extraVisitShopIds.contains(shopId)) return true;
    return api.isAssignedBeatShop(shopId);
  }

  Future<void> _persistExtraVisits() async {
    if (localRepo == null) return;
    try {
      final key = _todayExtraVisitsKey();
      await localRepo!.setMetadata(key, jsonEncode(_extraVisitShopIds.toList()));
    } catch (e) {
      debugPrint('[SalesFeatureService] Error persisting extra visits: $e');
    }
  }
}
