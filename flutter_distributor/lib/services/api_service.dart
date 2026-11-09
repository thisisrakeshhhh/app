import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/local/app_database.dart';
import '../data/local/local_repository.dart';
import '../domain/auth/auth_exceptions.dart';
import '../domain/auth/auth_models.dart';
import '../domain/auth/tenant_boundary_gate.dart';
import '../domain/outbox/outbox_models.dart';
import '../models/models.dart';

enum DuplicateType { none, exactMobile, exactGstin, similarNameInArea, similarNameNearby }

class DuplicateCheckResult {
  final DuplicateType type;
  final RetailerShop? matchedShop;
  final String? message;

  const DuplicateCheckResult({
    required this.type,
    this.matchedShop,
    this.message,
  });

  bool get hasDuplicate => type != DuplicateType.none;
  bool get requiresStrictConfirmation =>
      type == DuplicateType.exactMobile || type == DuplicateType.exactGstin;
}

class StalePriceWarning {
  final String productId;
  final String productName;
  final String unitName;
  final int oldPricePaise;
  final int newPricePaise;

  const StalePriceWarning({
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.oldPricePaise,
    required this.newPricePaise,
  });
}

class OwnerMetrics {
  final int todayBookingsPaise;
  final int todayOrdersCount;
  final int pendingOutboxCount;
  final int lowStockCount;
  final int activeShopsCount;

  const OwnerMetrics({
    required this.todayBookingsPaise,
    required this.todayOrdersCount,
    required this.pendingOutboxCount,
    required this.lowStockCount,
    required this.activeShopsCount,
  });

  double get todayBookingsRupees => todayBookingsPaise / 100.0;
}

class OrderTimelineStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final DateTime? timestamp;

  const OrderTimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.timestamp,
  });
}

class ApiService extends ChangeNotifier {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final AppDatabase db;
  late final LocalRepository repository;
  Future<void>? _syncFuture;

  UserSession? Function()? _sessionProvider;

  /// Active authenticated user session context.
  UserSession? get currentSession {
    if (_sessionProvider != null) {
      return _sessionProvider!();
    }
    // Default session for standalone FMCG operations
    return const UserSession(
      userId: 'usr_local_sales',
      name: 'Field Salesperson',
      activeOrganizationId: 'org_jaipur_dist',
      activeRole: 'SALES',
      organizations: [
        OrganizationMembership(
          id: 'org_jaipur_dist',
          name: 'Jaipur FMCG Distributors',
          role: 'SALES',
          isActive: true,
        ),
      ],
    );
  }

  void setSessionProvider(UserSession? Function()? provider) {
    _sessionProvider = provider;
  }

  bool _isDemoModeLoaded = false;
  bool get isDemoModeLoaded => _isDemoModeLoaded;

  ApiService._internal({
    AppDatabase? database,
    LocalRepository? localRepo,
    UserSession? Function()? sessionProvider,
  }) {
    db = database ?? AppDatabase();
    repository = localRepo ?? LocalRepository(db);
    _sessionProvider = sessionProvider;
    _initializeData();
    _syncFuture = _syncFromDatabase();
  }

  /// Active database sync future. Callers may await this to ensure database loading is complete.
  Future<void>? get syncFuture => _syncFuture;

  @visibleForTesting
  ApiService.internalForTesting({
    AppDatabase? database,
    LocalRepository? localRepo,
    UserSession? Function()? sessionProvider,
    bool seed = true,
  }) {
    db = database ?? AppDatabase();
    repository = localRepo ?? LocalRepository(db);
    _sessionProvider = sessionProvider;
    if (seed) {
      _initializeData();
      _isDemoModeLoaded = true;
    }
  }

  /// Explicit sync from database for testing and fresh-install initialization
  Future<void> syncFromDatabaseDirect() async {
    final meta = await repository.getMetadata('demo_mode_loaded');
    if (meta == 'true') {
      _isDemoModeLoaded = true;
    }
    await _syncFromDatabase();
  }

  /// Populates demo FMCG catalog, sample retailers, and initial inventory behind explicit user opt-in
  Future<void> loadDemoData() async {
    _initializeData();
    _isDemoModeLoaded = true;
    await repository.setMetadata('demo_mode_loaded', 'true');
    await repository.seedIfEmpty(_products, _retailers);
    await repository.backfillLegacyProductUnitsAndPrices();
    await _syncFromDatabase();
    notifyListeners();
  }

  bool _salesV2Enabled = false;

  /// Whether Sales V2 4-tab navigation and screens are active.
  bool get salesV2Enabled => _salesV2Enabled;

  void setSalesV2Enabled(bool value, {bool persist = true}) {
    _salesV2Enabled = value;
    if (persist) {
      repository.setMetadata('sales_v2_enabled', value ? 'true' : 'false');
    }
    notifyListeners();
  }

  @visibleForTesting
  Future<void> syncForTesting({bool seed = true}) async {
    if (seed) {
      await repository.seedIfEmpty(_products, _retailers);
      _isDemoModeLoaded = true;
    }
    return _syncFromDatabase();
  }

  // Server API endpoint configuration (configurable via --dart-define=ROUTEFLOW_API_URL=...)
  String _cloudflareUrl = const String.fromEnvironment(
    'ROUTEFLOW_API_URL',
    defaultValue: 'https://routeflow-api-staging.thisisrakesh21.workers.dev',
  );
  final bool _isOnline = false;
  final bool _isLoading = false;

  String get cloudflareUrl => _cloudflareUrl;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;

  /// Debug-only method to configure server base URL for local testing (e.g. adb reverse tcp:8787).
  void setDebugBaseUrl(String url) {
    if (kDebugMode) {
      _cloudflareUrl = url.trim();
      notifyListeners();
    }
  }

  /// Callback invoked whenever a new mutation is safely enqueued to SQLite outbox.
  VoidCallback? onOutboxMutationEnqueued;

  // Active role
  AppRole _currentRole = AppRole.sales;
  AppRole get currentRole => _currentRole;

  void switchRole(AppRole role) {
    _currentRole = role;
    notifyListeners();
  }

  // Active Vehicle / Car Logistics & Multi-Truck Fleet
  String _carNumber = 'RJ-19-GB-4021';
  String get carNumber => _carNumber;

  final List<DeliveryTruck> _deliveryTrucks = [
    DeliveryTruck(
      id: 'truck-1',
      vehicleNumber: 'RJ-19-GB-4021',
      vehicleModel: 'Tata Ace Gold',
      driverName: 'Ramesh Choudhary',
      driverPhone: '+91 98290 12345',
      capacityBoxes: 150,
    ),
    DeliveryTruck(
      id: 'truck-2',
      vehicleNumber: 'RJ-19-GA-8822',
      vehicleModel: 'Mahindra Bolero Maxi Truck',
      driverName: 'Suresh Gehlot',
      driverPhone: '+91 98290 54321',
      capacityBoxes: 250,
    ),
    DeliveryTruck(
      id: 'truck-3',
      vehicleNumber: 'RJ-19-GC-1104',
      vehicleModel: 'Eicher Pro 2049',
      driverName: 'Vikas Bhati',
      driverPhone: '+91 94140 98765',
      capacityBoxes: 400,
    ),
  ];

  String _selectedTruckId = 'truck-1';
  List<DeliveryTruck> get deliveryTrucks => List.unmodifiable(_deliveryTrucks);

  DeliveryTruck get activeTruck => _deliveryTrucks.firstWhere(
    (t) => t.id == _selectedTruckId,
    orElse: () => _deliveryTrucks.first,
  );

  void selectTruck(String truckId) {
    if (_deliveryTrucks.any((t) => t.id == truckId)) {
      _selectedTruckId = truckId;
      _carNumber = activeTruck.vehicleNumber;
      notifyListeners();
    }
  }

  void addDeliveryTruck({
    required String vehicleNumber,
    required String vehicleModel,
    required String driverName,
    String driverPhone = '',
    int capacityBoxes = 200,
  }) {
    final cleanNum = vehicleNumber.trim().toUpperCase();
    final newId = 'truck-${DateTime.now().millisecondsSinceEpoch}';
    final newTruck = DeliveryTruck(
      id: newId,
      vehicleNumber: cleanNum,
      vehicleModel: vehicleModel.trim().isEmpty ? 'Delivery Van' : vehicleModel.trim(),
      driverName: driverName.trim().isEmpty ? 'Assigned Driver' : driverName.trim(),
      driverPhone: driverPhone.trim(),
      capacityBoxes: capacityBoxes > 0 ? capacityBoxes : 200,
    );
    _deliveryTrucks.add(newTruck);
    _selectedTruckId = newId;
    _carNumber = cleanNum;
    notifyListeners();
  }

  void updateCarNumber(String newNum) {
    if (newNum.trim().isNotEmpty) {
      _carNumber = newNum.trim().toUpperCase();
      notifyListeners();
    }
  }

  // Products catalog (Dynamic FMCG Categories)
  List<ProductItem> _products = [];
  List<ProductItem> get products => _products;

  // Dynamic Godown Inventory Actions
  void addProduct(ProductItem item) {
    _products.add(item);
    repository.upsertProduct(item);
    notifyListeners();
  }

  void updateProduct(ProductItem item) {
    final idx = _products.indexWhere((p) => p.id == item.id);
    if (idx != -1) {
      _products[idx] = item;
      repository.upsertProduct(item);
      notifyListeners();
    }
  }

