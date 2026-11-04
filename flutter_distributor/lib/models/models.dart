enum AppRole {
  sales,
  inventory,
  logistics,
}

extension AppRoleExtension on AppRole {
  String get title {
    switch (this) {
      case AppRole.sales:
        return 'Sales Executive';
      case AppRole.inventory:
        return 'Godown & Inventory';
      case AppRole.logistics:
        return 'Logistics & Van';
    }
  }

  String get personaName {
    switch (this) {
      case AppRole.sales:
        return 'Vikram Rathore (Beat Sales)';
      case AppRole.inventory:
        return 'Central Godown (Basni)';
      case AppRole.logistics:
        return 'Suresh Yadav (Van 04)';
    }
  }

  String get subtitle {
    switch (this) {
      case AppRole.sales:
        return 'Jodhpur Central Beat (Sardarpura)';
      case AppRole.inventory:
        return 'Godown Stock Intake & Live Inventory';
      case AppRole.logistics:
        return 'RJ-19-GB-4021 • Tata Ace';
    }
  }
}

enum OrderUnit {
  piece,
  strip,
  box,
}

extension OrderUnitExt on OrderUnit {
  String get label {
    switch (this) {
      case OrderUnit.piece:
        return 'Piece (पीस)';
      case OrderUnit.strip:
        return 'Strip / Ladi (लड़ी)';
      case OrderUnit.box:
        return 'Box / Peti (पेटी)';
    }
  }

  String get shortCode {
    switch (this) {
      case OrderUnit.piece:
        return 'Pcs';
      case OrderUnit.strip:
        return 'Strip';
      case OrderUnit.box:
        return 'Box';
    }
  }
}

enum StockHealth {
  ok,
  lowStock,
  outOfStock,
}

class FourPartStockStatus {
  final int onHandBoxes;
  final int reservedBoxes;
  final int availableBoxes;
  final StockHealth health;

  const FourPartStockStatus({
    required this.onHandBoxes,
    required this.reservedBoxes,
    required this.availableBoxes,
    required this.health,
  });

  String get healthBadge {
    switch (health) {
      case StockHealth.outOfStock:
        return 'OUT';
      case StockHealth.lowStock:
        return 'LOW';
      case StockHealth.ok:
        return 'OK';
    }
  }
}

class SalespersonPerformance {
  final String name;
  final String beat;
  final int visitedShops;
  final int totalShops;
  final int ordersBooked;
  final int totalOrderValuePaise;
  final int cashCollectedPaise;

  const SalespersonPerformance({
    required this.name,
    required this.beat,
    required this.visitedShops,
    required this.totalShops,
    required this.ordersBooked,
    required this.totalOrderValuePaise,
    required this.cashCollectedPaise,
  });

  double get totalOrderValueRupees => totalOrderValuePaise / 100.0;
  double get cashCollectedRupees => cashCollectedPaise / 100.0;
}

class ProductPackagingUnit {
  final String id;
  final String productId;
  final String unitName;
  final int multiplierToBase;
  final bool isBaseUnit;
  final bool allowLooseSale;
  final bool canBuy;
  final bool canSell;
  final int wholesalePricePaise;
  final int mrpPaise;
  final int minOrderQty;

  bool get looseSale => allowLooseSale;

