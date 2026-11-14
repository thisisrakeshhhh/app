import '../l10n/app_language.dart';
import '../domain/models/phone_sanitizer.dart';
import '../domain/models/retailer_business_validator.dart';
import '../domain/models/retailer_classification.dart';

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

enum BatchStatus {
  active,
  depleted,
  expired,
  recalled,
}

extension BatchStatusExt on BatchStatus {
  String get code {
    switch (this) {
      case BatchStatus.active:
        return 'ACTIVE';
      case BatchStatus.depleted:
        return 'DEPLETED';
      case BatchStatus.expired:
        return 'EXPIRED';
      case BatchStatus.recalled:
        return 'RECALLED';
    }
  }

  static BatchStatus fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'DEPLETED':
        return BatchStatus.depleted;
      case 'EXPIRED':
        return BatchStatus.expired;
      case 'RECALLED':
        return BatchStatus.recalled;
      case 'ACTIVE':
      default:
        return BatchStatus.active;
    }
  }
}

class ProductBatch {
  final String id;
  final String productId;
  final String batchNo;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final String? rackBin;
  final int receivedQuantity;
  final int remainingQuantity;
  final int committedQuantity;
  final BatchStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductBatch({
    required this.id,
    required this.productId,
    required this.batchNo,
    this.mfgDate,
    this.expiryDate,
    this.rackBin,
    required this.receivedQuantity,
    required this.remainingQuantity,
    this.committedQuantity = 0,
    this.status = BatchStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Available units in this batch (uncommitted)
  int get availableQuantity {
    final net = remainingQuantity - committedQuantity;
    return net > 0 ? net : 0;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    return expiryDate!.isBefore(DateTime(now.year, now.month, now.day));
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    return expiryDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  ProductBatch copyWith({
    String? id,
    String? productId,
    String? batchNo,
    DateTime? mfgDate,
    DateTime? expiryDate,
    String? rackBin,
    int? receivedQuantity,
    int? remainingQuantity,
    int? committedQuantity,
    BatchStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchNo: batchNo ?? this.batchNo,
      mfgDate: mfgDate ?? this.mfgDate,
      expiryDate: expiryDate ?? this.expiryDate,
      rackBin: rackBin ?? this.rackBin,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      committedQuantity: committedQuantity ?? this.committedQuantity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BatchPickAllocation {
  final ProductBatch batch;
  final int allocatedPieces;

  const BatchPickAllocation({
    required this.batch,
    required this.allocatedPieces,
  });
}

class ProductItem {
  final String id;
  final String name;
  final String hindiName;
  final String gujaratiName;
  final String category;
  final int mrpPaise; // Authoritative retail maximum price in integer paise
  double get mrpRupees => mrpPaise / 100.0; // Display helper
  final int piecePricePaise; // Wholesale base price per piece
  final int stripQty; // Pieces in 1 hanging strip / ladi
  final int boxQty; // Pieces in 1 box / carton / peti
  final double gstRate; // e.g. 12.0 or 18.0 or 5.0
  int godownStockBoxes; // Live physical stock in Godown / Warehouse
  int godownReservedBoxes; // Live reserved boxes in Godown
  int godownReservedPieces; // Live reserved loose pieces in Godown
  int carStockBoxes; // Live stock loaded in Delivery Car / Van
  final String badge;
  final String imageUrl;
  final Map<String, int>? customUnitMultipliers; // unitName -> multiplierToBase
  final Map<String, int>? customUnitPricesPaise; // unitName -> wholesalePricePaise
  final String batchNumber;
  final DateTime? expiryDate;
  final int reorderLevelBoxes;
  final int costPricePaise;
  final bool isArchived;
  final String shelfLocation;

  ProductItem({
    required this.id,
    required this.name,
    required this.hindiName,
    this.gujaratiName = '',
    required this.category,
    int? mrpPaise,
    double? mrpRupees,
    required this.piecePricePaise,
    required this.stripQty,
    required this.boxQty,
    this.gstRate = 18.0,
    this.godownStockBoxes = 0,
    this.godownReservedBoxes = 0,
    this.godownReservedPieces = 0,
    this.carStockBoxes = 0,
    this.badge = '',
    this.imageUrl = '',
    this.customUnitMultipliers,
    this.customUnitPricesPaise,
    this.batchNumber = 'LOT-2026-A1',
    this.expiryDate,
    this.reorderLevelBoxes = 30,
    int? costPricePaise,
    this.isArchived = false,
    this.shelfLocation = '',
  })  : mrpPaise = mrpPaise ?? (mrpRupees != null ? (mrpRupees * 100).round() : 0),
        costPricePaise = costPricePaise ?? (piecePricePaise * 85 ~/ 100);

  // Stock calculations: Physical, Reserved, and Available
  int get physicalGodownPieces => godownStockBoxes * boxQty;
  int get reservedGodownPieces => (godownReservedBoxes * boxQty) + godownReservedPieces;
  bool get isGodownOverReserved => reservedGodownPieces > physicalGodownPieces;
  int get godownOverReservedPieces => isGodownOverReserved ? (reservedGodownPieces - physicalGodownPieces) : 0;

  int get availableGodownPieces {
    if (reservedGodownPieces > physicalGodownPieces) {
      throw StateError(
        'INVALID_INVENTORY_STATE for product $id: Reserved stock ($reservedGodownPieces pieces) exceeds physical stock ($physicalGodownPieces pieces).',
      );
    }
    return physicalGodownPieces - reservedGodownPieces;
  }
  int get availableGodownBoxes => availableGodownPieces ~/ boxQty;
  int get availableGodownLoosePieces => availableGodownPieces % boxQty;

  String nameForLanguage(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.hi:
        return hindiName.isNotEmpty ? hindiName : name;
      case AppLanguage.gu:
        return gujaratiName.isNotEmpty ? gujaratiName : (hindiName.isNotEmpty ? hindiName : name);
      case AppLanguage.hinglish:
      case AppLanguage.en:
        return name;
    }
  }

  bool get isLowStock => godownStockBoxes > 0 && godownStockBoxes <= reorderLevelBoxes;
  bool get isOutOfStock => godownStockBoxes <= 0;

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    return expiryDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool get isExpired {
    final d = daysUntilExpiry;
    return d != null && d < 0;
  }

  bool get isExpiringSoon {
    final d = daysUntilExpiry;
    return d != null && d >= 0 && d <= 60;
  }

  int get godownValuationPaise => godownStockBoxes * boxQty * piecePricePaise;
  double get godownValuationRupees => godownValuationPaise / 100.0;

  ProductItem copyWith({
    String? id,
    String? name,
    String? hindiName,
    String? gujaratiName,
    String? category,
    int? mrpPaise,
    int? piecePricePaise,
    int? stripQty,
    int? boxQty,
    double? gstRate,
    int? godownStockBoxes,
    int? godownReservedBoxes,
    int? godownReservedPieces,
    int? carStockBoxes,
    String? badge,
    String? imageUrl,
    Map<String, int>? customUnitMultipliers,
    Map<String, int>? customUnitPricesPaise,
    String? batchNumber,
    DateTime? expiryDate,
    int? reorderLevelBoxes,
    int? costPricePaise,
    bool? isArchived,
    String? shelfLocation,
  }) {
    return ProductItem(
      id: id ?? this.id,
      name: name ?? this.name,
      hindiName: hindiName ?? this.hindiName,
      gujaratiName: gujaratiName ?? this.gujaratiName,
      category: category ?? this.category,
      mrpPaise: mrpPaise ?? this.mrpPaise,
      piecePricePaise: piecePricePaise ?? this.piecePricePaise,
      stripQty: stripQty ?? this.stripQty,
      boxQty: boxQty ?? this.boxQty,
      gstRate: gstRate ?? this.gstRate,
      godownStockBoxes: godownStockBoxes ?? this.godownStockBoxes,
      godownReservedBoxes: godownReservedBoxes ?? this.godownReservedBoxes,
      godownReservedPieces: godownReservedPieces ?? this.godownReservedPieces,
      carStockBoxes: carStockBoxes ?? this.carStockBoxes,
      badge: badge ?? this.badge,
      imageUrl: imageUrl ?? this.imageUrl,
      customUnitMultipliers: customUnitMultipliers ?? this.customUnitMultipliers,
      customUnitPricesPaise: customUnitPricesPaise ?? this.customUnitPricesPaise,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      reorderLevelBoxes: reorderLevelBoxes ?? this.reorderLevelBoxes,
      costPricePaise: costPricePaise ?? this.costPricePaise,
      isArchived: isArchived ?? this.isArchived,
      shelfLocation: shelfLocation ?? this.shelfLocation,
    );
  }

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
  String? whatsappPhone;
  String? gstType; // 'CONSUMER' | 'COMPOSITION' | 'REGULAR'
  String? panNumber;
  bool isSkipped;
  String? skipReason;

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
    this.whatsappPhone,
    this.gstType = 'CONSUMER',
    this.panNumber,
    this.isSkipped = false,
    this.skipReason,
  });

  String? get normalizedPhone =>
      PhoneSanitizer.normalize(phone) ?? PhoneSanitizer.canonicalize(phone);
  String? get displayPhone => PhoneSanitizer.formatDisplay(phone);
  String? get normalizedWhatsappPhone => whatsappPhone != null
      ? (PhoneSanitizer.normalize(whatsappPhone) ??
          PhoneSanitizer.canonicalize(whatsappPhone!))
      : null;

  String? get resolvedPanNumber =>
      RetailerBusinessValidator.resolvePan(pan: panNumber, gstin: gstin);
  bool get hasValidGstin => RetailerBusinessValidator.isValidGstin(gstin);

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
  String get classCode => RetailerClassification.normalize(classType);

  /// Display name for retailer classification without invented marketing hype.
  String get classDisplayName => RetailerClassification.displayName(classType);

  int get defaultCreditLimitPaise =>
      RetailerClassification.defaultCreditLimitPaise(classType);
  int get defaultCreditDays =>
      RetailerClassification.defaultCreditDays(classType);
  int get defaultVisitFrequencyDays =>
      RetailerClassification.defaultVisitFrequencyDays(classType);
  bool get canUseCredit => RetailerClassification.canUseCredit(
        classType: classType,
        creditLimitPaise: creditLimitPaise,
      );

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

  void skipShop(String reason) {
    isSkipped = true;
    skipReason = reason;
    if (currentVisitStartTime != null) {
      endVisit();
    }
  }

  void clearSkip() {
    isSkipped = false;
    skipReason = null;
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

enum WarehouseTaskStage {
  waitingApproval,
  approvedToPick,
  assignedToWorker,
  pickingInProgress,
  waitingPacking,
  packingInProgress,
  packedReady,
  handedOver,
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
  bool isOwnerApproved;

  // Warehouse workflow tracking (optional, backward-compatible)
  WarehouseTaskStage? warehouseTaskStage;
  String assignedWorkerName;
  String packingWorkerName;
  int packedCartonCount;
  String handedOverBy;
  String receivedByDriver;
  DateTime? handedOverAt;
  final Map<String, int> pickedLineQuantities;
  final Map<String, int> damagedLineQuantities;
  final Map<String, String> lineIssueNotes;

  WarehouseTaskStage get effectiveWarehouseStage {
    if (stage == OrderLifecycleStage.orderSend || stage == OrderLifecycleStage.delivered) {
      return WarehouseTaskStage.handedOver;
    }
    if (stage == OrderLifecycleStage.readyStock) {
      return WarehouseTaskStage.packedReady;
    }
    if (!isOwnerApproved) {
      return WarehouseTaskStage.waitingApproval;
    }
    if (warehouseTaskStage != null && warehouseTaskStage != WarehouseTaskStage.waitingApproval) {
      return warehouseTaskStage!;
    }
    if (assignedWorkerName.isNotEmpty) {
      return WarehouseTaskStage.assignedToWorker;
    }
    return WarehouseTaskStage.approvedToPick;
  }

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
    this.isOwnerApproved = false,
    this.warehouseTaskStage,
    this.assignedWorkerName = '',
    this.packingWorkerName = '',
    this.packedCartonCount = 1,
    this.handedOverBy = '',
    this.receivedByDriver = '',
    this.handedOverAt,
    Map<String, int>? pickedLineQuantities,
    Map<String, int>? damagedLineQuantities,
    Map<String, String>? lineIssueNotes,
  })  : pickedLineQuantities = pickedLineQuantities ?? {},
        damagedLineQuantities = damagedLineQuantities ?? {},
        lineIssueNotes = lineIssueNotes ?? {};

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
    bool? isOwnerApproved,
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
      isOwnerApproved: isOwnerApproved ?? this.isOwnerApproved,
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

/// Delivery Truck / Mobile Fleet Stock Model.
/// Supports multiple trucks in the warehouse loading fleet.
class DeliveryTruck {
  final String id;
  final String vehicleNumber;
  final String vehicleModel; // e.g. "Tata Ace Gold", "Mahindra Bolero Maxi", "Eicher Pro 2049"
  final String driverName;
  final String driverPhone;
  final int capacityBoxes;
  final Map<String, int> loadedStockBoxes; // productId -> boxes loaded on this specific truck

  DeliveryTruck({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.driverName,
    required this.driverPhone,
    this.capacityBoxes = 150,
    Map<String, int>? loadedStockBoxes,
  }) : loadedStockBoxes = loadedStockBoxes != null ? Map.from(loadedStockBoxes) : {};

  int get totalLoadedBoxes => loadedStockBoxes.values.fold(0, (sum, b) => sum + b);

  double get capacityUtilizationPercent =>
      capacityBoxes > 0 ? (totalLoadedBoxes / capacityBoxes).clamp(0.0, 1.0) * 100 : 0.0;

  int getStockForProduct(String productId) => loadedStockBoxes[productId] ?? 0;

  void loadStock(String productId, int boxes) {
    if (boxes <= 0) return;
    loadedStockBoxes[productId] = (loadedStockBoxes[productId] ?? 0) + boxes;
  }

  void unloadStock(String productId, int boxes) {
    if (boxes <= 0) return;
    final current = loadedStockBoxes[productId] ?? 0;
    if (boxes >= current) {
      loadedStockBoxes.remove(productId);
    } else {
      loadedStockBoxes[productId] = current - boxes;
    }
  }

  DeliveryTruck copyWith({
    String? id,
    String? vehicleNumber,
    String? vehicleModel,
    String? driverName,
    String? driverPhone,
    int? capacityBoxes,
    Map<String, int>? loadedStockBoxes,
  }) {
    return DeliveryTruck(
      id: id ?? this.id,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      capacityBoxes: capacityBoxes ?? this.capacityBoxes,
      loadedStockBoxes: loadedStockBoxes != null ? Map.from(loadedStockBoxes) : Map.from(this.loadedStockBoxes),
    );
  }
}

/// Distributor Staff Member for Owner Role Management.
class StaffMember {
  final String id;
  final String username;
  final String fullName;
  final String role; // 'SALES', 'WAREHOUSE', 'DELIVERY', 'ADMIN', 'OWNER'
  bool isActive;
  final String? assignedBeat;
  final DateTime createdAt;

  StaffMember({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.isActive = true,
    this.assignedBeat,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role,
    'isActive': isActive,
    'assignedBeat': assignedBeat,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    fullName: (json['fullName'] ?? json['full_name'] ?? '') as String,
    role: json['role'] as String? ?? 'SALES',
    isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    assignedBeat: json['assignedBeat'] as String?,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
  );
}

/// Sales Representative Peer Performance & Competition Leaderboard Entry
class SalesRepLeaderboardEntry {
  final String id;
  final String repName;
  final String beatName;
  final double salesRevenueRupees;
  final int visitsCompleted;
  final int totalAssignedShops;
  final int ordersBooked;
  final double targetRevenueRupees;
  final bool isCurrentRep;
  final String badge;

  const SalesRepLeaderboardEntry({
    required this.id,
    required this.repName,
    required this.beatName,
    required this.salesRevenueRupees,
    required this.visitsCompleted,
    required this.totalAssignedShops,
    required this.ordersBooked,
    required this.targetRevenueRupees,
    this.isCurrentRep = false,
    this.badge = '',
  });

  double get targetAchievementPercent {
    if (targetRevenueRupees <= 0) return 0.0;
    return ((salesRevenueRupees / targetRevenueRupees) * 100.0).clamp(0.0, 200.0);
  }

  double get strikeRatePercent {
    if (totalAssignedShops <= 0) return 0.0;
    return ((visitsCompleted / totalAssignedShops) * 100.0).clamp(0.0, 100.0);
  }
}

/// Simple Truck Inward Item for Godown Receiving (Cart-style)
class TruckInwardItem {
  final String productId;
  final String productName;
  final int boxes;
  final int strips;
  final int pieces;

  const TruckInwardItem({
    required this.productId,
    required this.productName,
    this.boxes = 0,
    this.strips = 0,
    this.pieces = 0,
  });

  String get summary {
    final parts = <String>[];
    if (boxes > 0) parts.add('$boxes Peti/Box');
    if (strips > 0) parts.add('$strips Strip');
    if (pieces > 0) parts.add('$pieces Piece');
    return parts.isEmpty ? '0 Pcs' : parts.join(', ');
  }
}

/// Inward Receipt for stock arriving at godown by truck
class TruckInwardEntry {
  final String id;
  final String truckNumber;
  final String driverName;
  final String supplier;
  final DateTime arrivedAt;
  final List<TruckInwardItem> items;
  final int totalCartons;
  final int totalPieces;

  const TruckInwardEntry({
    required this.id,
    required this.truckNumber,
    required this.driverName,
    required this.supplier,
    required this.arrivedAt,
    required this.items,
    required this.totalCartons,
    required this.totalPieces,
  });
}

/// Real-time Outward Dispatch Log (where stock went)
class StockDispatchEntry {
  final String id;
  final String orderNumber;
  final String shopName;
  final String shopArea;
  final DateTime dispatchedAt;
  final String deliveryVehicle;
  final String itemsSummary;
  final int totalCartons;

  const StockDispatchEntry({
    required this.id,
    required this.orderNumber,
    required this.shopName,
    required this.shopArea,
    required this.dispatchedAt,
    required this.deliveryVehicle,
    required this.itemsSummary,
    required this.totalCartons,
  });
}