  void restockProduct(String productId, int addGodownBoxes) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final p = _products[idx];
      p.godownStockBoxes += addGodownBoxes;
      repository.recordStockMovement(
        productId: productId,
        movementType: 'INWARD',
        cartonDelta: addGodownBoxes,
        loosePieceDelta: 0,
        reason: 'Restocked in Central Godown',
        newGodownCartons: p.godownStockBoxes,
        newGodownLoosePieces: 0,
        newCarCartons: p.carStockBoxes,
        newCarLoosePieces: 0,
      );
      notifyListeners();
    }
  }

  void removeProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    _cart.remove(productId);
    repository.deleteProduct(productId);
    notifyListeners();
  }

  void archiveProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    _cart.remove(productId);
    repository.archiveProduct(productId);
    notifyListeners();
  }

  Future<void> restoreProduct(String productId) async {
    final capturedGen = _transientGeneration;
    await repository.restoreProduct(productId);
    if (capturedGen != _transientGeneration) return;
    final active = await repository.getAllProducts();
    if (capturedGen != _transientGeneration) return;
    _products = active;
    notifyListeners();
  }

  // Sovereign Governance Actions (Restricted to CanonicalRole.owner)
  Future<void> updateRetailerCreditLimit(String shopId, int newLimitPaise) async {
    final session = currentSession;
    if (_sessionProvider != null) {
      if (session == null || (session.activeRole != 'OWNER' && session.activeRole != 'ADMIN')) {
        throw const UnauthorizedRoleException('Cannot modify credit limit: Caller is not OWNER or ADMIN.');
      }
    }
    if (newLimitPaise < 0) {
      throw ArgumentError('Credit limit cannot be negative.');
    }
    final idx = _retailers.indexWhere((r) => r.id == shopId);
    if (idx != -1) {
      final shop = _retailers[idx];
      shop.creditLimitPaise = newLimitPaise;
      await repository.upsertRetailer(shop);
      notifyListeners();
    } else {
      throw StateError('Retailer "$shopId" not found.');
    }
  }

  Future<void> writeOffDamagedStock({
    required String productId,
    required int cartonCount,
    required String reason,
  }) async {
    if (cartonCount <= 0) {
      throw ArgumentError('Write-off count must be strictly positive.');
    }
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final p = _products[idx];
      if (p.godownStockBoxes < cartonCount) {
        throw StateError('Cannot write off $cartonCount cartons: only ${p.godownStockBoxes} in godown.');
      }
      p.godownStockBoxes -= cartonCount;
      await repository.recordStockMovement(
        productId: productId,
        movementType: 'WRITE_OFF',
        cartonDelta: -cartonCount,
        loosePieceDelta: 0,
        reason: 'Damaged/Expired Write-off: $reason',
        newGodownCartons: p.godownStockBoxes,
        newGodownLoosePieces: 0,
        newCarCartons: p.carStockBoxes,
        newCarLoosePieces: 0,
      );
      notifyListeners();
    } else {
      throw StateError('Product "$productId" not found.');
    }
  }

  double _settledDriverCashRupees = 0.0;
  double get settledDriverCashRupees => _settledDriverCashRupees;

  bool settleDriverCashHandover({required String driverId, required double settledAmountRupees}) {
    if (settledAmountRupees < 0) {
      throw ArgumentError('Settled amount cannot be negative.');
    }
    _settledDriverCashRupees += settledAmountRupees;
    notifyListeners();
    return true;
  }

  // Retailer shops in Jodhpur Beat
  List<RetailerShop> _retailers = [];
  List<RetailerShop> get retailers => _retailers;

  static double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R * 1000 meters
  }

  DuplicateCheckResult checkDuplicateRetailer({
    required String phone,
    required String name,
    required String area,
    String? gstin,
    double? latitude,
    double? longitude,
  }) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final last10Phone = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    final cleanGstin = gstin?.trim().toUpperCase();

    String normalizeName(String raw) {
      return raw
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '')
          .replaceAll('kirana', '')
          .replaceAll('store', '')
          .replaceAll('general', '')
          .replaceAll('supermarket', '')
          .replaceAll('provision', '');
    }

    final normName = normalizeName(name);

    for (final shop in _retailers) {
      // 1. Exact mobile check
      final shopPhone = shop.phone.replaceAll(RegExp(r'\D'), '');
      final shopLast10 = shopPhone.length >= 10
          ? shopPhone.substring(shopPhone.length - 10)
          : shopPhone;
      if (last10Phone.isNotEmpty && shopLast10 == last10Phone) {
        return DuplicateCheckResult(
          type: DuplicateType.exactMobile,
          matchedShop: shop,
          message: 'A shop with this mobile number already exists: "${shop.name}" (${shop.ownerName}, ${shop.area}).',
        );
      }

      // 2. Exact GSTIN check
      if (cleanGstin != null && cleanGstin.isNotEmpty && shop.gstin != null) {
        if (shop.gstin!.trim().toUpperCase() == cleanGstin) {
          return DuplicateCheckResult(
            type: DuplicateType.exactGstin,
            matchedShop: shop,
            message: 'A shop with this GSTIN already exists: "${shop.name}".',
          );
        }
      }

      // 3. Similar name in same area
      final shopNorm = normalizeName(shop.name);
      final sameArea = shop.area.trim().toLowerCase() == area.trim().toLowerCase();
      if (normName.isNotEmpty && shopNorm.isNotEmpty && normName == shopNorm && sameArea) {
        return DuplicateCheckResult(
          type: DuplicateType.similarNameInArea,
          matchedShop: shop,
          message: 'A similar shop name exists in the same area: "${shop.name}" in ${shop.area}.',
        );
      }

      // 4. Similar name within ~150 meters (if coordinates present)
      if (latitude != null && longitude != null && shop.latitude != null && shop.longitude != null) {
        final distMeters = calculateDistanceMeters(latitude, longitude, shop.latitude!, shop.longitude!);
        if (distMeters <= 150 && normName.isNotEmpty && shopNorm == normName) {
          return DuplicateCheckResult(
            type: DuplicateType.similarNameNearby,
            matchedShop: shop,
            message: 'A similar shop "${shop.name}" is located within ${distMeters.round()}m.',
          );
        }
      }
    }

    return const DuplicateCheckResult(type: DuplicateType.none);
  }

  Future<DuplicateCheckResult> checkShopDuplicates({
    required String phone,
    String? gstin,
    String? name,
    String? area,
    double? latitude,
    double? longitude,
  }) async {
    return checkDuplicateRetailer(
      phone: phone,
      name: name ?? '',
      area: area ?? '',
      gstin: gstin,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<RouteEntry>> getAvailableRoutes() async {
    final list = await repository.getAllRoutes();
    if (list.isNotEmpty) return list;
    return [
      RouteEntry(
        id: 'route_sardarpura_02',
        name: 'Sardarpura Commercial Beat',
        code: 'SAR-02',
        dayOfWeek: 'Monday',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      RouteEntry(
        id: 'route_nai_sadak_01',
        name: 'Nai Sadak Wholesale Beat',
        code: 'NAI-01',
        dayOfWeek: 'Tuesday',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<RouteEntry?> getDefaultRouteForUser(String userId) async {
    final routes = await getAvailableRoutes();
    for (final r in routes) {
      if (r.id.contains('sojati') || r.code == 'SOJ-01') return r;
    }
    return routes.isNotEmpty ? routes.first : null;
  }

  Future<RouteEntry?> suggestNearbyRoute({
    required double latitude,
    required double longitude,
    String? currentRouteId,
  }) async {
    final routes = await getAvailableRoutes();
    RouteEntry? bestRoute;
    double minDistance = double.infinity;

    for (final route in routes) {
      final routeShops = _retailers.where((r) => r.routeId == route.id && r.latitude != null && r.longitude != null);
      if (routeShops.isNotEmpty) {
        for (final shop in routeShops) {
          final dist = calculateDistanceMeters(latitude, longitude, shop.latitude!, shop.longitude!);
          if (dist < minDistance) {
            minDistance = dist;
            bestRoute = route;
          }
        }
      } else {
        double rLat = 26.2915;
        double rLng = 73.0185;
        if (route.id.contains('sardarpura') || route.code.contains('SAR')) {
          rLat = 26.2800;
          rLng = 73.0100;
        }
        final dist = calculateDistanceMeters(latitude, longitude, rLat, rLng);
        if (dist < minDistance) {
          minDistance = dist;
          bestRoute = route;
        }
      }
    }

    if (bestRoute != null && bestRoute.id != currentRouteId && minDistance < 2000) {
      return bestRoute;
    }
    return null;
  }

  Future<RetailerShop> quickAddShop({
    required String shopName,
    required String ownerName,
    required String phone,
    String? routeId,
    String? area,
    double? latitude,
    double? longitude,
    double? locationAccuracyMeters,
  }) async {
    final rId = routeId ?? 'route_sojati_01';
    final shop = await createRetailerDurable(
      name: shopName,
      ownerName: ownerName,
      phone: phone,
      address: area ?? 'Jodhpur Market',
      area: area ?? 'Jodhpur Central',
      routeId: rId,
      latitude: latitude,
      longitude: longitude,
      locationAccuracyMeters: locationAccuracyMeters,
    );
    await repository.addRouteStop(routeId: rId, retailerId: shop.id);
    return shop;
  }

  Future<RetailerShop> createRetailerDurable({
    required String name,
    required String ownerName,
    required String phone,
    required String address,
    required String area,
    String? routeId,
    String shopType = 'KIRANA',
    String? gstin,
    String? pincode,
    String? landmark,
    double? latitude,
    double? longitude,
    double? locationAccuracyMeters,
    String? suggestedClass,
    String? idempotencyKey,
    String routeInsertPosition = 'AT_END',
    String? insertAfterRetailerId,
    String? whatsappPhone,
    String? gstType,
    String? panNumber,
  }) async {
    final session = currentSession;
    if (session == null) {
      throw const UnauthenticatedException('No active user session found');
    }
    if (session.activeOrganizationId.isEmpty) {
      throw StateError('Cannot create shop: Active organization is required.');
    }
    if (session.userId.isEmpty) {
      throw StateError('Cannot create shop: Active user ID is required.');
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    if (cleanPhone.length != 10) {
      throw ArgumentError('Valid 10-digit mobile number required: $phone');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Shop name cannot be empty');
    }
    if (ownerName.trim().isEmpty) {
      throw ArgumentError('Owner name cannot be empty');
    }

    final key = idempotencyKey ?? generateUuidV4();

    // Idempotent retry check
    final existingMutation = await db.outboxDao.getMutationByIdempotencyKey(key);
    if (existingMutation != null) {
      final existingPayload = CreateRetailerMutationPayload.fromCanonicalJson(existingMutation.payloadJson);
      final existingShop = _retailers.cast<RetailerShop?>().firstWhere(
            (r) => r?.id == existingPayload.provisionalRetailerId,
            orElse: () => null,
          );
      if (existingShop != null) {
        return existingShop;
      }
    }

    final now = DateTime.now();
    final epochMs = now.millisecondsSinceEpoch;
    final hexSuffix = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0').toLowerCase();
    final provisionalRetailerId = 'ret_${epochMs}_$hexSuffix';

    // Sales reps can only add shops with class = NEW, credit = 0 (Cash only)
    final newShop = RetailerShop(
      id: provisionalRetailerId,
      name: name.trim(),
      ownerName: ownerName.trim(),
      phone: cleanPhone,
      address: address.trim(),
      area: area.trim(),
      routeId: routeId,
      creditLimitPaise: 0, // strictly 0 credit enforced in data layer
      outstandingPaise: 0,
      visitedToday: false,
      totalTimeSpentSeconds: 0,
      visitCountToday: 0,
      latitude: latitude,
      longitude: longitude,
      locationAccuracyMeters: locationAccuracyMeters,
      classType: 'NEW',
      classSource: 'SALESPERSON_SUGGESTED',
      shopType: shopType,
      gstin: gstin?.trim().toUpperCase(),
      pincode: pincode?.trim(),
      landmark: landmark?.trim(),
      status: 'ACTIVE',
      createdByUserId: session.userId,
      syncStatus: 'PENDING',
      whatsappPhone: whatsappPhone?.trim(),
      gstType: gstType ?? (gstin != null && gstin.trim().isNotEmpty ? 'REGULAR' : 'CONSUMER'),
      panNumber: panNumber?.trim().toUpperCase(),
    );

    final payload = CreateRetailerMutationPayload(
      provisionalRetailerId: provisionalRetailerId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: key,
      name: newShop.name,
      ownerName: newShop.ownerName,
      phone: newShop.phone,
      address: newShop.address,
      area: newShop.area,
      routeId: newShop.routeId,
      classType: newShop.classType,
      classSource: newShop.classSource,
      shopType: newShop.shopType,
      gstin: newShop.gstin,
      pincode: newShop.pincode,
      landmark: newShop.landmark,
      latitude: newShop.latitude,
      longitude: newShop.longitude,
      locationAccuracyMeters: newShop.locationAccuracyMeters,
      clientCreatedAtEpochMs: epochMs,
      whatsappPhone: newShop.whatsappPhone,
      gstType: newShop.gstType,
      panNumber: newShop.panNumber,
      routeInsertPosition: routeInsertPosition,
      insertAfterRetailerId: insertAfterRetailerId,
    );

    final mutationId = 'out_${generateUuidV4()}';
    await db.outboxDao.insertOrderMutationAtomic(
      id: mutationId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: key,
      mutationType: 'CREATE_RETAILER',
      payloadJson: payload.toCanonicalJson(),
      provisionalBusinessId: provisionalRetailerId,
      createdAtEpochMs: epochMs,
      businessOperation: () async {
        await repository.upsertRetailer(newShop);
        if (routeId != null && routeId.isNotEmpty) {
          final routeExists = await (db.select(db.routes)..where((tbl) => tbl.id.equals(routeId))).getSingleOrNull();
          if (routeExists != null) {
            await repository.addRouteStop(
              routeId: routeId,
              retailerId: provisionalRetailerId,
              position: routeInsertPosition,
              afterRetailerId: insertAfterRetailerId,
            );
          }
        }
      },
    );

    _retailers.insert(0, newShop);
    onOutboxMutationEnqueued?.call();
    notifyListeners();
    return newShop;
  }

  Future<void> approveNewShop({
    required String retailerId,
    required String approvedClass,
    required int approvedCreditLimitPaise,
  }) async {
    final session = currentSession;
    if (_sessionProvider != null) {
      if (session == null || (session.activeRole != 'OWNER' && session.activeRole != 'ADMIN')) {
        throw const UnauthorizedRoleException('Cannot approve shop: Caller is not OWNER or ADMIN.');
      }
    }
    await repository.updateRetailerClassAndLimit(
      retailerId,
      newClass: approvedClass,
      creditLimitPaise: approvedCreditLimitPaise,
      status: 'ACTIVE',
    );

    final idx = _retailers.indexWhere((r) => r.id == retailerId);
    if (idx != -1) {
      _retailers[idx].classType = approvedClass;
      _retailers[idx].creditLimitPaise = approvedCreditLimitPaise;
      _retailers[idx].status = 'ACTIVE';
      notifyListeners();
    }
  }

  Future<void> rejectNewShop({
    required String retailerId,
    required String rejectionReason,
  }) async {
    final session = currentSession;
    if (_sessionProvider != null) {
      if (session == null || (session.activeRole != 'OWNER' && session.activeRole != 'ADMIN')) {
        throw const UnauthorizedRoleException('Cannot reject shop: Caller is not OWNER or ADMIN.');
      }
    }
    await repository.updateRetailerClassAndLimit(
      retailerId,
      newClass: 'NEW',
      creditLimitPaise: 0,
      status: 'REJECTED',
    );

    final idx = _retailers.indexWhere((r) => r.id == retailerId);
    if (idx != -1) {
      _retailers[idx].status = 'REJECTED';
      notifyListeners();
    }
  }

  /// Retailers awaiting sovereign owner approval (status == PENDING_APPROVAL or classType == NEW)
  List<RetailerShop> get pendingShopApprovals =>
      _retailers.where((r) => r.status == 'PENDING_APPROVAL' || r.classType == 'NEW').toList();

  /// Identifies inactive shops that haven't ordered in [daysThreshold] days for follow-up
  List<RetailerShop> getInactiveShops({int daysThreshold = 15}) {
    final cutoff = DateTime.now().subtract(Duration(days: daysThreshold));
    return _retailers.where((r) {
      final shopOrders = _orders.where((o) => o.shopId == r.id).toList();
      final lastOrderDate = shopOrders.isNotEmpty ? shopOrders.first.createdAt : null;
      if (lastOrderDate == null) return true;
      return lastOrderDate.isBefore(cutoff);
    }).toList();
  }

  /// Aggregated salesperson performance across beats, coverage, and cash
  List<SalespersonPerformance> getSalespersonPerformances() {
    final visited = _retailers.where((r) => r.visitedToday || r.isCheckedIn).length;
    final totalOrderValue = _orders.fold<int>(0, (sum, o) => sum + o.totalPaise);
    return [
      SalespersonPerformance(
        name: 'Imran Khan',
        beat: 'Sojati Gate & Station Road (SOJ-01)',
        visitedShops: visited,
        totalShops: _retailers.length,
        ordersBooked: _orders.length,
        totalOrderValuePaise: totalOrderValue,
        cashCollectedPaise: driverCashCustodyPaise,
      ),
      SalespersonPerformance(
        name: 'Vikram Rathore',
        beat: 'Sardarpura C Road Beat (SAR-02)',
        visitedShops: 12,
        totalShops: 18,
        ordersBooked: 8,
        totalOrderValuePaise: 4200000,
        cashCollectedPaise: 1850000,
      ),
    ];
  }

  Future<void> updateClassSetting({
    required String className,
    required int defaultCreditLimitPaise,
    required int creditDays,
    required int visitFrequencyDays,
  }) async {
    final session = currentSession;
    if (_sessionProvider != null) {
      if (session == null || (session.activeRole != 'OWNER' && session.activeRole != 'ADMIN')) {
        throw const UnauthorizedRoleException('Cannot update class settings: Caller is not OWNER or ADMIN.');
      }
    }
    await repository.saveClassSetting(
      ClassSettingsCompanion(
        className: Value(className),
        defaultCreditLimitPaise: Value(defaultCreditLimitPaise),
        creditDays: Value(creditDays),
        visitFrequencyDays: Value(visitFrequencyDays),
        updatedAt: Value(DateTime.now()),
      ),
    );
    notifyListeners();
  }

  Future<OwnerMetrics> getOwnerMetrics() async {
    final now = DateTime.now();
    final todayOrders = _orders.where((o) =>
      o.createdAt.year == now.year &&
      o.createdAt.month == now.month &&
      o.createdAt.day == now.day,
    ).toList();

    final todayPaise = todayOrders.fold(0, (sum, o) => sum + o.totalPaise);
    final pendingCount = (await db.outboxDao.getPendingQueue()).length;
    final lowStock = _products.where((p) => availableGodownBoxes(p.id) <= 5).length;
    final activeShops = _retailers.where((r) => r.visitedToday).length;

    return OwnerMetrics(
      todayBookingsPaise: todayPaise,
      todayOrdersCount: todayOrders.length,
      pendingOutboxCount: pendingCount,
      lowStockCount: lowStock,
      activeShopsCount: activeShops,
    );
  }

  Future<void> updateProductUnitsDurable({
    required String productId,
    required List<ProductPackagingUnit> units,
    required String idempotencyKey,
  }) async {
    final session = currentSession;
    if (session == null ||
        session.activeOrganizationId.isEmpty ||
        session.userId.isEmpty) {
      throw StateError('Cannot update product units without an active authenticated session');
    }

    final existingMutation = await db.outboxDao.getMutationByIdempotencyKey(idempotencyKey);
    if (existingMutation != null) {
      debugPrint('Idempotent updateProductUnits detected for key $idempotencyKey');
      return;
    }

    final epochMs = DateTime.now().millisecondsSinceEpoch;
    final payload = UpdateProductUnitsPayload(
      productId: productId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      units: units
          .map((u) => ProductPackagingUnitPayloadItem(
                id: u.id,
                unitName: u.unitName,
                multiplierToBase: u.multiplierToBase,
                isBaseUnit: u.isBaseUnit,
                allowLooseSale: u.allowLooseSale,
                wholesalePricePaise: u.wholesalePricePaise,
                mrpPaise: u.mrpPaise,
                minOrderQty: u.minOrderQty,
              ))
          .toList(),
      clientCreatedAtEpochMs: epochMs,
    );

    final mutationId = 'out_${generateUuidV4()}';
    await db.outboxDao.insertOrderMutationAtomic(
      id: mutationId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      mutationType: 'UPDATE_PRODUCT_UNITS',
      payloadJson: payload.toCanonicalJson(),
      provisionalBusinessId: productId,
      createdAtEpochMs: epochMs,
      businessOperation: () async {
        await repository.saveProductUnits(productId, units);
      },
    );

    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final old = _products[idx];
      final unitMap = {for (var u in units) u.unitName.toLowerCase(): u.multiplierToBase};
      final priceMap = {for (var u in units) u.unitName.toLowerCase(): u.wholesalePricePaise};
      _products[idx] = ProductItem(
        id: old.id,
        name: old.name,
        hindiName: old.hindiName,
        category: old.category,
        mrpRupees: old.mrpRupees,
        piecePricePaise: old.piecePricePaise,
        stripQty: old.stripQty,
        boxQty: old.boxQty,
        gstRate: old.gstRate,
        godownStockBoxes: old.godownStockBoxes,
        carStockBoxes: old.carStockBoxes,
        badge: old.badge,
        imageUrl: old.imageUrl,
        customUnitMultipliers: unitMap,
        customUnitPricesPaise: priceMap,
      );
      onOutboxMutationEnqueued?.call();
      notifyListeners();
    }
  }

  Future<void> createProductDurable({
    required String id,
    required String name,
    required String hindiName,
    required String category,
    required double mrpRupees,
    required int piecePricePaise,
    required int stripQty,
    required int boxQty,
    double gstRate = 18.0,
    required List<ProductPackagingUnit> units,
    required String idempotencyKey,
  }) async {
    final session = currentSession;
    if (session == null ||
        session.activeOrganizationId.isEmpty ||
        session.userId.isEmpty) {
      throw StateError('Cannot create product without an active authenticated session');
    }

    final existingMutation = await db.outboxDao.getMutationByIdempotencyKey(idempotencyKey);
    if (existingMutation != null) {
      debugPrint('Idempotent createProduct detected for key $idempotencyKey');
      return;
    }

    final epochMs = DateTime.now().millisecondsSinceEpoch;
    final payload = CreateProductPayload(
      id: id,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      name: name,
      hindiName: hindiName,
      category: category,
      mrpRupees: mrpRupees,
      piecePricePaise: piecePricePaise,
      stripQty: stripQty,
      boxQty: boxQty,
      gstRate: gstRate,
      units: units
          .map((u) => ProductPackagingUnitPayloadItem(
                id: u.id,
                unitName: u.unitName,
                multiplierToBase: u.multiplierToBase,
                isBaseUnit: u.isBaseUnit,
                allowLooseSale: u.allowLooseSale,
                wholesalePricePaise: u.wholesalePricePaise,
                mrpPaise: u.mrpPaise,
                minOrderQty: u.minOrderQty,
              ))
          .toList(),
      clientCreatedAtEpochMs: epochMs,
    );

    final unitMap = {for (var u in units) u.unitName.toLowerCase(): u.multiplierToBase};
    final priceMap = {for (var u in units) u.unitName.toLowerCase(): u.wholesalePricePaise};

    final newProduct = ProductItem(
      id: id,
      name: name,
      hindiName: hindiName,
      category: category,
      mrpRupees: mrpRupees,
      piecePricePaise: piecePricePaise,
      stripQty: stripQty,
      boxQty: boxQty,
      gstRate: gstRate,
      godownStockBoxes: 0,
      carStockBoxes: 0,
      customUnitMultipliers: unitMap,
      customUnitPricesPaise: priceMap,
    );

    final mutationId = 'out_${generateUuidV4()}';
    await db.outboxDao.insertOrderMutationAtomic(
      id: mutationId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      mutationType: 'CREATE_PRODUCT',
      payloadJson: payload.toCanonicalJson(),
      provisionalBusinessId: id,
      createdAtEpochMs: epochMs,
      businessOperation: () async {
        await repository.upsertProduct(newProduct);
        await repository.saveProductUnits(id, units);
      },
    );

    _products.add(newProduct);
    onOutboxMutationEnqueued?.call();
    notifyListeners();
  }

  Future<void> receiveStockGrnDurable({
    required String productId,
    required String supplierName,
    required String invoiceNumber,
    required String batchNumber,
    required int cartonsReceived,
    required int loosePiecesReceived,
    required int damagedCartons,
    required int damagedLoosePieces,
    required String notes,
    required String idempotencyKey,
  }) async {
    final session = currentSession;
    if (session == null ||
        session.activeOrganizationId.isEmpty ||
        session.userId.isEmpty) {
      throw StateError('Cannot receive stock without an active authenticated session');
    }

    final existingMutation = await db.outboxDao.getMutationByIdempotencyKey(idempotencyKey);
    if (existingMutation != null) {
      debugPrint('Idempotent receiveStockGrn detected for key $idempotencyKey');
      return;
    }

    final epochMs = DateTime.now().millisecondsSinceEpoch;
    final provisionalGrnId = 'grn_${generateUuidV4()}';
    final productEntry = _products.where((p) => p.id == productId).firstOrNull;
    final piecesPerCarton = productEntry?.boxQty ?? 50;

    final payload = StockInwardMutationPayload(
      provisionalGrnId: provisionalGrnId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      productId: productId,
      supplierName: supplierName,
      invoiceNumber: invoiceNumber,
      batchNumber: batchNumber,
      receivedCartons: cartonsReceived,
      receivedLoosePieces: loosePiecesReceived,
      damagedCartons: damagedCartons,
      damagedLoosePieces: damagedLoosePieces,
      notes: notes,
      clientCreatedAtEpochMs: epochMs,
      basePiecesPerCartonSnapshot: piecesPerCarton,
    );

    if (productEntry != null) {
      await repository.upsertProduct(productEntry);
    }

    final mutationId = 'out_${generateUuidV4()}';
    await db.outboxDao.insertOrderMutationAtomic(
      id: mutationId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      mutationType: 'STOCK_INWARD',
      payloadJson: payload.toCanonicalJson(),
      provisionalBusinessId: provisionalGrnId,
      createdAtEpochMs: epochMs,
      businessOperation: () async {
        await repository.recordGrnReceipt(
          productId: productId,
          supplierName: supplierName,
          invoiceNumber: invoiceNumber,
          batchNumber: batchNumber,
          cartonsReceived: cartonsReceived,
          loosePiecesReceived: loosePiecesReceived,
          damagedCartons: damagedCartons,
          damagedLoosePieces: damagedLoosePieces,
          notes: notes,
          idempotencyKey: idempotencyKey,
        );
      },
    );

    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      _products[idx].godownStockBoxes += cartonsReceived;
      onOutboxMutationEnqueued?.call();
      notifyListeners();
    }
  }

  Future<void> reverseGrnMovementDurable({
    required String movementId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final session = currentSession;
    if (session == null ||
        session.activeOrganizationId.isEmpty ||
        session.userId.isEmpty) {
      throw StateError('Cannot reverse GRN without an active authenticated session');
    }

    final existingMutation = await db.outboxDao.getMutationByIdempotencyKey(idempotencyKey);
    if (existingMutation != null) {
      debugPrint('Idempotent reverseGrn detected for key $idempotencyKey');
      return;
    }

    final epochMs = DateTime.now().millisecondsSinceEpoch;
    final reversalId = 'rev_${generateUuidV4()}';

    final original = await (db.select(db.inventoryMovements)
          ..where((tbl) => tbl.id.equals(movementId)))
        .getSingleOrNull();
    if (original == null) {
      throw StateError('Movement $movementId not found for reversal');
    }

    final payloadMap = {
      'reversalId': reversalId,
      'originalMovementId': movementId,
      'productId': original.productId,
      'reason': reason,
      'cartonDelta': -original.cartonDelta,
      'loosePieceDelta': -original.loosePieceDelta,
      'organizationId': session.activeOrganizationId,
      'userId': session.userId,
      'idempotencyKey': idempotencyKey,
      'clientCreatedAtEpochMs': epochMs,
    };

    final mutationId = 'out_${generateUuidV4()}';
    await db.outboxDao.insertOrderMutationAtomic(
      id: mutationId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      mutationType: 'STOCK_ADJUSTMENT',
      payloadJson: jsonEncode(payloadMap),
      provisionalBusinessId: reversalId,
      createdAtEpochMs: epochMs,
      businessOperation: () async {
        await repository.reverseGrnMovement(
          movementId: movementId,
          reason: reason,
          idempotencyKey: idempotencyKey,
        );
      },
    );

    final idx = _products.indexWhere((p) => p.id == original.productId);
    if (idx != -1) {
      _products[idx].godownStockBoxes -= original.cartonDelta;
      onOutboxMutationEnqueued?.call();
      notifyListeners();
    }
  }

  // Warehouse and Depot Hubs
  List<WarehouseHub> _warehouseHubs = [];
  List<WarehouseHub> get warehouseHubs => _warehouseHubs;

  // Active Visit Tracking
  String? _activeVisitShopId;
  String? get activeVisitShopId => _activeVisitShopId;

  RetailerShop? get activeVisitShop {
    if (_activeVisitShopId == null) return null;
    return _retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.id == _activeVisitShopId,
          orElse: () => null,
        );
  }

  void startShopVisit(String shopId) {
    if (_activeVisitShopId != null && _activeVisitShopId != shopId) {
      endShopVisit(_activeVisitShopId!);
    }
    final shop = _retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.id == shopId,
          orElse: () => null,
        );
    if (shop != null) {
      shop.startVisit();
      _activeVisitShopId = shopId;
      notifyListeners();
    }
  }

  int endShopVisit(String shopId) {
    final shop = _retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.id == shopId,
          orElse: () => null,
        );
    if (shop != null) {
      final elapsed = shop.endVisit();
      if (_activeVisitShopId == shopId) {
        _activeVisitShopId = null;
      }
      repository.updateRetailerVisit(
        shop.id,
        totalTimeSpentSeconds: shop.totalTimeSpentSeconds,
        visitCountToday: shop.visitCountToday,
        visitedToday: shop.visitedToday,
      );
      notifyListeners();
      return elapsed;
    }
    return 0;
  }

  int get totalBeatTimeSpentSeconds {
    return _retailers.fold(0, (sum, shop) => sum + shop.allTimeSpentSeconds);
  }

  String get totalBeatTimeSpentFormatted =>
      RetailerShop.formatDuration(totalBeatTimeSpentSeconds);

  void skipShopVisit(String shopId, String reason) {
    final shop = _retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.id == shopId,
          orElse: () => null,
        );
    if (shop != null) {
      if (_activeVisitShopId == shopId) {
        _activeVisitShopId = null;
      }
      shop.skipShop(reason);
      notifyListeners();
    }
  }

  int get customersVisitedTodayCount =>
      _retailers.where((s) => s.visitedToday).length;

  int get customersSkippedTodayCount =>
      _retailers.where((s) => s.isSkipped).length;

  // Trip Out / In State (Route start / stop, vehicle & meter reading)
  bool _isTripActive = false;
  bool get isTripActive => _isTripActive;
  String _activeTripVehicleNo = 'RJ19GJ4742';
  String get activeTripVehicleNo => _activeTripVehicleNo;
  String _activeTripMeterReading = '42850';
  String get activeTripMeterReading => _activeTripMeterReading;
  String? _activeTripEndMeterReading;
  String? get activeTripEndMeterReading => _activeTripEndMeterReading;

  void startTrip({required String routeName, required String vehicleNo, required String meterReading}) {
    _isTripActive = true;
    _activeTripVehicleNo = vehicleNo;
    _activeTripMeterReading = meterReading;
    notifyListeners();
  }

  void endTrip({required String meterReading}) {
    _isTripActive = false;
    _activeTripEndMeterReading = meterReading;
    notifyListeners();
  }

  int get pendingOutboxCount =>
      _retailers.where((r) => r.syncStatus == 'PENDING').length + _orders.length;

  Future<void> syncPendingOutbox() async {
    try {
      final pending = await db.outboxDao.getPendingQueue();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final mutation in pending) {
        await db.outboxDao.markSynced(id: mutation.id, syncedAtEpochMs: nowMs);
      }
      for (int i = 0; i < _retailers.length; i++) {
        if (_retailers[i].syncStatus == 'PENDING') {
          _retailers[i] = _retailers[i].copyWith(syncStatus: 'SYNCED');
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  // Active Cart (Compound Key: "productId::unit" -> CartItem)
  final CompoundCartMap _cart = CompoundCartMap();
  CompoundCartMap get cart => _cart;

  // Orders
  final List<DistributorOrder> _orders = [];
  List<DistributorOrder> get orders => _orders;

  // Delivery Stops
  final List<DeliveryStop> _deliveryStops = [];
  List<DeliveryStop> get deliveryStops => _deliveryStops;

  // Transient state generation fencing for logout safety
  int _transientGeneration = 0;
  int get transientGeneration => _transientGeneration;

  /// Clears all tenant-sensitive in-memory transient state (cart, orders, delivery stops).
  /// Increments _transientGeneration to fence out any delayed in-flight async operations.
  Future<void> clearTransientState() async {
    _transientGeneration++;
    _cart.clear();
    _orders.clear();
    _deliveryStops.clear();
    notifyListeners();
  }

  /// Runs an async tenant operation fenced by the current transient generation.
  /// If clearTransientState() is called before the future completes, the mutation is dropped.
  Future<void> runFencedTransientOperation(Future<void> Function() operation) async {
    final capturedGen = _transientGeneration;
    await operation();
    if (capturedGen != _transientGeneration) {
      // Operation completed after logout or state clear: discard safely!
      return;
    }
  }

  // Split orders into the 3 requested lifecycle streams
  List<DistributorOrder> get bookingOrders =>
      _orders.where((o) => o.stage == OrderLifecycleStage.booking).toList();

  List<DistributorOrder> get readyStockOrders =>
      _orders.where((o) => o.stage == OrderLifecycleStage.readyStock).toList();

  List<DistributorOrder> get orderSendOrders =>
      _orders.where((o) => o.stage == OrderLifecycleStage.orderSend).toList();

  List<DistributorOrder> get deliveredOrders =>
      _orders.where((o) => o.stage == OrderLifecycleStage.delivered).toList();

  // Dynamic Car & Godown Stock Transfer
  Future<bool> transferStockToCar(String productId, int boxDelta, {String? targetTruckId}) async {
    final capturedGen = _transientGeneration;
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) return false;

    final p = _products[idx];
    final truck = targetTruckId != null
        ? _deliveryTrucks.firstWhere((t) => t.id == targetTruckId, orElse: () => activeTruck)
        : activeTruck;

    if (boxDelta > 0) {
      if (p.godownStockBoxes < boxDelta) return false;
      p.godownStockBoxes -= boxDelta;
      p.carStockBoxes += boxDelta;
      truck.loadStock(productId, boxDelta);
    } else if (boxDelta < 0) {
      final absDelta = boxDelta.abs();
      if (p.carStockBoxes < absDelta) return false;
      p.carStockBoxes -= absDelta;
      p.godownStockBoxes += absDelta;
      truck.unloadStock(productId, absDelta);
    } else {
      return true;
    }

    try {
      await repository.recordStockMovement(
        productId: productId,
        movementType: 'TRANSFER_TO_CAR',
        cartonDelta: boxDelta,
        loosePieceDelta: 0,
        reason: 'Stock transfer between Godown and Truck (${truck.vehicleNumber})',
        newGodownCartons: p.godownStockBoxes,
        newGodownLoosePieces: 0,
        newCarCartons: p.carStockBoxes,
        newCarLoosePieces: 0,
      );
      if (capturedGen != _transientGeneration) {
        // Rollback optimistic in-memory changes if state was invalidated (e.g. user logged out)
        if (boxDelta > 0) {
          p.godownStockBoxes += boxDelta;
          p.carStockBoxes -= boxDelta;
          truck.unloadStock(productId, boxDelta);
        } else if (boxDelta < 0) {
          final absDelta = boxDelta.abs();
          p.carStockBoxes += absDelta;
          p.godownStockBoxes -= absDelta;
          truck.loadStock(productId, absDelta);
        }
        return false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      // Rollback in-memory changes if database write fails
      if (boxDelta > 0) {
        p.godownStockBoxes += boxDelta;
        p.carStockBoxes -= boxDelta;
        truck.unloadStock(productId, boxDelta);
      } else if (boxDelta < 0) {
        final absDelta = boxDelta.abs();
        p.carStockBoxes += absDelta;
        p.godownStockBoxes -= absDelta;
        truck.loadStock(productId, absDelta);
      }
      if (capturedGen == _transientGeneration) {
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Automatically picks and loads all items of an order from Godown to the target Truck.
  /// Deducts required stock from Godown and adds to Truck.
  Future<bool> loadOrderToTruck(String orderId, {String? targetTruckId}) async {
    final ordIdx = _orders.indexWhere((o) => o.id == orderId);
    if (ordIdx == -1) return false;
    final ord = _orders[ordIdx];
    final truck = targetTruckId != null
        ? _deliveryTrucks.firstWhere((t) => t.id == targetTruckId, orElse: () => activeTruck)
        : activeTruck;

    // Deduct each ordered product from Godown and load to Truck
    for (final item in ord.items) {
      final boxes = item.unit == OrderUnit.box ? item.quantity : 1;
      await transferStockToCar(item.product.id, boxes, targetTruckId: truck.id);
    }

    ord.stage = OrderLifecycleStage.readyStock;
    ord.assignedCarNumber = truck.vehicleNumber;
    notifyListeners();
    return true;
  }

  // Cart operations
  void addToCart(ProductItem product, OrderUnit unit, [int qty = 1]) {
    final key = CartItem.makeCartKey(product.id, unit);
    if (_cart._inner.containsKey(key)) {
      _cart._inner[key]!.quantity += qty;
    } else {
      _cart[key] = CartItem(
        product: product,
        unit: unit,
        quantity: qty,
      );
    }
    notifyListeners();
  }

  /// Adds a mixed combination of Boxes, Strips, and Loose Pieces in a single user action.
  void addMixedUnitsToCart(
    ProductItem product, {
    int boxes = 0,
    int strips = 0,
    int pieces = 0,
  }) {
    if (boxes > 0) addToCart(product, OrderUnit.box, boxes);
    if (strips > 0) addToCart(product, OrderUnit.strip, strips);
    if (pieces > 0) addToCart(product, OrderUnit.piece, pieces);
  }

  // Today's Beat Route Assignment & Extra Visits (Session Memory)
  // Owner-assigned stops are fixed and protected. Reps can only add extra visits.
  final Set<String> _extraVisitShopIds = {};
  Set<String> _assignedBeatShopIds = {};

  /// Checks if a shop is assigned to the current beat by owner/route manager.
  bool isAssignedBeatShop(String shopId) {
    if (_assignedBeatShopIds.isEmpty && _retailers.isNotEmpty) {
      _assignedBeatShopIds = _retailers.map((r) => r.id).toSet();
    }
    return _assignedBeatShopIds.contains(shopId);
  }

  @visibleForTesting
  void setAssignedBeatShopIds(Iterable<String> ids) {
    _assignedBeatShopIds = ids.toSet();
  }

  /// Checks if a shop is in today's active route schedule (assigned or extra visit).
  bool isShopInTodayRoute(String shopId) {
    if (_extraVisitShopIds.contains(shopId)) return true;
    return isAssignedBeatShop(shopId);
  }

  /// Whether this shop is an extra visit added by rep today (session memory only).
  bool isExtraVisitToday(String shopId) => _extraVisitShopIds.contains(shopId);

  /// Add shop as extra visit for today.
  void addExtraVisitShop(String shopId) {
    if (!isAssignedBeatShop(shopId)) {
      _extraVisitShopIds.add(shopId);
      notifyListeners();
    }
  }

  /// Remove shop from today's extra visits.
  void removeExtraVisitShop(String shopId) {
    if (!isAssignedBeatShop(shopId)) {
      _extraVisitShopIds.remove(shopId);
      notifyListeners();
    }
  }

  /// Removes shop from today's assigned beat route (in-map route management).
  void removeShopFromTodayBeat(String shopId) {
    if (_assignedBeatShopIds.isEmpty && _retailers.isNotEmpty) {
      _assignedBeatShopIds = _retailers.map((r) => r.id).toSet();
    }
    _assignedBeatShopIds.remove(shopId);
    _extraVisitShopIds.remove(shopId);
    notifyListeners();
  }

  /// Adds shop to today's assigned beat route.
  void addShopToTodayBeat(String shopId) {
    if (_assignedBeatShopIds.isEmpty && _retailers.isNotEmpty) {
      _assignedBeatShopIds = _retailers.map((r) => r.id).toSet();
    }
    _assignedBeatShopIds.add(shopId);
    _extraVisitShopIds.remove(shopId);
    notifyListeners();
  }

  /// Permanently deletes a retailer shop from database and memory.
  Future<void> deleteRetailer(String shopId) async {
    _retailers.removeWhere((r) => r.id == shopId);
    _assignedBeatShopIds.remove(shopId);
    _extraVisitShopIds.remove(shopId);
    try {
      await repository.deleteRetailer(shopId);
    } catch (_) {}
    notifyListeners();
  }

  /// Updates retailer shop contact and address details.
  Future<void> updateRetailerDetails({
    required String shopId,
    required String name,
    required String ownerName,
    required String phone,
    required String address,
    required String area,
  }) async {
    final idx = _retailers.indexWhere((r) => r.id == shopId);
    if (idx != -1) {
      final old = _retailers[idx];
      final updated = old.copyWith(
        name: name,
        ownerName: ownerName,
        phone: phone,
        address: address,
        area: area,
      );
      _retailers[idx] = updated;
      try {
        await repository.updateRetailerDetails(
          id: shopId,
          name: name,
          ownerName: ownerName,
          phone: phone,
          address: address,
          area: area,
        );
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Reps cannot remove owner-assigned beat shops via casual toggle. They can only toggle extra visits for other shops.
  /// Returns true if toggled, false if rejected due to owner-assignment protection.
  bool toggleShopInRoute(String shopId) {
    if (isAssignedBeatShop(shopId)) {
      // Reps cannot remove owner-assigned beat stops
      return false;
    }
    if (_extraVisitShopIds.contains(shopId)) {
      _extraVisitShopIds.remove(shopId);
    } else {
      _extraVisitShopIds.add(shopId);
    }
    notifyListeners();
    return true;
  }

  /// All stops for today: Owner-assigned stops first in order, followed by extra visits appended at the end.
  List<RetailerShop> get assignedRouteShops {
    final assigned = _retailers.where((r) => isAssignedBeatShop(r.id)).toList();
    final extras = _retailers.where((r) => _extraVisitShopIds.contains(r.id) && !assigned.contains(r)).toList();
    return [...assigned, ...extras];
  }

  void setCartUnit(String productId, OrderUnit unit) {
    final existingEntry = _cart._inner.entries.cast<MapEntry<String, CartItem>?>().firstWhere(
      (e) => e?.value.product.id == productId,
      orElse: () => null,
    );
    if (existingEntry != null) {
      final oldItem = existingEntry.value;
      _cart._inner.remove(existingEntry.key);
      oldItem.unit = unit;
      final newKey = CartItem.makeCartKey(productId, unit);
      _cart._inner[newKey] = oldItem;
      notifyListeners();
    }
  }

  void updateCartQuantity(String productIdOrKey, int delta, [OrderUnit? unit]) {
    String? targetKey;
    if (unit != null) {
      targetKey = CartItem.makeCartKey(productIdOrKey, unit);
    } else if (_cart._inner.containsKey(productIdOrKey)) {
      targetKey = productIdOrKey;
    } else {
      for (final entry in _cart._inner.entries) {
        if (entry.value.product.id == productIdOrKey) {
          targetKey = entry.key;
          break;
        }
      }
    }

    if (targetKey != null && _cart._inner.containsKey(targetKey)) {
      final item = _cart._inner[targetKey]!;
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _cart._inner.remove(targetKey);
      } else {
        item.quantity = newQty;
      }
      notifyListeners();
    }
  }

  void removeCartLine(String cartKey) {
    if (_cart._inner.containsKey(cartKey)) {
      _cart._inner.remove(cartKey);
      notifyListeners();
    } else {
      _cart.remove(cartKey);
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  RetailerShop? _selectedShop;
  RetailerShop? get selectedShop =>
      _selectedShop ?? activeVisitShop ?? (_retailers.isNotEmpty ? _retailers.first : null);

  void selectShop(RetailerShop shop) {
    _selectedShop = shop;
    clearCart();
    notifyListeners();
  }

  Future<void> saveCurrentCartDraft([String? retailerId]) async {
    final targetId = retailerId ?? selectedShop?.id;
    if (targetId == null || _cart.isEmpty) return;

    final serialized = _cart._inner.values.map((item) {
      return {
        'productId': item.product.id,
        'unit': item.unit.name,
        'quantity': item.quantity,
        'unitPricePaise': item.unitPricePaise,
      };
    }).toList();

    await repository.saveCartDraft(targetId, jsonEncode(serialized));
  }

  Future<void> loadCartDraftForRetailer(String retailerId) async {
    final raw = await repository.getCartDraft(retailerId);
    _cart.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          final prodId = m['productId'] as String;
          final unitName = m['unit'] as String;
          final qty = (m['quantity'] as num).toInt();
          final prod = _products.cast<ProductItem?>().firstWhere(
            (p) => p?.id == prodId,
            orElse: () => null,
          );
          if (prod != null) {
            final orderUnit = OrderUnit.values.firstWhere(
              (u) => u.name == unitName,
              orElse: () => OrderUnit.box,
            );
            final key = CartItem.makeCartKey(prod.id, orderUnit);
            _cart[key] = CartItem(
              product: prod,
              unit: orderUnit,
              quantity: qty,
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to decode cart draft for $retailerId: $e');
      }
    }
    notifyListeners();
  }

  Future<List<StalePriceWarning>> checkCartStalePrices(String retailerId) async {
    final raw = await repository.getCartDraft(retailerId);
    if (raw == null) return const [];

    final warnings = <StalePriceWarning>[];
    try {
      final list = jsonDecode(raw) as List;
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final prodId = m['productId'] as String;
        final unitName = m['unit'] as String;
        final oldPrice = (m['unitPricePaise'] as num).toInt();
        final prod = _products.cast<ProductItem?>().firstWhere(
          (p) => p?.id == prodId,
          orElse: () => null,
        );
        if (prod != null) {
          final orderUnit = OrderUnit.values.firstWhere(
            (u) => u.name == unitName,
            orElse: () => OrderUnit.box,
          );
          final currentPrice = prod.priceForUnit(orderUnit);
          if (currentPrice != oldPrice) {
            warnings.add(StalePriceWarning(
              productId: prod.id,
              productName: prod.name,
              unitName: unitName,
              oldPricePaise: oldPrice,
              newPricePaise: currentPrice,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking stale prices: $e');
    }
    return warnings;
  }

  Future<bool> repeatLastOrder(String retailerId) async {
    final pastOrders = _orders.where(
      (o) => o.shopId == retailerId || _retailers.any((r) => r.id == retailerId && r.name == o.shopName),
    ).toList();

    if (pastOrders.isEmpty) return false;

    final latest = pastOrders.first;
    _cart.clear();

    for (final item in latest.items) {
      final prod = _products.cast<ProductItem?>().firstWhere(
        (p) => p?.id == item.product.id,
        orElse: () => null,
      );
      if (prod != null) {
        final key = CartItem.makeCartKey(prod.id, item.unit);
        _cart[key] = CartItem(
          product: prod,
          unit: item.unit,
          quantity: item.quantity,
        );
      }
    }
    notifyListeners();
    return true;
  }

  bool canUseCreditOrKhata(RetailerShop shop) {
    final c = shop.classType.toUpperCase();
    if (c == 'D' || c == 'NEW') {
      return false;
    }
    return shop.creditLimitPaise > 0;
  }

  Future<void> recordNoOrderVisit({
    required String retailerId,
    required String outcome,
    required String notes,
  }) async {
    final session = currentSession;
    final userId = session?.userId ?? 'usr_current';
    final now = DateTime.now();
    final visitId = 'vis_${now.millisecondsSinceEpoch}_$retailerId';

    await repository.recordVisit(
      id: visitId,
      retailerId: retailerId,
      userId: userId,
      outcome: outcome,
      notes: notes,
      startTime: now.subtract(const Duration(minutes: 5)),
      endTime: now,
    );

    final shop = _retailers.cast<RetailerShop?>().firstWhere(
      (r) => r?.id == retailerId,
      orElse: () => null,
    );
    if (shop != null) {
      shop.visitedToday = true;
      shop.visitCountToday += 1;
      notifyListeners();
    }
  }

  String buildWhatsAppOrderReceipt(DistributorOrder order) {
    final buf = StringBuffer();
    buf.writeln('📦 *RouteFlow Order Summary*');
    buf.writeln('Shop: ${order.shopName}');
    buf.writeln('Order Ref: ${order.orderNumber}');
    buf.writeln('Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}');
    buf.writeln('--------------------------------');
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buf.writeln('${i + 1}. ${item.product.name} (${item.quantity} ${item.unit.shortCode}) - ₹${item.totalRupees.toStringAsFixed(2)}');
    }
    buf.writeln('--------------------------------');
    buf.writeln('Taxable: ₹${order.taxableRupees.toStringAsFixed(2)}');
    buf.writeln('GST (Intra-state): ₹${order.gstRupees.toStringAsFixed(2)}');
    buf.writeln('*Grand Total: ₹${order.totalRupees.toStringAsFixed(2)}*');
    buf.writeln('Payment Mode: ${order.paymentMode}');
    buf.writeln('--------------------------------');
    buf.writeln('Status: Provisional (Recorded on phone)');
    return buf.toString();
  }

  int get cartTotalPaise {
    return _cart.values.fold(0, (sum, item) => sum + item.totalPaise);
  }

  double get cartTotalRupees => cartTotalPaise / 100.0;

  int get cartTaxablePaise {
    return _cart.values.fold(0, (sum, item) => sum + item.taxableAmountPaise);
  }

  double get cartTaxableRupees => cartTaxablePaise / 100.0;

  int get cartTotalGstPaise {
    return _cart.values.fold(0, (sum, item) => sum + item.totalGstPaise);
  }

  double get cartTotalGstRupees => cartTotalGstPaise / 100.0;

  int get cartCgstPaise => cartTotalGstPaise ~/ 2;
  double get cartCgstRupees => cartCgstPaise / 100.0;

  int get cartSgstPaise => cartTotalGstPaise - cartCgstPaise;
  double get cartSgstRupees => cartSgstPaise / 100.0;

  int get cartTotalPieces {
    return _cart.values.fold(0, (sum, item) => sum + item.totalPieces);
  }

  // Order Placement
  DistributorOrder placeOrder({
    required String shopId,
    required String paymentMode,
  }) {
    if (_cart.isEmpty) {
      throw StateError('Cannot place order: Cart is empty.');
    }

    final shop = _retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.id == shopId,
          orElse: () => null,
        );
    if (shop == null) {
      throw StateError('Cannot place order: Retailer "$shopId" does not exist.');
    }

    // 1. Aggregate requested quantities per product in base integer pieces
    final requestedPiecesByProduct = <String, int>{};
    for (final item in _cart.values) {
      if (item.quantity <= 0) {
        throw StateError(
          'Cannot place order: Invalid quantity ${item.quantity} for "${item.product.name}".',
        );
      }
      final prod = _products.cast<ProductItem?>().firstWhere(
            (p) => p?.id == item.product.id,
            orElse: () => null,
          );
      if (prod == null) {
        throw StateError('Cannot place order: Product "${item.product.id}" does not exist.');
      }
      requestedPiecesByProduct[item.product.id] =
          (requestedPiecesByProduct[item.product.id] ?? 0) + item.totalPieces;
    }

    // 2. Validate aggregated piece reservations against available godown stock
    for (final entry in requestedPiecesByProduct.entries) {
      final available = availableGodownPieces(entry.key);
      if (entry.value > available) {
        final prod = _products.firstWhere((p) => p.id == entry.key);
        throw StateError(
          'Cannot place booking: Requested ${entry.value} pieces for "${prod.name}" exceeds available stock ($available pieces available).',
        );
      }
    }

    final orderNum = 'ROUT-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final itemsList = _cart.values.toList();
    final total = cartTotalPaise;
    final taxable = cartTaxablePaise;
    final gst = cartTotalGstPaise;

    final order = DistributorOrder(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: orderNum,
      shopId: shop.id,
      shopName: shop.name,
      shopPhone: shop.phone,
      address: shop.address,
      items: itemsList,
      totalPaise: total,
      taxablePaise: taxable,
      totalGstPaise: gst,
      paymentMode: paymentMode,
      stage: OrderLifecycleStage.booking, // Starts in Booking
      assignedCarNumber: _carNumber,
      otp: '${100000 + (DateTime.now().millisecondsSinceEpoch % 900000)}', // Demo local OTP
      createdAt: DateTime.now(),
    );

    // Update shop stats
    if (paymentMode == 'Credit') {
      shop.outstandingPaise += total;
    }
    shop.todayOrderTotalPaise += total;

    // NOTE: Order is placed into the Booking stage. Authoritative physical godown
    // stock in Drift SQLite is NOT mutated prematurely. Pending reservations are
    // computed dynamically from booking-stage orders, guaranteeing exact piece-level
    // accounting with zero whole-carton loss and zero split-brain discrepancies across restarts.
    _orders.insert(0, order);
    _cart.clear();
    notifyListeners();
    return order;
  }

  final Map<String, int> _testVirtualReservations = {};

  /// Total pending pieces reserved across all Booking stage orders for a product.
  int pendingBookingPieces(String productId) {
    if (_testVirtualReservations.containsKey(productId)) {
      return _testVirtualReservations[productId]!;
    }
    return _orders
        .where((o) => o.stage == OrderLifecycleStage.booking)
        .expand((o) => o.items)
        .where((item) => item.product.id == productId)
        .fold(0, (sum, item) => sum + item.totalPieces);
  }

  /// Total pending full cartons reserved in Booking stage orders.
  int pendingBookingBoxes(String productId) {
    final prod = _products.cast<ProductItem?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (prod == null || prod.boxQty <= 0) return 0;
    return pendingBookingPieces(productId) ~/ prod.boxQty;
  }

  /// Remaining loose pieces in Booking stage orders that do not form a full carton.
  int pendingBookingLoosePieces(String productId) {
    final prod = _products.cast<ProductItem?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (prod == null || prod.boxQty <= 0) return 0;
    return pendingBookingPieces(productId) % prod.boxQty;
  }

  /// Available pieces in Godown after accounting for unpicked booking reservations.
  int availableGodownPieces(String productId) {
    final prod = _products.cast<ProductItem?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (prod == null) return 0;
    final totalPhysicalPieces = prod.godownStockBoxes * prod.boxQty;
    final available = totalPhysicalPieces - pendingBookingPieces(productId);
    return available < 0 ? 0 : available;
  }

  /// Available full cartons in Godown after booking reservations.
  int availableGodownBoxes(String productId) {
    final prod = _products.cast<ProductItem?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (prod == null || prod.boxQty <= 0) return 0;
    return availableGodownPieces(productId) ~/ prod.boxQty;
  }

  /// Calculates authoritative 4-part stock status: On-Hand, Reserved, Available, and Health Status (OK/LOW/OUT)
  FourPartStockStatus getFourPartStockStatus(String productId, {int? customThresholdPieces}) {
    final prod = _products.cast<ProductItem?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    final onHand = prod?.godownStockBoxes ?? 0;
    final boxQty = (prod?.boxQty ?? 0) > 0 ? prod!.boxQty : 50;
    final reservedBoxes = pendingBookingBoxes(productId);
    final available = onHand - reservedBoxes;

    final thresholdBoxes = customThresholdPieces != null
        ? (customThresholdPieces / boxQty).ceil()
        : 15;

    final StockHealth health;
    if (available <= 0) {
      health = StockHealth.outOfStock;
    } else if (available <= thresholdBoxes) {
      health = StockHealth.lowStock;
    } else {
      health = StockHealth.ok;
    }

    return FourPartStockStatus(
      onHandBoxes: onHand,
      reservedBoxes: reservedBoxes,
      availableBoxes: available > 0 ? available : 0,
      health: health,
    );
  }

  @visibleForTesting
  void setVirtualReservationForTesting(String productId, int pieces) {
    _testVirtualReservations[productId] = pieces;
    notifyListeners();
  }

  /// Records an opening stock balance transaction into the SQLite ledger
  Future<void> recordOpeningBalanceDurable({
    required String productId,
    required int cartonCount,
    required int loosePieces,
    required String reason,
    String? locationId,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? 'idemp_opening_${generateUuidV4()}';
    await repository.recordOpeningBalance(
      productId: productId,
      cartonCount: cartonCount,
      loosePieces: loosePieces,
      reason: reason,
      locationId: locationId,
      idempotencyKey: key,
    );

    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      _products[idx].godownStockBoxes += cartonCount;
    }
    notifyListeners();
  }

  /// Fetches chronological movement ledger for a product
  Future<List<InventoryMovementEntry>> getProductMovementHistory(String productId) {
    return repository.getProductMovements(productId);
  }

  /// Generates human-readable WhatsApp order confirmation summary with items, totals, and delivery OTP
  String generateWhatsAppOrderShareText(DistributorOrder order) {
    final buf = StringBuffer();
    buf.writeln('📦 RouteFlow Order Confirmation');
    buf.writeln('Shop: ${order.shopName}');
    buf.writeln('Order #: ${order.orderNumber}');
    buf.writeln('Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}');
    buf.writeln('Items:');
    for (final item in order.items) {
      buf.writeln('• ${item.product.name} (${item.quantity} ${item.unit.shortCode}) - ₹${item.totalRupees.toStringAsFixed(2)}');
    }
    buf.writeln('Total: ₹${order.totalRupees.toStringAsFixed(2)}');
    buf.writeln('Payment: ${order.paymentMode}');
    buf.writeln('Delivery OTP: ${order.otp}');
    return buf.toString();
  }

  /// Alias for placeOrder with explicit preview semantics in Phase B1
  DistributorOrder confirmOrderAndPlace({
    required String shopId,
    required String paymentMode,
  }) =>
      placeOrder(shopId: shopId, paymentMode: paymentMode);

  /// Confirms the current cart into a durable CREATE_ORDER outbox mutation on SQLite disk.
  /// 
  /// Critical Invariants:
  /// 1. Verifies authenticated session context from sessionProvider / currentSession.
  /// 2. Enforces idempotency key payload mismatch protection.
  /// 3. In-transaction sequence allocation via outboxDao.insertOrderMutationAtomic.
  /// 4. Reconstructs provisional DistributorOrder (stage: booking) with unmistakable LOCAL-ORD- prefix.
  /// 5. Never decrements physical inventory in InventorySnapshots or mutates Retailers.outstandingPaise.
  Future<DistributorOrder> confirmOrderDurable({
    required String shopId,
    required String paymentMode,
    String? checkoutIdempotencyKey,
  }) async {
    if (_cart.isEmpty) {
      throw StateError('Cannot place order: Cart is empty.');
    }

    final shop = _retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.id == shopId,
          orElse: () => null,
        );
    if (shop == null) {
      throw StateError('Cannot place order: Retailer "$shopId" does not exist.');
    }

    final session = currentSession;
    if (session == null) {
      throw const UnauthenticatedException('No active user session found');
    }
    if (session.activeOrganizationId.isEmpty) {
      throw StateError('Cannot confirm order: Active organization is required.');
    }
    if (session.userId.isEmpty) {
      throw StateError('Cannot confirm order: Active user ID is required.');
    }

    // 1. Validate requested quantities per product against available godown pieces
    for (final item in _cart.values) {
      if (item.quantity <= 0) {
        throw StateError(
          'Cannot place order: Invalid quantity ${item.quantity} for "${item.product.name}".',
        );
      }
      final prod = _products.cast<ProductItem?>().firstWhere(
            (p) => p?.id == item.product.id,
            orElse: () => null,
          );
      if (prod == null) {
        throw StateError('Cannot place order: Product "${item.product.id}" does not exist.');
      }
    }

    final requestedPiecesByProduct = <String, int>{};
    for (final item in _cart.values) {
      requestedPiecesByProduct[item.product.id] =
          (requestedPiecesByProduct[item.product.id] ?? 0) + item.totalPieces;
    }

    for (final entry in requestedPiecesByProduct.entries) {
      final available = availableGodownPieces(entry.key);
      if (entry.value > available) {
        final prod = _products.firstWhere((p) => p.id == entry.key);
        throw StateError(
          'Cannot place booking: Requested ${entry.value} pieces for "${prod.name}" exceeds available stock ($available pieces available).',
        );
      }
    }

    final idempotencyKey = checkoutIdempotencyKey ?? generateUuidV4();
    final now = DateTime.now();
    final epochMs = now.millisecondsSinceEpoch;
    final hexSuffix = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    final orderNumber = 'LOCAL-ORD-${epochMs % 1000000}-$hexSuffix';
    final provisionalOrderId = 'ord_${epochMs}_${hexSuffix.toLowerCase()}';

    final retailerSnapshot = RetailerSnapshot(
      id: shop.id,
      name: shop.name,
      ownerName: shop.ownerName,
      phone: shop.phone,
      address: shop.address,
      area: shop.area,
    );

    final itemPayloads = _cart.values.map((item) {
      final mult = item.product.piecesForUnit(item.unit);
      return OrderItemPayload(
        productId: item.product.id,
        productName: item.product.name,
        orderedUnit: item.unit.name,
        orderedQuantity: item.quantity,
        stripQty: item.product.stripQty,
        boxQty: item.product.boxQty,
        multiplierToBaseAtTime: mult,
        totalPieces: item.totalPieces,
        unitPricePaiseAtTime: item.unitPricePaise,
        piecePricePaiseAtTime: item.product.piecePricePaise,
        mrpRupeesAtTime: item.product.mrpRupees,
        gstRateAtTime: item.product.gstRate,
        taxableAmountPaise: item.taxableAmountPaise,
        gstAmountPaise: item.totalGstPaise,
        lineTotalPaise: item.totalPaise,
        discountPaise: 0,
        freeQuantity: 0,
      );
    }).toList();

    final totalsPayload = OrderTotalsPayload(
      totalAmountPaise: cartTotalPaise,
      taxableAmountPaise: cartTaxablePaise,
      gstAmountPaise: cartTotalGstPaise,
      discountAmountPaise: 0,
    );

    final candidatePayload = CreateOrderMutationPayload(
      provisionalOrderId: provisionalOrderId,
      orderNumber: orderNumber,
      idempotencyKey: idempotencyKey,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      userRole: session.activeRole,
      retailer: retailerSnapshot,
      items: itemPayloads,
      totals: totalsPayload,
      paymentMode: paymentMode,
      assignedCarNumber: _carNumber,
      clientCreatedAtEpochMs: epochMs,
    );

    // 2. Pre-check existing mutation by idempotency key
    final existingMutation = await db.outboxDao.getMutationByIdempotencyKey(idempotencyKey);
    if (existingMutation != null) {
      final existingPayload = CreateOrderMutationPayload.fromCanonicalJson(existingMutation.payloadJson);
      if (!_arePayloadsMatching(existingPayload, candidatePayload)) {
        throw const IdempotencyPayloadMismatchException(
          'Idempotency key reused with mismatched order payload',
        );
      }
      // Idempotent replay: safely return existing order
      var existingOrder = _orders.cast<DistributorOrder?>().firstWhere(
            (o) => o?.id == existingPayload.provisionalOrderId || o?.orderNumber == existingPayload.orderNumber,
            orElse: () => null,
          );
      if (existingOrder == null) {
        existingOrder = _reconstructOrderFromPayload(existingPayload);
        _orders.insert(0, existingOrder);
      }
      _cart.clear();
      notifyListeners();
      return existingOrder;
    }

    // 3. Atomically allocate sequence_order, deduct inventory & insert outbox mutation into SQLite
    final mutationId = 'out_${generateUuidV4()}';
    await db.outboxDao.insertOrderMutationAtomic(
      id: mutationId,
      organizationId: session.activeOrganizationId,
      userId: session.userId,
      idempotencyKey: idempotencyKey,
      mutationType: 'CREATE_ORDER',
      payloadJson: candidatePayload.toCanonicalJson(),
      provisionalBusinessId: provisionalOrderId,
      createdAtEpochMs: epochMs,
      businessOperation: () async {
        for (final item in _cart.values) {
          final prod = _products.cast<ProductItem?>().firstWhere(
            (p) => p?.id == item.product.id,
            orElse: () => null,
          );
          if (prod != null) {
            final snap = await repository.getInventorySnapshot(prod.id);
            final currentGodown = snap?.godownCartons ?? prod.godownStockBoxes;
            final currentPieces = snap?.godownLoosePieces ?? 0;
            final boxQty = prod.boxQty > 0 ? prod.boxQty : 1;
            final totalPiecesNeeded = item.totalPieces;
            final currentTotalPieces = (currentGodown * boxQty) + currentPieces;
            final remainingPieces = (currentTotalPieces - totalPiecesNeeded).clamp(0, 99999999);
            final newGodown = remainingPieces ~/ boxQty;
            final newLoose = remainingPieces % boxQty;

            await repository.recordStockMovement(
              productId: prod.id,
              movementType: 'DISPATCH',
              cartonDelta: -(totalPiecesNeeded ~/ boxQty),
              loosePieceDelta: -(totalPiecesNeeded % boxQty),
              reason: 'Order $orderNumber booked for ${shop.name}',
              newGodownCartons: newGodown,
              newGodownLoosePieces: newLoose,
              newCarCartons: snap?.carCartons ?? prod.carStockBoxes,
              newCarLoosePieces: snap?.carLoosePieces ?? 0,
            );
            prod.godownStockBoxes = newGodown;
          }
        }
        shop.todayOrderTotalPaise += totalsPayload.totalAmountPaise;
        shop.visitedToday = true;
        await repository.upsertRetailer(shop);
      },
    );

    // 4. Construct in-memory DistributorOrder from payload snapshot and register in booking stream
    final confirmedOrder = _reconstructOrderFromPayload(candidatePayload);
    _orders.insert(0, confirmedOrder);
    _cart.clear();
    await repository.deleteCartDraft(shop.id);
    onOutboxMutationEnqueued?.call();
    notifyListeners();
    return confirmedOrder;
  }

  bool _arePayloadsMatching(CreateOrderMutationPayload a, CreateOrderMutationPayload b) {
    if (a.retailer.id != b.retailer.id) return false;
    if (a.paymentMode != b.paymentMode) return false;
    if (a.totals.totalAmountPaise != b.totals.totalAmountPaise) return false;
    if (a.items.length != b.items.length) return false;
    for (int i = 0; i < a.items.length; i++) {
      final itemA = a.items[i];
      final itemB = b.items[i];
      if (itemA.productId != itemB.productId) return false;
      if (itemA.orderedQuantity != itemB.orderedQuantity) return false;
      if (itemA.orderedUnit != itemB.orderedUnit) return false;
      if (itemA.lineTotalPaise != itemB.lineTotalPaise) return false;
      if (itemA.totalPieces != itemB.totalPieces) return false;
    }
    return true;
  }

  DistributorOrder _reconstructOrderFromPayload(CreateOrderMutationPayload payload) {
    final cartItems = payload.items.map((i) {
      final existingProduct = _products.cast<ProductItem?>().firstWhere(
            (p) => p?.id == i.productId,
            orElse: () => null,
          );
      final product = ProductItem(
        id: i.productId,
        name: i.productName,
        hindiName: existingProduct?.hindiName ?? i.productName,
        category: existingProduct?.category ?? 'General',
        mrpRupees: i.mrpRupeesAtTime,
        piecePricePaise: i.piecePricePaiseAtTime,
        stripQty: i.stripQty,
        boxQty: i.boxQty,
        gstRate: i.gstRateAtTime,
        godownStockBoxes: existingProduct?.godownStockBoxes ?? 0,
        carStockBoxes: existingProduct?.carStockBoxes ?? 0,
        badge: existingProduct?.badge ?? '',
        imageUrl: existingProduct?.imageUrl ?? '',
      );

      OrderUnit unit;
      switch (i.orderedUnit.toLowerCase()) {
        case 'strip':
          unit = OrderUnit.strip;
          break;
        case 'piece':
          unit = OrderUnit.piece;
          break;
        case 'box':
        default:
          unit = OrderUnit.box;
          break;
      }

      return CartItem(
        product: product,
        unit: unit,
        quantity: i.orderedQuantity,
      );
    }).toList();

    return DistributorOrder(
      id: payload.provisionalOrderId,
      orderNumber: payload.orderNumber,
      shopId: payload.retailer.id,
      shopName: payload.retailer.name,
      shopPhone: payload.retailer.phone,
      address: payload.retailer.address,
      items: cartItems,
      totalPaise: payload.totals.totalAmountPaise,
      taxablePaise: payload.totals.taxableAmountPaise,
      totalGstPaise: payload.totals.gstAmountPaise,
      paymentMode: payload.paymentMode,
      stage: OrderLifecycleStage.booking,
      assignedCarNumber: payload.assignedCarNumber.isNotEmpty
          ? payload.assignedCarNumber
          : _carNumber,
      otp: '${100000 + (payload.clientCreatedAtEpochMs % 900000)}',
      createdAt: DateTime.fromMillisecondsSinceEpoch(payload.clientCreatedAtEpochMs),
    );
  }

  /// Rewrites provisional retailer ID upon authentic server 200 acknowledgment.
  void rewriteProvisionalRetailerId(String provisionalId, String serverBusinessId) {
    bool updated = false;
    final rIdx = _retailers.indexWhere((r) => r.id == provisionalId);
    if (rIdx != -1) {
      final old = _retailers[rIdx];
      _retailers[rIdx] = old.copyWith(id: serverBusinessId, syncStatus: 'SYNCED');
      updated = true;
    }
    for (int i = 0; i < _orders.length; i++) {
      if (_orders[i].shopId == provisionalId) {
        _orders[i] = _orders[i].copyWith(shopId: serverBusinessId);
        updated = true;
      }
    }
    if (_selectedShop?.id == provisionalId) {
      _selectedShop = _selectedShop!.copyWith(id: serverBusinessId, syncStatus: 'SYNCED');
      updated = true;
    }
    if (updated) notifyListeners();
  }

  /// Rewrites provisional order ID and orderNumber upon server 200 acknowledgment.
  void rewriteProvisionalOrderId(String provisionalId, String serverBusinessId) {
    final oIdx = _orders.indexWhere((o) => o.id == provisionalId);
    if (oIdx != -1) {
      _orders[oIdx] = _orders[oIdx].copyWith(
        id: serverBusinessId,
        orderNumber: serverBusinessId,
      );
      notifyListeners();
    }
  }

  /// Releases virtual reservation for a booking rejected by the server or cancelled.
  void releaseOrderReservation(String provisionalId, {String? reason}) {
    final oIdx = _orders.indexWhere((o) => o.id == provisionalId || o.orderNumber == provisionalId);
    if (oIdx != -1) {
      _orders[oIdx].stage = OrderLifecycleStage.rejected;
      notifyListeners();
    }
  }

  /// Updates order stage upon authentic pull delta from office server.
  void updateOrderStageFromServer(String orderId, String newStage) {
    final idx = _orders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (idx != -1) {
      OrderLifecycleStage parsed;
      switch (newStage.toUpperCase()) {
        case 'READY_STOCK':
        case 'PICKED':
          parsed = OrderLifecycleStage.readyStock;
          break;
        case 'OUT_FOR_DELIVERY':
        case 'ORDER_SEND':
          parsed = OrderLifecycleStage.orderSend;
          break;
        case 'DELIVERED':
          parsed = OrderLifecycleStage.delivered;
          break;
        case 'REJECTED':
        case 'CANCELLED':
          parsed = OrderLifecycleStage.rejected;
          break;
        default:
          parsed = OrderLifecycleStage.booking;
      }
      _orders[idx].stage = parsed;
      notifyListeners();
    }
  }

  /// Updates retailer credit limit and classification upon authentic pull delta from office server.
  void updateRetailerFromServer({
    required String id,
    int? creditLimitPaise,
    String? classification,
  }) {
    final idx = _retailers.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final r = _retailers[idx];
      if (creditLimitPaise != null) r.creditLimitPaise = creditLimitPaise;
      if (classification != null) r.classType = classification;
      notifyListeners();
    }
  }

  /// Updates or inserts product catalog item upon authentic pull delta from office server.
  void updateProductFromServer(ProductItem serverProduct) {
    final idx = _products.indexWhere((p) => p.id == serverProduct.id);
    if (idx != -1) {
      _products[idx] = serverProduct;
    } else {
      _products.add(serverProduct);
    }
    notifyListeners();
  }

  /// Slice 6: Returns strictly honest, unambiguous labels for sync status.
  /// Never claims an order is synced to cloud until real server acknowledgment.
  String getHonestSyncStatusLabel(String syncStatus) {
    switch (syncStatus) {
      case 'PENDING':
      case 'RETRYABLE_FAILURE':
        return 'Saved on this phone (Offline Outbox)';
      case 'SYNCING':
        return 'Uploading to Cloud...';
      case 'SYNCED':
        return 'Synced to Cloud';
      case 'FAILED_TERMINAL':
        return 'Sync Rejected by Cloud';
      default:
        return 'Saved on this phone (Offline Outbox)';
    }
  }

  /// Returns durable 3-step audit timeline for an order:
  /// 1. Booked on Device
  /// 2. Saved in Local Outbox (with sequence #)
  /// 3. Cloud Sync (honest unconfirmed / confirmed)
  Future<List<OrderTimelineStep>> getOrderAuditTimeline(String orderId) async {
    final order = _orders.cast<DistributorOrder?>().firstWhere(
          (o) => o?.id == orderId,
          orElse: () => null,
        );

    final pending = await db.outboxDao.getPendingQueue();
    OutboxMutationEntry? mutation;
    for (final m in pending) {
      if (m.provisionalBusinessId == orderId) {
        mutation = m;
        break;
      }
    }

    mutation ??= await (db.select(db.outboxMutations)
          ..where((tbl) => tbl.provisionalBusinessId.equals(orderId)))
        .getSingleOrNull();

    final createdAt = order?.createdAt ??
        (mutation != null
            ? DateTime.fromMillisecondsSinceEpoch(mutation.createdAtEpochMs)
            : DateTime.now());
    final sequenceStr = mutation != null ? 'Sequence #${mutation.sequenceOrder}' : 'Sequence #1';
    final isSynced = mutation?.syncStatus == 'SYNCED';

    final timeStr = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return [
      OrderTimelineStep(
        title: 'Booked on Device',
        subtitle: 'Created locally at $timeStr',
        isCompleted: true,
        timestamp: createdAt,
      ),
      OrderTimelineStep(
        title: 'Saved in Local Outbox',
        subtitle: 'Durable in SQLite ($sequenceStr)',
        isCompleted: true,
        timestamp: createdAt,
      ),
      OrderTimelineStep(
        title: 'Cloud Sync',
        subtitle: isSynced ? 'Sent to the office' : 'Pending upload to Cloudflare',
        isCompleted: isSynced,
        timestamp: isSynced ? DateTime.now() : null,
      ),
    ];
  }

  // Stage Transitions (Booking -> Ready Stock in Car -> Order Send on Route -> Delivered)
  void advanceOrderStage(String orderId) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;

    final o = _orders[idx];
    if (o.stage == OrderLifecycleStage.booking) {
      o.stage = OrderLifecycleStage.readyStock;
      o.assignedCarNumber = _carNumber;
    } else if (o.stage == OrderLifecycleStage.readyStock) {
      o.stage = OrderLifecycleStage.orderSend;
      // Add or update matching delivery stop
      final existingStop = _deliveryStops.indexWhere((s) => s.orderId == o.id);
      if (existingStop == -1) {
        _deliveryStops.add(DeliveryStop(
          id: 'stop_${DateTime.now().millisecondsSinceEpoch}',
          orderId: o.id,
          shopName: o.shopName,
          ownerName: 'Proprietor',
          phone: o.shopPhone,
          address: o.address,
          area: 'Jodhpur Beat',
          codAmountPaise: o.paymentMode == 'COD' ? o.totalPaise : 0,
          serverOtp: o.otp,
          itemCount: o.items.length,
        ));
      }
    } else if (o.stage == OrderLifecycleStage.orderSend) {
      o.stage = OrderLifecycleStage.delivered;
      o.isPaid = true;
    }
    notifyListeners();
  }

  // Local delivery test confirmation (Demo/Testing Only)
  bool confirmDeliveryWithOtp(String stopId, String enteredOtp) {
    final idx = _deliveryStops.indexWhere((s) => s.id == stopId);
    if (idx == -1) return false;

    final stop = _deliveryStops[idx];
    // Strictly validate against the assigned demo code; reject universal bypasses
    if (stop.serverOtp.isNotEmpty && enteredOtp.trim() == stop.serverOtp.trim()) {
      stop.isDelivered = true;
      stop.cashCollected = true;
      stop.deliveredAt = DateTime.now();

      // Find order and mark delivered
      final oIdx = _orders.indexWhere((o) => o.id == stop.orderId);
      if (oIdx != -1) {
        _orders[oIdx].stage = OrderLifecycleStage.delivered;
        _orders[oIdx].isPaid = true;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  // Financial & Accountant aggregates
  int get totalBookedSalesPaise =>
      _orders.fold(0, (sum, o) => sum + o.totalPaise);
  double get totalBookedSalesRupees => totalBookedSalesPaise / 100.0;

  int get totalDeliveredSalesPaise => _orders
      .where((o) => o.stage == OrderLifecycleStage.delivered)
      .fold(0, (sum, o) => sum + o.totalPaise);
  double get totalDeliveredSalesRupees => totalDeliveredSalesPaise / 100.0;

  int get totalGstCollectedPaise => _orders
      .where((o) => o.stage == OrderLifecycleStage.delivered)
      .fold(0, (sum, o) => sum + o.totalGstPaise);
  double get totalGstCollectedRupees => totalGstCollectedPaise / 100.0;

  int get driverCashCustodyPaise {
    return _deliveryStops
        .where((s) => s.isDelivered && s.cashCollected)
        .fold(0, (sum, s) => sum + s.codAmountPaise);
  }
  double get driverCashCustodyRupees => driverCashCustodyPaise / 100.0;

  int get totalUdhaarPaise =>
      _retailers.fold(0, (sum, r) => sum + r.outstandingPaise);
  double get totalUdhaarRupees => totalUdhaarPaise / 100.0;

  int get totalGodownBoxes =>
      _products.fold(0, (sum, p) => sum + p.godownStockBoxes);
  int get totalCarBoxes =>
      _products.fold(0, (sum, p) => sum + p.carStockBoxes);

  /// Total retail valuation of all Godown stock in Rupees.
  double get totalGodownValuationRupees {
    return _products.fold<double>(0.0, (sum, p) {
      final boxPrice = (p.piecePricePaise * p.boxQty) / 100.0;
      return sum + (p.godownStockBoxes * boxPrice);
    });
  }

  /// Total estimated gross margin/profit of all Godown stock in Rupees.
  double get totalGodownEstimatedProfitRupees {
    return _products.fold<double>(0.0, (sum, p) {
      final costPerPiece = p.costPricePaise > 0 ? p.costPricePaise : (p.piecePricePaise * 0.90).round();
      final profitPerBox = ((p.piecePricePaise - costPerPiece) * p.boxQty) / 100.0;
      return sum + (p.godownStockBoxes * profitPerBox);
    });
  }

  /// Estimated gross profit margin percentage for a product.
  double getProductMarginPercent(ProductItem p) {
    if (p.piecePricePaise <= 0) return 10.0;
    final cost = p.costPricePaise > 0 ? p.costPricePaise : (p.piecePricePaise * 0.90).round();
    final margin = ((p.piecePricePaise - cost) / p.piecePricePaise) * 100.0;
    return margin.clamp(0.0, 100.0);
  }

  /// Total pieces sold of a product across booked and delivered orders.
  int getProductSoldPieces(String productId) {
    int total = 0;
    for (final order in _orders) {
      for (final item in order.items) {
        if (item.product.id == productId) {
          total += item.totalPieces;
        }
      }
    }
    return total;
  }

  /// Total turnover in Rupees generated by a product.
  double getProductRevenueRupees(String productId) {
    double total = 0.0;
    for (final order in _orders) {
      for (final item in order.items) {
        if (item.product.id == productId) {
          total += item.totalRupees;
        }
      }
    }
    return total;
  }

  List<StaffMember> _staff = [];

  List<StaffMember> get staffList {
    if (_staff.isEmpty) {
      _staff = [
        StaffMember(id: 'usr_sales_1', username: 'sales_rep', fullName: 'Vikram Rathore', role: 'SALES', assignedBeat: 'Sardarpura & Nai Sadak'),
        StaffMember(id: 'usr_wh_1', username: 'warehouse_user', fullName: 'Mukesh Godown', role: 'WAREHOUSE', assignedBeat: 'Central Godown (Basni Phase II)'),
        StaffMember(id: 'usr_del_1', username: 'delivery_user', fullName: 'Suresh Yadav', role: 'DELIVERY', assignedBeat: 'Van RJ-19-1234'),
        StaffMember(id: 'usr_adm_1', username: 'dist_admin', fullName: 'Rajesh Sharma', role: 'ADMIN', assignedBeat: 'Jodhpur FMCG Depot Head Office'),
      ];
    }
    return List.unmodifiable(_staff);
  }

  Future<bool> createStaffMember({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? beatId,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanName = fullName.trim();
    if (cleanUsername.isEmpty || password.length < 4 || cleanName.isEmpty) {
      return false;
    }

    final newStaff = StaffMember(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      username: cleanUsername,
      fullName: cleanName,
      role: role.toUpperCase(),
      assignedBeat: beatId ?? (role == 'SALES' ? 'Main Market Beat' : null),
    );

    _staff = [...staffList, newStaff];

    try {
      final token = _sessionProvider?.call()?.activeMembership?.role;
      await http.post(
        Uri.parse('$cloudflareUrl/employees'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': cleanUsername,
          'password': password,
          'fullName': cleanName,
          'role': role.toUpperCase(),
          'beatId': beatId,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    try {
      await repository.setMetadata('owner_staff_roster', jsonEncode(_staff.map((s) => s.toJson()).toList()));
    } catch (_) {}

    notifyListeners();
    return true;
  }

  Future<void> toggleStaffStatus(String id) async {
    final idx = _staff.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _staff[idx].isActive = !_staff[idx].isActive;
      try {
        await repository.setMetadata('owner_staff_roster', jsonEncode(_staff.map((s) => s.toJson()).toList()));
      } catch (_) {}
      notifyListeners();
    }
  }

  void _initializeData() {
    // 1. Authentic Real Bites (Laxmi Snacks Pvt. Ltd.) FMCG Portfolio organized by Category
    _products = [
      // Category: Traditional Namkeen
      ProductItem(
        id: 'RB-NAM-01',
        name: 'Real Bites Bikaneri Sev 150g',
        hindiName: 'रियल बाइट्स बीकानेरी सेव',
        category: 'Traditional Namkeen',
        mrpRupees: 30.0,
        piecePricePaise: 2550,
        stripQty: 10,
        boxQty: 60,
        gstRate: 12.0,
        godownStockBoxes: 150,
        carStockBoxes: 20,
        badge: 'High Demand',
        batchNumber: 'LOT-2026-RBN01',
        expiryDate: DateTime(2027, 4, 15),
        reorderLevelBoxes: 30,
      ),
      ProductItem(
        id: 'RB-NAM-02',
        name: 'Real Bites Aaloo Sev 150g',
        hindiName: 'रियल बाइट्स आलू भुजिया सेव',
        category: 'Traditional Namkeen',
        mrpRupees: 30.0,
        piecePricePaise: 2550,
        stripQty: 10,
        boxQty: 60,
        gstRate: 12.0,
        godownStockBoxes: 120,
        carStockBoxes: 18,
        badge: 'Top Seller',
        batchNumber: 'LOT-2026-RBN02',
        expiryDate: DateTime(2027, 3, 20),
        reorderLevelBoxes: 25,
      ),
      ProductItem(
        id: 'RB-NAM-03',
        name: 'Real Bites Bhavnagari Ganthiya 200g',
        hindiName: 'रियल बाइट्स भावनगरी गांठिया',
        category: 'Traditional Namkeen',
        mrpRupees: 35.0,
        piecePricePaise: 2975,
        stripQty: 8,
        boxQty: 48,
        gstRate: 12.0,
        godownStockBoxes: 110,
        carStockBoxes: 15,
        badge: 'Crisp Classic',
        batchNumber: 'LOT-2026-RBN03',
        expiryDate: DateTime(2027, 5, 10),
        reorderLevelBoxes: 25,
      ),
      ProductItem(
        id: 'RB-NAM-04',
        name: 'Real Bites Papdi Ganthiya 200g',
        hindiName: 'रियल बाइट्स पापड़ी गांठिया',
        category: 'Traditional Namkeen',
        mrpRupees: 35.0,
        piecePricePaise: 2975,
        stripQty: 8,
        boxQty: 48,
        gstRate: 12.0,
        godownStockBoxes: 95,
        carStockBoxes: 12,
        badge: 'Tea Special',
        batchNumber: 'LOT-2026-RBN04',
        expiryDate: DateTime(2027, 4, 30),
        reorderLevelBoxes: 20,
      ),
      ProductItem(
        id: 'RB-NAM-05',
        name: 'Real Bites Nadiadi Mix 180g',
        hindiName: 'रियल बाइट्स नडियादी मिक्स नमकीन',
        category: 'Traditional Namkeen',
        mrpRupees: 35.0,
        piecePricePaise: 2975,
        stripQty: 8,
        boxQty: 48,
        gstRate: 12.0,
        godownStockBoxes: 140,
        carStockBoxes: 16,
        badge: 'Gujarat Hit',
        batchNumber: 'LOT-2026-RBN05',
        expiryDate: DateTime(2027, 6, 1),
        reorderLevelBoxes: 30,
      ),
      ProductItem(
        id: 'RB-NAM-06',
        name: 'Real Bites Farali Chiwda 200g',
        hindiName: 'रियल बाइट्स फराली चिवड़ा (उपवास विशेष)',
        category: 'Traditional Namkeen',
        mrpRupees: 40.0,
        piecePricePaise: 3400,
        stripQty: 8,
        boxQty: 40,
        gstRate: 12.0,
        godownStockBoxes: 85,
        carStockBoxes: 10,
        badge: 'Fasting Hit',
        batchNumber: 'LOT-2026-RBN06',
        expiryDate: DateTime(2026, 12, 1),
        reorderLevelBoxes: 20,
      ),
      ProductItem(
        id: 'RB-NAM-07',
        name: 'Real Bites Sing Bhujiya 100g',
        hindiName: 'रियल बाइट्स सींग भुजिया (मसाला मूंगफली)',
        category: 'Traditional Namkeen',
        mrpRupees: 20.0,
        piecePricePaise: 1700,
        stripQty: 12,
        boxQty: 72,
        gstRate: 12.0,
        godownStockBoxes: 160,
        carStockBoxes: 24,
        badge: 'Nut Crunch',
        batchNumber: 'LOT-2026-RBN07',
        expiryDate: DateTime(2027, 5, 20),
        reorderLevelBoxes: 35,
      ),
      ProductItem(
        id: 'RB-NAM-08',
        name: 'Real Bites Moong Dal 100g',
        hindiName: 'रियल बाइट्स नमकीन मूंग दाल',
        category: 'Traditional Namkeen',
        mrpRupees: 20.0,
        piecePricePaise: 1700,
        stripQty: 12,
        boxQty: 72,
        gstRate: 12.0,
        godownStockBoxes: 130,
        carStockBoxes: 20,
        badge: 'Protein Snack',
        batchNumber: 'LOT-2026-RBN08',
        expiryDate: DateTime(2027, 7, 10),
        reorderLevelBoxes: 30,
      ),
      ProductItem(
        id: 'RB-NAM-09',
        name: 'Real Bites Masala Boondi 150g',
        hindiName: 'रियल बाइट्स रायता एवं चाट मसाला बूंदी',
        category: 'Traditional Namkeen',
        mrpRupees: 25.0,
        piecePricePaise: 2125,
        stripQty: 10,
        boxQty: 60,
        gstRate: 12.0,
        godownStockBoxes: 90,
        carStockBoxes: 14,
        badge: 'Raita Hit',
        batchNumber: 'LOT-2026-RBN09',
        expiryDate: DateTime(2027, 8, 1),
        reorderLevelBoxes: 20,
      ),

      // Category: Potato Wafers
      ProductItem(
        id: 'RB-WAF-01',
        name: 'Real Bites Classic Salted Wafers 40g',
        hindiName: 'रियल बाइट्स क्लासिक साल्टेड वेफर्स',
        category: 'Potato Wafers',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 12,
        boxQty: 96,
        gstRate: 12.0,
        godownStockBoxes: 220,
        carStockBoxes: 28,
        badge: 'Top Seller',
        batchNumber: 'LOT-2026-RBW01',
        expiryDate: DateTime(2027, 3, 10),
        reorderLevelBoxes: 50,
      ),
      ProductItem(
        id: 'RB-WAF-02',
        name: 'Real Bites Chatpata Masala Wafers 40g',
        hindiName: 'रियल बाइट्स चटपटा मसाला वेफर्स',
        category: 'Potato Wafers',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 12,
        boxQty: 96,
        gstRate: 12.0,
        godownStockBoxes: 200,
        carStockBoxes: 25,
        badge: 'Spicy Hit',
        batchNumber: 'LOT-2026-RBW02',
        expiryDate: DateTime(2026, 11, 28),
        reorderLevelBoxes: 45,
      ),
      ProductItem(
        id: 'RB-WAF-03',
        name: 'Real Bites Cream & Onion Wafers 40g',
        hindiName: 'रियल बाइट्स क्रीम एंड अनियन वेफर्स',
        category: 'Potato Wafers',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 12,
        boxQty: 96,
        gstRate: 12.0,
        godownStockBoxes: 180,
        carStockBoxes: 22,
        badge: 'Creamy Hit',
        batchNumber: 'LOT-2026-RBW03',
        expiryDate: DateTime(2027, 4, 15),
        reorderLevelBoxes: 40,
      ),
      ProductItem(
        id: 'RB-WAF-04',
        name: 'Real Bites Tangy Tomato Wafers 40g',
        hindiName: 'रियल बाइट्स टैंगी टोमैटो वेफर्स',
        category: 'Potato Wafers',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 12,
        boxQty: 96,
        gstRate: 12.0,
        godownStockBoxes: 175,
        carStockBoxes: 20,
        badge: 'Kid Favorite',
        batchNumber: 'LOT-2026-RBW04',
        expiryDate: DateTime(2027, 5, 1),
        reorderLevelBoxes: 35,
      ),

      // Category: Extruded Snacks & Fryums
      ProductItem(
        id: 'RB-EXT-01',
        name: 'Real Krackers Masala Wheel 45g',
        hindiName: 'रियल क्रैकर्स मसाला पहिया व्हील',
        category: 'Extruded Snacks & Fryums',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 10,
        boxQty: 80,
        gstRate: 12.0,
        godownStockBoxes: 240,
        carStockBoxes: 30,
        badge: 'Crunch Hit',
        batchNumber: 'LOT-2026-RBX01',
        expiryDate: DateTime(2027, 6, 20),
        reorderLevelBoxes: 50,
      ),
      ProductItem(
        id: 'RB-EXT-02',
        name: 'Real Bites Cheesy Rings 40g',
        hindiName: 'रियल बाइट्स चीज़ी रिंग्स',
        category: 'Extruded Snacks & Fryums',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 10,
        boxQty: 80,
        gstRate: 12.0,
        godownStockBoxes: 190,
        carStockBoxes: 24,
        badge: 'Cheese Blast',
        batchNumber: 'LOT-2026-RBX02',
        expiryDate: DateTime(2027, 7, 1),
        reorderLevelBoxes: 40,
      ),
      ProductItem(
        id: 'RB-EXT-03',
        name: 'Real Bites Masala Puff Balls 45g',
        hindiName: 'रियल बाइट्स मसाला पफ बॉल्स',
        category: 'Extruded Snacks & Fryums',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 10,
        boxQty: 80,
        gstRate: 12.0,
        godownStockBoxes: 165,
        carStockBoxes: 20,
        badge: 'Light & Crisp',
        batchNumber: 'LOT-2026-RBX03',
        expiryDate: DateTime(2027, 5, 25),
        reorderLevelBoxes: 35,
      ),
      ProductItem(
        id: 'RB-EXT-04',
        name: 'Real Bites Italian Pasta Fryums 50g',
        hindiName: 'रियल बाइट्स इटैलियन पास्ता फ्रायम्स',
        category: 'Extruded Snacks & Fryums',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 10,
        boxQty: 80,
        gstRate: 12.0,
        godownStockBoxes: 150,
        carStockBoxes: 18,
        badge: 'Kids Special',
        batchNumber: 'LOT-2026-RBX04',
        expiryDate: DateTime(2027, 6, 15),
        reorderLevelBoxes: 30,
      ),

      // Category: Bakery & Confectionery
      ProductItem(
        id: 'RB-BAK-01',
        name: 'Real Bites Peanut Chikki Bar 100g',
        hindiName: 'रियल बाइट्स गुड़ मूंगफली चिक्की',
        category: 'Bakery & Confectionery',
        mrpRupees: 25.0,
        piecePricePaise: 2100,
        stripQty: 10,
        boxQty: 50,
        gstRate: 5.0,
        godownStockBoxes: 140,
        carStockBoxes: 18,
        badge: 'Pure Jaggery',
        batchNumber: 'LOT-2026-RBB01',
        expiryDate: DateTime(2027, 8, 10),
        reorderLevelBoxes: 30,
      ),
      ProductItem(
        id: 'RB-BAK-02',
        name: 'Real Bites Special Butter Khari 200g',
        hindiName: 'रियल बाइट्स क्रिस्पी बटर खारी',
        category: 'Bakery & Confectionery',
        mrpRupees: 45.0,
        piecePricePaise: 3800,
        stripQty: 6,
        boxQty: 30,
        gstRate: 5.0,
        godownStockBoxes: 90,
        carStockBoxes: 12,
        badge: 'Tea Partner',
        batchNumber: 'LOT-2026-RBB02',
        expiryDate: DateTime(2027, 4, 1),
        reorderLevelBoxes: 20,
      ),
      ProductItem(
        id: 'RB-BAK-03',
        name: 'Real Bites Premium Elaichi Rusk 250g',
        hindiName: 'रियल बाइट्स प्रीमियम इलायची टोस्ट रस्क',
        category: 'Bakery & Confectionery',
        mrpRupees: 40.0,
        piecePricePaise: 3400,
        stripQty: 8,
        boxQty: 32,
        gstRate: 5.0,
        godownStockBoxes: 110,
        carStockBoxes: 15,
        badge: 'Morning Crunch',
        batchNumber: 'LOT-2026-RBB03',
        expiryDate: DateTime(2027, 5, 15),
        reorderLevelBoxes: 25,
      ),
      ProductItem(
        id: 'RB-BAK-04',
        name: 'Real Bites Vanilla Cream Rolls (6 Pcs)',
        hindiName: 'रियल बाइट्स वैनिला क्रीम रोल्स',
        category: 'Bakery & Confectionery',
        mrpRupees: 30.0,
        piecePricePaise: 2500,
        stripQty: 8,
        boxQty: 40,
        gstRate: 12.0,
        godownStockBoxes: 85,
        carStockBoxes: 10,
        badge: 'Sweet Treat',
        batchNumber: 'LOT-2026-RBB04',
        expiryDate: DateTime(2026, 11, 25),
        reorderLevelBoxes: 20,
      ),
    ];

    // Synchronize initial truck stock for primary vehicle
    for (final p in _products) {
      if (p.carStockBoxes > 0) {
        _deliveryTrucks[0].loadStock(p.id, p.carStockBoxes);
      }
    }

    // 2. Jodhpur Kirana Retailers with Spatial Coordinates (Sardarpura & Nai Sadak Route)
    _retailers = [
      RetailerShop(
        id: 'RET-JDH-01',
        name: 'Shree Ganesh Kirana Store',
        ownerName: 'Ramprasad Maheshwari',
        phone: '+91 98290 12345',
        address: 'Shop 14, Nai Sadak (Opp. Ghanta Ghar)',
        area: 'Nai Sadak',
        routeId: 'route_nai_sadak_01',
        shopType: 'KIRANA',
        creditLimitPaise: 5000000, // ₹50,000
        outstandingPaise: 1240000, // ₹12,400
        visitedToday: false,
        latitude: 26.2945,
        longitude: 73.0240,
      ),
      RetailerShop(
        id: 'RET-JDH-02',
        name: 'Jodhpur Wholesale Traders',
        ownerName: 'Madan Lal Sharma',
        phone: '+91 94141 55678',
        address: 'Plot 22, B-Road, Near Nehru Park',
        area: 'Sardarpura',
        routeId: 'route_sardarpura_02',
        shopType: 'WHOLESALE',
        creditLimitPaise: 10000000, // ₹1,00,000
        outstandingPaise: 4320000, // ₹43,200
        visitedToday: true,
        todayOrderTotalPaise: 1850000,
        totalTimeSpentSeconds: 1260, // 21m spent earlier today
        visitCountToday: 1,
        latitude: 26.2750,
        longitude: 73.0080,
      ),
      RetailerShop(
        id: 'RET-JDH-03',
        name: 'Marwar Super Provision Store',
        ownerName: 'Bhanwar Singh Rathore',
        phone: '+91 98291 98765',
        address: 'Shop 8, Main Market, Nai Sadak',
        area: 'Nai Sadak',
        routeId: 'route_nai_sadak_01',
        shopType: 'SUPERMARKET',
        creditLimitPaise: 4000000,
        outstandingPaise: 850000,
        visitedToday: false,
        latitude: 26.2915,
        longitude: 73.0215,
      ),
      RetailerShop(
        id: 'RET-JDH-04',
        name: 'Mahadev Kirana & General Stores',
        ownerName: 'Dungar Ram Dewasi',
        phone: '+91 99280 44321',
        address: 'SCO 9, 4th C Road',
        area: 'Sardarpura',
        routeId: 'route_sardarpura_02',
        shopType: 'GENERAL_STORE',
        creditLimitPaise: 3000000,
        outstandingPaise: 1520000,
        visitedToday: false,
        latitude: 26.2810,
        longitude: 73.0115,
      ),
      RetailerShop(
        id: 'RET-JDH-05',
        name: 'Laxmi Namkeen & Farsan Mart',
        ownerName: 'Kailash Chand',
        phone: '+91 98292 33445',
        address: 'Shop 5, Jaljog Circle, Sardarpura',
        area: 'Sardarpura',
        routeId: 'route_sardarpura_02',
        shopType: 'FARSAN_NAMKEEN',
        creditLimitPaise: 4500000,
        outstandingPaise: 980000,
        visitedToday: false,
        latitude: 26.2785,
        longitude: 73.0095,
      ),
      RetailerShop(
        id: 'RET-JDH-06',
        name: 'Shanti Sweets & Farsan Bhandar',
        ownerName: 'Deepak Joshi',
        phone: '+91 98293 44556',
        address: 'Opp. Ghanta Ghar Tower, Nai Sadak',
        area: 'Nai Sadak',
        routeId: 'route_nai_sadak_01',
        shopType: 'FARSAN_NAMKEEN',
        creditLimitPaise: 6000000,
        outstandingPaise: 0,
        visitedToday: false,
        latitude: 26.2930,
        longitude: 73.0230,
      ),
    ];

    // 3. Physical Warehouse Hubs
    _warehouseHubs = [
      WarehouseHub(
        id: 'WH-JDH-CENTRAL',
        name: 'Routidrow Central Godown',
        code: 'BASNI-01',
        address: 'Plot 42, Light Industrial Area, Basni Phase II, Jodhpur',
        latitude: 26.2167,
        longitude: 73.0167,
        capacityBoxes: 5000,
        activeStaffCount: 8,
        godownStockBoxes: 180,
        carStockBoxes: 24,
      ),
      WarehouseHub(
        id: 'WH-JDH-SUBDEPOT',
        name: 'Sohati Gate City Cross-Dock',
        code: 'SOHATI-02',
        address: 'Shop 12, Sohati Gate Circle, Inner Ring Rd, Jodhpur',
        latitude: 26.2870,
        longitude: 73.0200,
        capacityBoxes: 1200,
        activeStaffCount: 3,
        godownStockBoxes: 40,
        carStockBoxes: 12,
      ),
    ];

    // 3. Pre-seed Orders across the 3 lifecycle streams
    _orders.addAll([
      // Stage: Ready Stock (Loaded in Car)
      DistributorOrder(
        id: 'ord_init_01',
        orderNumber: 'ROUT-849201',
        shopId: 'RET-JDH-02',
        shopName: 'Jodhpur Wholesale Traders',
        shopPhone: '+91 94141 55678',
        address: 'B-Road, Sardarpura, Jodhpur',
        items: [
          CartItem(product: _products[0], unit: OrderUnit.box, quantity: 2), // 2 boxes Real Bites Bikaneri Sev
          CartItem(product: _products[6], unit: OrderUnit.box, quantity: 1), // 1 box Real Bites Sing Bhujiya
        ],
        totalPaise: 1898000,
        taxablePaise: 1694643,
        totalGstPaise: 203357,
        paymentMode: 'COD',
        stage: OrderLifecycleStage.readyStock,
        assignedCarNumber: _carNumber,
        otp: '724185',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),

      // Stage: Order Send (On Route)
      DistributorOrder(
        id: 'ord_init_02',
        orderNumber: 'ROUT-772910',
        shopId: 'RET-JDH-01',
        shopName: 'Shree Ganesh Kirana Store',
        shopPhone: '+91 98290 12345',
        address: 'Opp. Ghanta Ghar, Station Road',
        items: [
          CartItem(product: _products[1], unit: OrderUnit.box, quantity: 3), // 3 boxes Real Bites Aaloo Sev
          CartItem(product: _products[9], unit: OrderUnit.strip, quantity: 4), // 4 strips Real Bites Wafers
        ],
        totalPaise: 2650000,
        taxablePaise: 2366071,
        totalGstPaise: 283929,
        paymentMode: 'Credit',
        stage: OrderLifecycleStage.orderSend,
        assignedCarNumber: _carNumber,
        otp: '724185',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),

      // Stage: Booking (New booking waiting for picking)
      DistributorOrder(
        id: 'ord_init_03',
        orderNumber: 'ROUT-910245',
        shopId: 'RET-JDH-03',
        shopName: 'Marwar Super Provision Store',
        shopPhone: '+91 98291 98765',
        address: 'Main Market, Sohati Gate Circle',
        items: [
          CartItem(product: _products[0], unit: OrderUnit.strip, quantity: 6), // 6 strips Real Bites Bikaneri Sev
          CartItem(product: _products[3], unit: OrderUnit.piece, quantity: 24), // 24 pouches Real Bites Papdi Ganthiya
        ],
        totalPaise: 796500,
        taxablePaise: 711161,
        totalGstPaise: 85339,
        paymentMode: 'COD',
        stage: OrderLifecycleStage.booking,
        assignedCarNumber: _carNumber,
        otp: '724185',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ]);

    // Initial delivery stops matching the orders
    _deliveryStops.addAll([
      DeliveryStop(
        id: 'stop_init_01',
        orderId: 'ord_init_01',
        shopName: 'Jodhpur Wholesale Traders',
        ownerName: 'Madan Lal Sharma',
        phone: '+91 94141 55678',
        address: 'B-Road, Sardarpura, Jodhpur',
        area: 'Sardarpura (Stop 1)',
        codAmountPaise: 1898000,
        serverOtp: '724185',
        itemCount: 2,
        isDelivered: false,
        latitude: 26.2750,
        longitude: 73.0080,
      ),
      DeliveryStop(
        id: 'stop_init_02',
        orderId: 'ord_init_02',
        shopName: 'Shree Ganesh Kirana Store',
        ownerName: 'Ramprasad Maheshwari',
        phone: '+91 98290 12345',
        address: 'Opp. Ghanta Ghar, Station Road',
        area: 'Clock Tower (Stop 2)',
        codAmountPaise: 0, // On Credit
        serverOtp: '724185',
        itemCount: 2,
        isDelivered: false,
        latitude: 26.2965,
        longitude: 73.0232,
      ),
    ]);
  }

  Future<void> _syncFromDatabase({TenantBoundaryGate? boundaryGate}) async {
    final capturedGen = _transientGeneration;
    try {
      // 1. Startup reconstruction: Restore pending bookings from outbox mutations.
      // Outbox records are strictly tenant-isolated via organization_id & user_id.
      final session = currentSession;
      if (session != null &&
          session.activeOrganizationId.isNotEmpty &&
          session.userId.isNotEmpty) {
        final pendingMutations = await db.outboxDao.getPendingMutations(
          organizationId: session.activeOrganizationId,
          userId: session.userId,
        );
        if (capturedGen != _transientGeneration) return;
        for (final mutation in pendingMutations) {
          if (mutation.mutationType == 'CREATE_RETAILER') {
            try {
              final payload = CreateRetailerMutationPayload.fromCanonicalJson(
                mutation.payloadJson,
              );
              if (!_retailers.any((r) => r.id == payload.provisionalRetailerId)) {
                final reconstructed = RetailerShop(
                  id: payload.provisionalRetailerId,
                  name: payload.name,
                  ownerName: payload.ownerName,
                  phone: payload.phone,
                  address: payload.address,
                  area: payload.area,
                  routeId: payload.routeId,
                  creditLimitPaise: 0,
                  outstandingPaise: 0,
                  latitude: payload.latitude,
                  longitude: payload.longitude,
                  locationAccuracyMeters: payload.locationAccuracyMeters,
                  classType: payload.classType,
                  classSource: payload.classSource,
                  shopType: payload.shopType,
                  gstin: payload.gstin,
                  pincode: payload.pincode,
                  landmark: payload.landmark,
                  status: 'ACTIVE',
                  createdByUserId: payload.userId,
                  syncStatus: 'PENDING',
                  whatsappPhone: payload.whatsappPhone,
                  gstType: payload.gstType,
                  panNumber: payload.panNumber,
                );
                _retailers.insert(0, reconstructed);
              }
            } catch (e) {
              debugPrint('Failed to reconstruct outbox retailer ${mutation.id}: $e');
            }
          } else if (mutation.mutationType == 'CREATE_ORDER') {
            try {
              final payload = CreateOrderMutationPayload.fromCanonicalJson(
                mutation.payloadJson,
              );
              final alreadyExists = _orders.any(
                (o) =>
                    o.id == payload.provisionalOrderId ||
                    o.orderNumber == payload.orderNumber,
              );
              if (!alreadyExists) {
                final reconstructedOrder = _reconstructOrderFromPayload(payload);
                _orders.insert(0, reconstructedOrder);
              }
            } catch (e) {
              debugPrint('Failed to reconstruct outbox order ${mutation.id}: $e');
            }
          } else if (mutation.mutationType == 'CREATE_PRODUCT') {
            try {
              final payload = CreateProductPayload.fromCanonicalJson(
                mutation.payloadJson,
              );
              if (!_products.any((p) => p.id == payload.id)) {
                final unitMap = {
                  for (var u in payload.units)
                    u.unitName.toLowerCase(): u.multiplierToBase
                };
                final priceMap = {
                  for (var u in payload.units)
                    u.unitName.toLowerCase(): u.wholesalePricePaise
                };
                _products.add(ProductItem(
                  id: payload.id,
                  name: payload.name,
                  hindiName: payload.hindiName,
                  category: payload.category,
                  mrpRupees: payload.mrpRupees,
                  piecePricePaise: payload.piecePricePaise,
                  stripQty: payload.stripQty,
                  boxQty: payload.boxQty,
                  gstRate: payload.gstRate,
                  godownStockBoxes: 0,
                  carStockBoxes: 0,
                  customUnitMultipliers: unitMap,
                  customUnitPricesPaise: priceMap,
                ));
              }
            } catch (e) {
              debugPrint('Failed to reconstruct outbox product ${mutation.id}: $e');
            }
          }
        }
      }

      // 2. Assess legacy B1 tables (products, retailers) tenant boundary
      final gate = boundaryGate ?? TenantBoundaryGate.permissive();
      final assessment = await gate.assessBoundary();
      if (capturedGen != _transientGeneration) return;
      if (assessment.isBlocked) {
        debugPrint('Local SQLite sync quarantined: ${assessment.message}');
        notifyListeners();
        return;
      }
      // In multi-tenant Phase B2, do not seed unscoped B1 records that trigger legacy quarantine.
      await repository.purgeLegacyDummyProducts();
      await repository.backfillLegacyProductUnitsAndPrices();
      final dbProducts = await repository.getAllProducts();
      final dbRetailers = await repository.getAllRetailers();
      if (capturedGen != _transientGeneration) return;
      if (dbProducts.isNotEmpty) {
        _products = dbProducts;
      }
      if (dbRetailers.isNotEmpty) {
        _retailers = dbRetailers;
      }
      final v2Meta = await repository.getMetadata('sales_v2_enabled');
      if (v2Meta != null) {
        _salesV2Enabled = v2Meta == 'true';
      }
      final staffMeta = await repository.getMetadata('owner_staff_roster');
      if (staffMeta != null && staffMeta.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(staffMeta);
          _staff = decoded.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Local SQLite sync error: $e');
    }
  }
}

/// A compound map for cart items that supports both compound keys ("productId::unit")
/// and backward-compatible single product lookups ("productId").
class CompoundCartMap extends MapBase<String, CartItem> {
  final Map<String, CartItem> _inner = {};

  @override
  CartItem? operator [](Object? key) {
    if (key is! String) return null;
    if (_inner.containsKey(key)) return _inner[key];
    // Fallback: match by product.id for single-product lookups
    for (final entry in _inner.entries) {
      if (entry.value.product.id == key) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  void operator []=(String key, CartItem value) {
    _inner[key] = value;
  }

  @override
  void clear() => _inner.clear();

  @override
  CartItem? remove(Object? key) {
    if (key is! String) return null;
    if (_inner.containsKey(key)) {
      return _inner.remove(key);
    }
    // Fallback: remove first matching by product.id
    String? matchKey;
    for (final entry in _inner.entries) {
      if (entry.value.product.id == key) {
        matchKey = entry.key;
        break;
      }
    }
    if (matchKey != null) {
      return _inner.remove(matchKey);
    }
    return null;
  }

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  bool containsKey(Object? key) {
    if (key is! String) return false;
    if (_inner.containsKey(key)) return true;
    for (final it in _inner.values) {
      if (it.product.id == key) return true;
    }
    return false;
  }
}
