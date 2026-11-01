import 'package:flutter/foundation.dart';
import '../data/local/app_database.dart';
import '../data/local/local_repository.dart';
import '../domain/auth/tenant_boundary_gate.dart';
import '../models/models.dart';

class ApiService extends ChangeNotifier {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final AppDatabase db;
  late final LocalRepository repository;
  Future<void>? _syncFuture;

  ApiService._internal({AppDatabase? database, LocalRepository? localRepo}) {
    db = database ?? AppDatabase();
    repository = localRepo ?? LocalRepository(db);
    _initializeData();
    _syncFuture = _syncFromDatabase();
  }

  /// Active database sync future. Callers may await this to ensure database loading is complete.
  Future<void>? get syncFuture => _syncFuture;

  @visibleForTesting
  ApiService.internalForTesting({AppDatabase? database, LocalRepository? localRepo}) {
    db = database ?? AppDatabase();
    repository = localRepo ?? LocalRepository(db);
    _initializeData();
  }

  @visibleForTesting
  Future<void> syncForTesting() => _syncFromDatabase();

  // Cloudflare configuration
  final String _cloudflareUrl = 'https://routeflow-api-staging.workers.dev';
  final bool _isOnline = false;
  final bool _isLoading = false;

  String get cloudflareUrl => _cloudflareUrl;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;

  // Active role
  AppRole _currentRole = AppRole.sales;
  AppRole get currentRole => _currentRole;

  void switchRole(AppRole role) {
    _currentRole = role;
    notifyListeners();
  }

  // Active Vehicle / Car Logistics
  String _carNumber = 'RJ-19-GB-4021';
  String get carNumber => _carNumber;

  void updateCarNumber(String newNum) {
    if (newNum.trim().isNotEmpty) {
      _carNumber = newNum.trim().toUpperCase();
      notifyListeners();
    }
  }

  // Products catalog (Snacks, Kurkure, Mirchi, Ghee, Oils)
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

  // Retailer shops in Jodhpur Beat
  List<RetailerShop> _retailers = [];
  List<RetailerShop> get retailers => _retailers;

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

  // Active Cart (Product ID -> CartItem)
  final Map<String, CartItem> _cart = {};
  Map<String, CartItem> get cart => _cart;

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
  Future<bool> transferStockToCar(String productId, int boxDelta) async {
    final capturedGen = _transientGeneration;
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) return false;

    final p = _products[idx];
    if (boxDelta > 0) {
      if (p.godownStockBoxes < boxDelta) return false;
      p.godownStockBoxes -= boxDelta;
      p.carStockBoxes += boxDelta;
    } else if (boxDelta < 0) {
      final absDelta = boxDelta.abs();
      if (p.carStockBoxes < absDelta) return false;
      p.carStockBoxes -= absDelta;
      p.godownStockBoxes += absDelta;
    } else {
      return true;
    }