  const ProductPackagingUnit({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.multiplierToBase,
    this.isBaseUnit = false,
    this.allowLooseSale = true,
    this.canBuy = true,
    this.canSell = true,
    required this.wholesalePricePaise,
    this.mrpPaise = 0,
    this.minOrderQty = 1,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'productId': productId,
    'unitName': unitName,
    'multiplierToBase': multiplierToBase,
    'isBaseUnit': isBaseUnit,
    'allowLooseSale': allowLooseSale,
    'canBuy': canBuy,
    'canSell': canSell,
    'wholesalePricePaise': wholesalePricePaise,
    'mrpPaise': mrpPaise,
    'minOrderQty': minOrderQty,
  };

  factory ProductPackagingUnit.fromMap(Map<String, dynamic> map) =>
      ProductPackagingUnit(
        id: map['id'] as String,
        productId: map['productId'] as String,
        unitName: map['unitName'] as String,
        multiplierToBase: (map['multiplierToBase'] as num).toInt(),
        isBaseUnit: (map['isBaseUnit'] as bool?) ?? false,
        allowLooseSale: (map['allowLooseSale'] as bool?) ?? (map['loose_sale'] as bool?) ?? true,
        canBuy: (map['canBuy'] as bool?) ?? (map['can_buy'] as bool?) ?? true,
        canSell: (map['canSell'] as bool?) ?? (map['can_sell'] as bool?) ?? true,
        wholesalePricePaise: (map['wholesalePricePaise'] as num).toInt(),
        mrpPaise: (map['mrpPaise'] as num?)?.toInt() ?? 0,
        minOrderQty: (map['minOrderQty'] as num?)?.toInt() ?? 1,
      );
}

class ProductItem {
  final String id;
  final String name;
  final String hindiName;
  final String category;
  final int mrpPaise; // Authoritative retail maximum price in integer paise
  double get mrpRupees => mrpPaise / 100.0; // Display helper
  final int piecePricePaise; // Wholesale base price per piece
  final int stripQty; // Pieces in 1 hanging strip / ladi
  final int boxQty; // Pieces in 1 box / carton / peti
  final double gstRate; // e.g. 12.0 or 18.0 or 5.0
  int godownStockBoxes; // Live available in Godown / Warehouse
  int carStockBoxes; // Live stock loaded in Delivery Car / Van
  final String badge;
  final String imageUrl;
  final Map<String, int>? customUnitMultipliers; // unitName -> multiplierToBase
  final Map<String, int>? customUnitPricesPaise; // unitName -> wholesalePricePaise

  ProductItem({
    required this.id,
    required this.name,
    required this.hindiName,
    required this.category,
    int? mrpPaise,
    double? mrpRupees,
    required this.piecePricePaise,
    required this.stripQty,
    required this.boxQty,
    this.gstRate = 18.0,
    this.godownStockBoxes = 0,
    this.carStockBoxes = 0,
    this.badge = '',
    this.imageUrl = '',
    this.customUnitMultipliers,
    this.customUnitPricesPaise,
  }) : mrpPaise = mrpPaise ?? (mrpRupees != null ? (mrpRupees * 100).round() : 0);

  // Wholesale pricing: data-driven from unit_prices, with base piece fallback
  int priceForUnit(OrderUnit unit) {
    final key = unit.name.toLowerCase();
    if (customUnitPricesPaise != null && customUnitPricesPaise!.containsKey(key)) {
      return customUnitPricesPaise![key]!;
    }
    // Fallback if not configured: piece price * multiplier
    return piecePricePaise * piecesForUnit(unit);
  }

  double priceRupeesForUnit(OrderUnit unit) => priceForUnit(unit) / 100.0;

  int piecesForUnit(OrderUnit unit) {
    final key = unit.name.toLowerCase();
    if (customUnitMultipliers != null && customUnitMultipliers!.containsKey(key)) {
      return customUnitMultipliers![key]!;
    }
    switch (unit) {
      case OrderUnit.piece:
        return 1;
      case OrderUnit.strip:
        return stripQty;
      case OrderUnit.box:
        return boxQty;
    }
  }

  int priceForUnitName(String unitName) {
    final key = unitName.toLowerCase();
    if (customUnitPricesPaise != null && customUnitPricesPaise!.containsKey(key)) {
      return customUnitPricesPaise![key]!;
    }
    return piecePricePaise * piecesForUnitName(unitName);
  }

  int piecesForUnitName(String unitName) {
    final key = unitName.toLowerCase();
    if (customUnitMultipliers != null && customUnitMultipliers!.containsKey(key)) {
      return customUnitMultipliers![key]!;
    }
    if (key == 'piece') return 1;
    if (key == 'strip') return stripQty;
    if (key == 'box') return boxQty;
    return 1;
  }

  int get totalStockBoxes => godownStockBoxes + carStockBoxes;
  int get stripsPerBox => boxQty ~/ (stripQty > 0 ? stripQty : 1);
}

class CartItem {
  final ProductItem product;
  OrderUnit unit;
  int quantity;

