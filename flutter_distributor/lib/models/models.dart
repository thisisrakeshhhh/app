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

class ProductItem {
  final String id;
  final String name;
  final String hindiName;
  final String category;
  final double mrpRupees;
  final int piecePricePaise; // Wholesale base price per piece
  final int stripQty; // Pieces in 1 hanging strip / ladi
  final int boxQty; // Pieces in 1 box / carton / peti
  final double gstRate; // e.g. 12.0 or 18.0 or 5.0
  int godownStockBoxes; // Live available in Godown / Warehouse
  int carStockBoxes; // Live stock loaded in Delivery Car / Van
  final String badge;
  final String imageUrl;

  ProductItem({
    required this.id,
    required this.name,
    required this.hindiName,
    required this.category,
    required this.mrpRupees,
    required this.piecePricePaise,
    required this.stripQty,
    required this.boxQty,
    this.gstRate = 18.0,
    required this.godownStockBoxes,
    this.carStockBoxes = 0,
    this.badge = '',
    this.imageUrl = '',
  });

  // Wholesale pricing with bulk slab discount
  int priceForUnit(OrderUnit unit) {
    switch (unit) {
      case OrderUnit.piece:
        return piecePricePaise;
      case OrderUnit.strip:
        // Slight strip wholesale incentive
        return (piecePricePaise * stripQty * 0.98).round();
      case OrderUnit.box:
        // 5% carton bulk discount for kirana retail
        return (piecePricePaise * boxQty * 0.95).round();
    }
  }

  double priceRupeesForUnit(OrderUnit unit) => priceForUnit(unit) / 100.0;

  int piecesForUnit(OrderUnit unit) {
    switch (unit) {
      case OrderUnit.piece:
        return 1;
      case OrderUnit.strip:
        return stripQty;
      case OrderUnit.box:
        return boxQty;
    }
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
  });

  double get creditLimitRupees => creditLimitPaise / 100.0;
  double get outstandingRupees => outstandingPaise / 100.0;
  double get availableCreditRupees =>
      (creditLimitPaise - outstandingPaise) / 100.0;

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