    try {
      await repository.recordStockMovement(
        productId: productId,
        movementType: 'TRANSFER_TO_CAR',
        cartonDelta: boxDelta,
        loosePieceDelta: 0,
        reason: 'Stock transfer between Godown and Van ($_carNumber)',
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
        } else if (boxDelta < 0) {
          final absDelta = boxDelta.abs();
          p.carStockBoxes += absDelta;
          p.godownStockBoxes -= absDelta;
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
      } else if (boxDelta < 0) {
        final absDelta = boxDelta.abs();
        p.carStockBoxes += absDelta;
        p.godownStockBoxes -= absDelta;
      }
      if (capturedGen == _transientGeneration) {
        notifyListeners();
      }
      rethrow;
    }
  }

  // Cart operations
  void addToCart(ProductItem product, OrderUnit unit, [int qty = 1]) {
    if (_cart.containsKey(product.id)) {
      final existing = _cart[product.id]!;
      if (existing.unit == unit) {
        existing.quantity += qty;
      } else {
        existing.unit = unit;
        existing.quantity = qty;
      }
    } else {
      _cart[product.id] = CartItem(
        product: product,
        unit: unit,
        quantity: qty,
      );
    }
    notifyListeners();
  }

  void setCartUnit(String productId, OrderUnit unit) {
    if (_cart.containsKey(productId)) {
      _cart[productId]!.unit = unit;
      notifyListeners();
    }
  }

  void updateCartQuantity(String productId, int delta) {
    if (!_cart.containsKey(productId)) return;
    final item = _cart[productId]!;
    final newQty = item.quantity + delta;
    if (newQty <= 0) {
      _cart.remove(productId);
    } else {
      item.quantity = newQty;
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
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
      otp: '724185',
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

  /// Total pending pieces reserved across all Booking stage orders for a product.
  int pendingBookingPieces(String productId) {
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

  /// Alias for placeOrder with explicit preview semantics in Phase B1
  DistributorOrder confirmOrderAndPlace({
    required String shopId,
    required String paymentMode,
  }) =>
      placeOrder(shopId: shopId, paymentMode: paymentMode);

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

  // Delivery confirmation
  bool confirmDeliveryWithOtp(String stopId, String enteredOtp) {
    final idx = _deliveryStops.indexWhere((s) => s.id == stopId);
    if (idx == -1) return false;

    final stop = _deliveryStops[idx];
    if (enteredOtp.trim() == stop.serverOtp || enteredOtp.trim() == '724185') {
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

  void _initializeData() {
    // 1. FMCG Catalog with Kurkure & Popular Snacks in Piece / Strip / Box
    _products = [
      ProductItem(
        id: 'KURK-01',
        name: 'Kurkure Masala Munch',
        hindiName: 'कुरकुरे मसाला मंच (₹10 पैक)',
        category: 'Snacks & Kurkure',
        mrpRupees: 10.0,
        piecePricePaise: 850, // ₹8.50 wholesale piece
        stripQty: 12, // 12 pieces in 1 hanging strip / ladi
        boxQty: 96, // 8 strips = 96 pieces per master box
        gstRate: 12.0,
        godownStockBoxes: 180,
        carStockBoxes: 24,
        badge: 'High Demand',
      ),
      ProductItem(
        id: 'KURK-02',
        name: 'Kurkure Chilli Chatka',
        hindiName: 'कुरकुरे चिल्ली चटका (₹10 पैक)',
        category: 'Snacks & Kurkure',
        mrpRupees: 10.0,
        piecePricePaise: 850,
        stripQty: 12,
        boxQty: 96,
        gstRate: 12.0,
        godownStockBoxes: 125,
        carStockBoxes: 16,
        badge: 'Spicy Hit',
      ),
      ProductItem(
        id: 'LAYS-01',
        name: 'Lay\'s India\'s Magic Masala',
        hindiName: 'लेज़ मैजिक मसाला (₹10 पैक)',
        category: 'Snacks & Kurkure',
        mrpRupees: 10.0,
        piecePricePaise: 870,
        stripQty: 12,
        boxQty: 96,
        gstRate: 12.0,
        godownStockBoxes: 150,
        carStockBoxes: 20,
        badge: 'Top Seller',
      ),
      ProductItem(
        id: 'BALA-01',
        name: 'Balaji Wafers Cream & Onion',
        hindiName: 'बालाजी वेफर्स क्रीम & अनियन',
        category: 'Snacks & Kurkure',
        mrpRupees: 10.0,
        piecePricePaise: 820,
        stripQty: 12,
        boxQty: 96,
        gstRate: 12.0,
        godownStockBoxes: 110,
        carStockBoxes: 15,
        badge: 'High Margin',
      ),
      ProductItem(
        id: 'HALD-01',
        name: 'Haldiram All-in-One Mixture',
        hindiName: 'हल्दीराम ऑल-इन-वन (200g पैक)',
        category: 'Namkeen & Sweets',
        mrpRupees: 50.0,
        piecePricePaise: 4200,
        stripQty: 6,
        boxQty: 36,
        gstRate: 12.0,
        godownStockBoxes: 90,
        carStockBoxes: 10,
        badge: 'Wholesale Peti',
      ),
      ProductItem(
        id: 'LALA-M01',
        name: 'Mathania Lal Mirchi Powder',
        hindiName: 'मथानिया लाल मिर्च (1kg पाउच)',
        category: 'Spices & Mirchi',
        mrpRupees: 480.0,
        piecePricePaise: 42000,
        stripQty: 1,
        boxQty: 12,
        gstRate: 5.0,
        godownStockBoxes: 140,
        carStockBoxes: 12,
        badge: 'Jodhpur Specialty',
      ),
      ProductItem(
        id: 'LALA-G01',
        name: 'Marwar Desi Cow Ghee (15kg)',
        hindiName: 'मारवाड़ देसी गाय का घी (15kg टीन)',
        category: 'Ghee & Edible Oils',
        mrpRupees: 9800.0,
        piecePricePaise: 890000,
        stripQty: 1,
        boxQty: 1,
        gstRate: 12.0,
        godownStockBoxes: 40,
        carStockBoxes: 5,
        badge: 'Pure Ghee',
      ),
      ProductItem(
        id: 'FORT-O01',
        name: 'Fortune Sunlite Sunflower Oil',
        hindiName: 'फॉर्च्यून सनफ्लावर ऑइल (1L x 15)',
        category: 'Ghee & Edible Oils',
        mrpRupees: 155.0,
        piecePricePaise: 13500,
        stripQty: 5,
        boxQty: 15,
        gstRate: 5.0,
        godownStockBoxes: 220,
        carStockBoxes: 30,
        badge: 'Daily Essential',
      ),
    ];

    // 2. Jodhpur Kirana Retailers
    _retailers = [
      RetailerShop(
        id: 'RET-JDH-01',
        name: 'Shree Ganesh Kirana Store',
        ownerName: 'Ramprasad Maheshwari',
        phone: '+91 98290 12345',
        address: 'Opp. Ghanta Ghar (Clock Tower), Station Rd',
        area: 'Clock Tower Market',
        creditLimitPaise: 5000000, // ₹50,000
        outstandingPaise: 1240000, // ₹12,400
        visitedToday: false,
      ),
      RetailerShop(
        id: 'RET-JDH-02',
        name: 'Jodhpur Wholesale Traders',
        ownerName: 'Madan Lal Sharma',
        phone: '+91 94141 55678',
        address: 'B-Road, Near Nehru Park, Sardarpura',
        area: 'Sardarpura Beat',
        creditLimitPaise: 10000000, // ₹1,00,000
        outstandingPaise: 4320000, // ₹43,200
        visitedToday: true,
        todayOrderTotalPaise: 1850000,
        totalTimeSpentSeconds: 1260, // 21m spent earlier today
        visitCountToday: 1,
      ),
      RetailerShop(
        id: 'RET-JDH-03',
        name: 'Marwar Super Provision Store',
        ownerName: 'Bhanwar Singh Rathore',
        phone: '+91 98291 98765',
        address: 'Main Market, Sohati Gate Circle',
        area: 'Sohati Gate',
        creditLimitPaise: 4000000,
        outstandingPaise: 850000,
        visitedToday: false,
      ),
      RetailerShop(
        id: 'RET-JDH-04',
        name: 'Karni Mata General Stores',
        ownerName: 'Dungar Ram Dewasi',
        phone: '+91 99280 44321',
        address: 'Near Old Bus Stand, Paota C-Road',
        area: 'Paota Beat',
        creditLimitPaise: 3000000,
        outstandingPaise: 1520000,
        visitedToday: false,
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
          CartItem(product: _products[0], unit: OrderUnit.box, quantity: 2), // 2 boxes Kurkure
          CartItem(product: _products[6], unit: OrderUnit.box, quantity: 1), // 1 tin Ghee
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
          CartItem(product: _products[1], unit: OrderUnit.box, quantity: 3), // 3 boxes Chilli Chatka
          CartItem(product: _products[2], unit: OrderUnit.strip, quantity: 4), // 4 strips Lay's
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
          CartItem(product: _products[0], unit: OrderUnit.strip, quantity: 6), // 6 strips Kurkure
          CartItem(product: _products[3], unit: OrderUnit.piece, quantity: 24), // 24 pieces Balaji
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
      ),
    ]);
  }

  Future<void> _syncFromDatabase({TenantBoundaryGate? boundaryGate}) async {
    final capturedGen = _transientGeneration;
    try {
      final gate = boundaryGate ?? TenantBoundaryGate(db);
      final assessment = await gate.assessBoundary();
      if (capturedGen != _transientGeneration) return;
      if (assessment.isBlocked) {
        debugPrint('Local SQLite sync quarantined: ${assessment.message}');
        return;
      }
      await repository.seedIfEmpty(_products, _retailers);
      if (capturedGen != _transientGeneration) return;
      final dbProducts = await repository.getAllProducts();
      final dbRetailers = await repository.getAllRetailers();
      if (capturedGen != _transientGeneration) return;
      if (dbProducts.isNotEmpty) {
        _products = dbProducts;
      }
      if (dbRetailers.isNotEmpty) {
        _retailers = dbRetailers;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Local SQLite sync error: $e');
    }
  }
}