  CartItem({
    required this.product,
    this.unit = OrderUnit.box,
    this.quantity = 1,
  });

  String get cartKey => makeCartKey(product.id, unit);
  static String makeCartKey(String productId, OrderUnit unit) => '$productId::${unit.name}';

  int get totalPieces => quantity * product.piecesForUnit(unit);
  int get unitPricePaise => product.priceForUnit(unit);
  int get totalPaise => quantity * unitPricePaise;
  double get totalRupees => totalPaise / 100.0;

  // Indian GST calculations (Intra-state Rajasthan)
  int get taxableAmountPaise {
    final rateFraction = 1.0 + (product.gstRate / 100.0);
    return (totalPaise / rateFraction).round();
  }

  int get totalGstPaise => totalPaise - taxableAmountPaise;
  int get cgstPaise => (totalGstPaise / 2).round();
  int get sgstPaise => totalGstPaise - cgstPaise;

  double get taxableRupees => taxableAmountPaise / 100.0;
  double get totalGstRupees => totalGstPaise / 100.0;
  double get cgstRupees => cgstPaise / 100.0;
  double get sgstRupees => sgstPaise / 100.0;
}

class RetailerShop {
  final String id;
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String area;
  int creditLimitPaise;
  int outstandingPaise;
  bool visitedToday;
  int todayOrderTotalPaise;
  int totalTimeSpentSeconds;
  DateTime? currentVisitStartTime;
  DateTime? lastVisitEndTime;
  int visitCountToday;
  final double? latitude;
  final double? longitude;
  String classType;
  String classSource;
  String? routeId;
  String shopType;
  String? gstin;
  String? pincode;
  String? landmark;
  String status;
  String? createdByUserId;
  double? locationAccuracyMeters;
  String syncStatus;

  RetailerShop({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.creditLimitPaise,
    required this.outstandingPaise,
    this.visitedToday = false,
    this.todayOrderTotalPaise = 0,
    this.totalTimeSpentSeconds = 0,
    this.currentVisitStartTime,
    this.lastVisitEndTime,
    this.visitCountToday = 0,
    this.latitude,
    this.longitude,
    this.classType = 'NEW',
    this.classSource = 'MANUAL',
    this.routeId,
    this.shopType = 'KIRANA',
    this.gstin,
    this.pincode,
    this.landmark,
    this.status = 'ACTIVE',
    this.createdByUserId,
    this.locationAccuracyMeters,
    this.syncStatus = 'PENDING',
  });

  double get creditLimitRupees => creditLimitPaise / 100.0;
  double get outstandingRupees => outstandingPaise / 100.0;
  double get availableCreditRupees =>
      (creditLimitPaise - outstandingPaise) / 100.0;

  /// Formatted unit number (e.g. "Shop 12", "Plot 5", "SCO 42") if explicitly present in real address text, else null.
  String? get unitNo {
    if (address.contains('SCO') || address.contains('Shop') || address.contains('Plot')) {
      final match = RegExp(r'(SCO|Shop|Plot)(\s*(No\.?|Number|#|:|-)?\s*[A-Za-z0-9-]+)', caseSensitive: false).firstMatch(address);
      if (match != null) return match.group(0)!.trim();
    }
    return null;
  }

  /// Backward-compatible alias for unitNo.
  String? get scoNo => unitNo;

  /// Formatted Gaali / street name if explicitly present in real address text, else null.
  String? get gaaliNo {
    if (address.contains('Gali') || address.contains('Gaali') || address.contains('Road') || address.contains('Street') || address.contains('Lane')) {
      final match = RegExp(r'(Gali|Gaali|Road|Street|Lane)(\s*(No\.?|Number|#)?\s*[A-Za-z0-9-]+)', caseSensitive: false).firstMatch(address);
      if (match != null) return match.group(0)!.trim();
    }
    return null;
  }

  /// Canonical letter code: A, B, C, D, or NEW.
  String get classCode {
    final c = classType.toUpperCase();
    if (c == 'CLASS_A' || c == 'A') return 'A';
    if (c == 'CLASS_B' || c == 'B') return 'B';
    if (c == 'CLASS_C' || c == 'C') return 'C';
    if (c == 'CLASS_D' || c == 'D') return 'D';
    return 'NEW';
  }

  /// Display name for retailer classification without invented marketing hype.
  String get classDisplayName {
    final code = classCode;
    return 'Class $code';
  }

  bool get isCheckedIn => currentVisitStartTime != null;

  int get currentVisitSeconds {
    if (currentVisitStartTime == null) return 0;
    return DateTime.now().difference(currentVisitStartTime!).inSeconds;
  }

  int get allTimeSpentSeconds => totalTimeSpentSeconds + currentVisitSeconds;

  static String formatDuration(int totalSecs) {
    if (totalSecs <= 0) return '0s';
    final hours = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    final secs = totalSecs % 60;

    if (hours > 0) {
      return '${hours}h ${mins.toString().padLeft(2, '0')}m';
    } else if (mins > 0) {
      return '${mins}m ${secs.toString().padLeft(2, '0')}s';
    } else {
      return '${secs}s';
    }
  }

  String get totalTimeSpentFormatted => formatDuration(allTimeSpentSeconds);

  RetailerShop copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? phone,
    String? address,
    String? area,
    int? creditLimitPaise,
    int? outstandingPaise,
    bool? visitedToday,
    int? todayOrderTotalPaise,
    int? totalTimeSpentSeconds,
    DateTime? currentVisitStartTime,
    DateTime? lastVisitEndTime,
    int? visitCountToday,
    double? latitude,
    double? longitude,
    String? classType,
    String? classSource,
    String? routeId,
    String? shopType,
    String? gstin,
    String? pincode,
    String? landmark,
    String? status,
    String? createdByUserId,
    double? locationAccuracyMeters,
    String? syncStatus,
  }) {
    return RetailerShop(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      area: area ?? this.area,
      creditLimitPaise: creditLimitPaise ?? this.creditLimitPaise,
      outstandingPaise: outstandingPaise ?? this.outstandingPaise,
      visitedToday: visitedToday ?? this.visitedToday,
      todayOrderTotalPaise: todayOrderTotalPaise ?? this.todayOrderTotalPaise,
      totalTimeSpentSeconds: totalTimeSpentSeconds ?? this.totalTimeSpentSeconds,
      currentVisitStartTime: currentVisitStartTime ?? this.currentVisitStartTime,
      lastVisitEndTime: lastVisitEndTime ?? this.lastVisitEndTime,
      visitCountToday: visitCountToday ?? this.visitCountToday,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      classType: classType ?? this.classType,
      classSource: classSource ?? this.classSource,
      routeId: routeId ?? this.routeId,
      shopType: shopType ?? this.shopType,
      gstin: gstin ?? this.gstin,
      pincode: pincode ?? this.pincode,
      landmark: landmark ?? this.landmark,
      status: status ?? this.status,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      locationAccuracyMeters: locationAccuracyMeters ?? this.locationAccuracyMeters,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
  String get activeVisitFormatted => formatDuration(currentVisitSeconds);

  void startVisit() {
    if (currentVisitStartTime == null) {
      currentVisitStartTime = DateTime.now();
      visitedToday = true;
      visitCountToday += 1;
    }
  }

  int endVisit() {
    if (currentVisitStartTime != null) {
      final elapsed = DateTime.now().difference(currentVisitStartTime!).inSeconds;
      totalTimeSpentSeconds += elapsed;
      lastVisitEndTime = DateTime.now();
      currentVisitStartTime = null;
      return elapsed;
    }
    return 0;
  }
}

enum OrderLifecycleStage {
  booking, // New booked order waiting for godown picking
  readyStock, // Picked and loaded into Car / Delivery Van
  orderSend, // Out for delivery on beat route
  delivered, // Delivered, OTP verified & cash collected
  rejected, // Rejected by server or outbox validation
}

extension OrderLifecycleExt on OrderLifecycleStage {
  String get label {
    switch (this) {
      case OrderLifecycleStage.booking:
        return 'Order Booking';
      case OrderLifecycleStage.readyStock:
        return 'Ready Stock (Car Loaded)';
      case OrderLifecycleStage.orderSend:
        return 'Order Send (On Route)';
      case OrderLifecycleStage.delivered:
        return 'Delivered & Settled';
      case OrderLifecycleStage.rejected:
        return 'Rejected (Reservation Released)';
    }
  }

  int get stepIndex {
    switch (this) {
      case OrderLifecycleStage.booking:
        return 0;
      case OrderLifecycleStage.readyStock:
        return 1;
      case OrderLifecycleStage.orderSend:
        return 2;
      case OrderLifecycleStage.delivered:
        return 3;
      case OrderLifecycleStage.rejected:
        return -1;
    }
  }
}

class DistributorOrder {
  final String id;
  final String orderNumber;
  final String shopId;
  final String shopName;
  final String shopPhone;
  final String address;
  final List<CartItem> items;
  final int totalPaise;
  final int taxablePaise;
  final int totalGstPaise;
  final String paymentMode; // COD or Credit
  OrderLifecycleStage stage;
  String assignedCarNumber;
  final String otp;
  final DateTime createdAt;
  bool isPaid;

  DistributorOrder({
    required this.id,
    required this.orderNumber,
    required this.shopId,
    required this.shopName,
    required this.shopPhone,
    required this.address,
    required this.items,
    required this.totalPaise,
    required this.taxablePaise,
    required this.totalGstPaise,
    required this.paymentMode,
    this.stage = OrderLifecycleStage.booking,
    this.assignedCarNumber = 'RJ-19-GB-4021',
    required this.otp,
    required this.createdAt,
    this.isPaid = false,
  });

  double get totalRupees => totalPaise / 100.0;
  double get taxableRupees => taxablePaise / 100.0;
  double get gstRupees => totalGstPaise / 100.0;

  DistributorOrder copyWith({
    String? id,
    String? orderNumber,
    String? shopId,
    String? shopName,
    String? shopPhone,
    String? address,
    List<CartItem>? items,
    int? totalPaise,
    int? taxablePaise,
    int? totalGstPaise,
    String? paymentMode,
    OrderLifecycleStage? stage,
    String? assignedCarNumber,
    String? otp,
    DateTime? createdAt,
    bool? isPaid,
  }) {
    return DistributorOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      address: address ?? this.address,
      items: items ?? this.items,
      totalPaise: totalPaise ?? this.totalPaise,
      taxablePaise: taxablePaise ?? this.taxablePaise,
      totalGstPaise: totalGstPaise ?? this.totalGstPaise,
      paymentMode: paymentMode ?? this.paymentMode,
      stage: stage ?? this.stage,
      assignedCarNumber: assignedCarNumber ?? this.assignedCarNumber,
      otp: otp ?? this.otp,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

class DeliveryStop {
  final String id;
  final String orderId;
  final String shopName;
  final String ownerName;
  final String phone;
  final String address;
  final String area;
  final int codAmountPaise;
  final String serverOtp;
  final int itemCount;
  bool isDelivered;
  bool cashCollected;
  DateTime? deliveredAt;
  final double? latitude;
  final double? longitude;

  DeliveryStop({
    required this.id,
    required this.orderId,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.codAmountPaise,
    required this.serverOtp,
    required this.itemCount,
    this.isDelivered = false,
    this.cashCollected = false,
    this.deliveredAt,
    this.latitude,
    this.longitude,
  });

  double get codAmountRupees => codAmountPaise / 100.0;
}

/// Physical Warehouse / Godown Depot hub model.
class WarehouseHub {
  final String id;
  final String name;
  final String code;
  final String address;
  final double? latitude;
  final double? longitude;
  final int capacityBoxes;
  final int activeStaffCount;
  int godownStockBoxes;
  int carStockBoxes;

  WarehouseHub({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    this.latitude,
    this.longitude,
    this.capacityBoxes = 1000,
    this.activeStaffCount = 4,
    this.godownStockBoxes = 0,
    this.carStockBoxes = 0,
  });

  int get totalStockBoxes => godownStockBoxes + carStockBoxes;
}
