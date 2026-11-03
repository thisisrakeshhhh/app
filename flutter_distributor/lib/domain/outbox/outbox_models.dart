import 'dart:convert';
import 'dart:math';

/// Mutation types supported by RouteFlow outbox.
enum MutationType {
  createOrder,
  recordCollection,
  cashHandover,
  stockInward,
  transferToCar,
  stockAdjustment,
}

extension MutationTypeExtension on MutationType {
  String toDbValue() {
    switch (this) {
      case MutationType.createOrder:
        return 'CREATE_ORDER';
      case MutationType.recordCollection:
        return 'RECORD_COLLECTION';
      case MutationType.cashHandover:
        return 'CASH_HANDOVER';
      case MutationType.stockInward:
        return 'STOCK_INWARD';
      case MutationType.transferToCar:
        return 'TRANSFER_TO_CAR';
      case MutationType.stockAdjustment:
        return 'STOCK_ADJUSTMENT';
    }
  }

  static MutationType fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'CREATE_ORDER':
        return MutationType.createOrder;
      case 'RECORD_COLLECTION':
        return MutationType.recordCollection;
      case 'CASH_HANDOVER':
        return MutationType.cashHandover;
      case 'STOCK_INWARD':
        return MutationType.stockInward;
      case 'TRANSFER_TO_CAR':
        return MutationType.transferToCar;
      case 'STOCK_ADJUSTMENT':
        return MutationType.stockAdjustment;
      default:
        throw ArgumentError('Unknown MutationType db value: $value');
    }
  }
}

/// Outbox mutation synchronization status.
enum SyncStatus {
  pending,
  syncing,
  synced,
  retryableFailure,
  failedPermanent,
}

extension SyncStatusExtension on SyncStatus {
  String toDbValue() {
    switch (this) {
      case SyncStatus.pending:
        return 'PENDING';
      case SyncStatus.syncing:
        return 'SYNCING';
      case SyncStatus.synced:
        return 'SYNCED';
      case SyncStatus.retryableFailure:
        return 'RETRYABLE_FAILURE';
      case SyncStatus.failedPermanent:
        return 'FAILED_PERMANENT';
    }
  }

  static SyncStatus fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return SyncStatus.pending;
      case 'SYNCING':
        return SyncStatus.syncing;
      case 'SYNCED':
        return SyncStatus.synced;
      case 'RETRYABLE_FAILURE':
        return SyncStatus.retryableFailure;
      case 'FAILED_PERMANENT':
        return SyncStatus.failedPermanent;
      default:
        throw ArgumentError('Unknown SyncStatus db value: $value');
    }
  }
}

/// Snapshot of retailer metadata captured immutably at the time of order confirmation.
class RetailerSnapshot {
  final String id;
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String area;

  const RetailerSnapshot({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.area,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
        'area': area,
      };

  factory RetailerSnapshot.fromJson(Map<String, dynamic> json) =>
      RetailerSnapshot(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        ownerName: json['ownerName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        area: json['area'] as String? ?? '',
      );
}

/// Structured item payload preserving all entered quantities, units, packaging ratios,
/// and calculated taxes for exact post-catalogue reconstruction.
class OrderItemPayload {
  final String productId;
  final String productName;
  final String orderedUnit; // 'box', 'strip', 'piece'
  final int orderedQuantity;
  final int stripQty;
  final int boxQty;
  final int totalPieces; // Base integer pieces
  final int unitPricePaiseAtTime;
  final int piecePricePaiseAtTime;
  final double mrpRupeesAtTime;
  final double gstRateAtTime;
  final int taxableAmountPaise;
  final int gstAmountPaise;
  final int lineTotalPaise;
  final int discountPaise;
  final int freeQuantity;

  const OrderItemPayload({
    required this.productId,
    this.productName = '',
    this.orderedUnit = 'box',
    int? orderedQuantity,
    int? quantity,
    this.stripQty = 10,
    this.boxQty = 50,
    int? totalPieces,
    int? unitPricePaiseAtTime,
    int? piecePricePaiseAtTime,
    int? pricePaiseAtTime,
    this.mrpRupeesAtTime = 0.0,
    this.gstRateAtTime = 18.0,
    this.taxableAmountPaise = 0,
    this.gstAmountPaise = 0,
    int? lineTotalPaise,
    this.discountPaise = 0,
    this.freeQuantity = 0,
  })  : orderedQuantity = orderedQuantity ?? quantity ?? 1,
        unitPricePaiseAtTime = unitPricePaiseAtTime ?? pricePaiseAtTime ?? 0,
        piecePricePaiseAtTime = piecePricePaiseAtTime ?? pricePaiseAtTime ?? 0,
        totalPieces = totalPieces ?? ((orderedQuantity ?? quantity ?? 1) * 50),
        lineTotalPaise = lineTotalPaise ??
            ((orderedQuantity ?? quantity ?? 1) *
                (unitPricePaiseAtTime ?? pricePaiseAtTime ?? 0));

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'orderedUnit': orderedUnit,
        'orderedQuantity': orderedQuantity,
        'stripQty': stripQty,
        'boxQty': boxQty,
        'totalPieces': totalPieces,
        'unitPricePaiseAtTime': unitPricePaiseAtTime,
        'piecePricePaiseAtTime': piecePricePaiseAtTime,
        'mrpRupeesAtTime': mrpRupeesAtTime,
        'gstRateAtTime': gstRateAtTime,
        'taxableAmountPaise': taxableAmountPaise,
        'gstAmountPaise': gstAmountPaise,
        'lineTotalPaise': lineTotalPaise,
        'discountPaise': discountPaise,
        'freeQuantity': freeQuantity,
      };

  factory OrderItemPayload.fromJson(Map<String, dynamic> json) =>
      OrderItemPayload(
        productId: json['productId'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        orderedUnit: json['orderedUnit'] as String? ?? 'box',
        orderedQuantity: (json['orderedQuantity'] as num?)?.toInt() ?? 1,
        stripQty: (json['stripQty'] as num?)?.toInt() ?? 10,
        boxQty: (json['boxQty'] as num?)?.toInt() ?? 50,
        totalPieces: (json['totalPieces'] as num?)?.toInt() ??
            ((json['orderedQuantity'] as num?)?.toInt() ?? 1) * 50,
        unitPricePaiseAtTime:
            (json['unitPricePaiseAtTime'] as num?)?.toInt() ??
                (json['pricePaiseAtTime'] as num?)?.toInt() ??
                0,
        piecePricePaiseAtTime:
            (json['piecePricePaiseAtTime'] as num?)?.toInt() ??
                (json['pricePaiseAtTime'] as num?)?.toInt() ??
                0,
        mrpRupeesAtTime: (json['mrpRupeesAtTime'] as num?)?.toDouble() ?? 0.0,
        gstRateAtTime: (json['gstRateAtTime'] as num?)?.toDouble() ?? 18.0,
        taxableAmountPaise: (json['taxableAmountPaise'] as num?)?.toInt() ?? 0,
        gstAmountPaise: (json['gstAmountPaise'] as num?)?.toInt() ?? 0,
        lineTotalPaise: (json['lineTotalPaise'] as num?)?.toInt() ??
            ((json['orderedQuantity'] as num?)?.toInt() ?? 1) *
                ((json['unitPricePaiseAtTime'] as num?)?.toInt() ?? 0),
        discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
        freeQuantity: (json['freeQuantity'] as num?)?.toInt() ?? 0,
      );
}

/// Financial summary totals snapshot in integer paise.
class OrderTotalsPayload {
  final int totalAmountPaise;
  final int taxableAmountPaise;
  final int gstAmountPaise;
  final int discountAmountPaise;

  const OrderTotalsPayload({
    required this.totalAmountPaise,
    required this.taxableAmountPaise,
    required this.gstAmountPaise,
    this.discountAmountPaise = 0,
  });

  Map<String, dynamic> toJson() => {
        'totalAmountPaise': totalAmountPaise,
        'taxableAmountPaise': taxableAmountPaise,
        'gstAmountPaise': gstAmountPaise,
        'discountAmountPaise': discountAmountPaise,
      };

  factory OrderTotalsPayload.fromJson(Map<String, dynamic> json) =>
      OrderTotalsPayload(
        totalAmountPaise: (json['totalAmountPaise'] as num?)?.toInt() ?? 0,
        taxableAmountPaise: (json['taxableAmountPaise'] as num?)?.toInt() ?? 0,
        gstAmountPaise: (json['gstAmountPaise'] as num?)?.toInt() ?? 0,
        discountAmountPaise:
            (json['discountAmountPaise'] as num?)?.toInt() ?? 0,
      );
}

/// Canonical payload for a CREATE_ORDER outbox mutation.
class CreateOrderMutationPayload {
  final String provisionalOrderId;
  final String orderNumber; // Unmistakably prefixed: 'LOCAL-ORD-...'
  final String idempotencyKey;
  final String organizationId;
  final String userId;
  final String userRole; // Historical metadata only; not authorization
  final RetailerSnapshot retailer;
  final List<OrderItemPayload> items;
  final OrderTotalsPayload totals;
  final String paymentMode;
  final String assignedCarNumber;
  final int clientCreatedAtEpochMs;

  CreateOrderMutationPayload({
    required this.provisionalOrderId,
    this.orderNumber = '',
    this.idempotencyKey = '',
    this.organizationId = '',
    this.userId = '',
    this.userRole = 'SALES',
    RetailerSnapshot? retailer,
    required this.items,
    OrderTotalsPayload? totals,
    required this.paymentMode,
    this.assignedCarNumber = '',
    int? clientCreatedAtEpochMs,
    // Backwards compatibility parameters for test fixtures:
    String? retailerId,
    int? totalAmountPaise,
    int? createdAtEpochMs,
  })  : retailer = retailer ??
            RetailerSnapshot(
              id: retailerId ?? '',
              name: '',
              ownerName: '',
              phone: '',
              address: '',
              area: '',
            ),
        totals = totals ??
            OrderTotalsPayload(
              totalAmountPaise: totalAmountPaise ?? 0,
              taxableAmountPaise: 0,
              gstAmountPaise: 0,
            ),
        clientCreatedAtEpochMs =
            clientCreatedAtEpochMs ?? createdAtEpochMs ?? 0;

  Map<String, dynamic> toJson() => {
        'provisionalOrderId': provisionalOrderId,
        'orderNumber': orderNumber,
        'idempotencyKey': idempotencyKey,
        'organizationId': organizationId,
        'userId': userId,
        'userRole': userRole,
        'retailer': retailer.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'totals': totals.toJson(),
        'paymentMode': paymentMode,
        'assignedCarNumber': assignedCarNumber,
        'clientCreatedAtEpochMs': clientCreatedAtEpochMs,
      };

  String toCanonicalJson() => jsonEncode(toJson());

  factory CreateOrderMutationPayload.fromJson(Map<String, dynamic> json) {
    // Graceful backwards compatibility for test fixtures
    final retJson = json['retailer'];
    final retailer = retJson is Map<String, dynamic>
        ? RetailerSnapshot.fromJson(retJson)
        : RetailerSnapshot(
            id: json['retailerId'] as String? ?? '',
            name: '',
            ownerName: '',
            phone: '',
            address: '',
            area: '',
          );

    final totalsJson = json['totals'];
    final totals = totalsJson is Map<String, dynamic>
        ? OrderTotalsPayload.fromJson(totalsJson)
        : OrderTotalsPayload(
            totalAmountPaise:
                (json['totalAmountPaise'] as num?)?.toInt() ?? 0,
            taxableAmountPaise: 0,
            gstAmountPaise: 0,
          );

    return CreateOrderMutationPayload(
      provisionalOrderId: json['provisionalOrderId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ??
          'LOCAL-ORD-${json['provisionalOrderId'] ?? 'UNKNOWN'}',
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userRole: json['userRole'] as String? ?? 'SALES',
      retailer: retailer,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItemPayload.fromJson(item as Map<String, dynamic>))
          .toList(),
      totals: totals,
      paymentMode: json['paymentMode'] as String? ?? 'COD',
      assignedCarNumber: json['assignedCarNumber'] as String? ?? '',
      clientCreatedAtEpochMs:
          (json['clientCreatedAtEpochMs'] as num?)?.toInt() ??
              (json['createdAtEpochMs'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory CreateOrderMutationPayload.fromCanonicalJson(String raw) =>
      CreateOrderMutationPayload.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
}

/// Thrown when a retry attempts to reuse an idempotency key with an altered payload.
class IdempotencyPayloadMismatchException implements Exception {
  final String message;
  const IdempotencyPayloadMismatchException(this.message);

  @override
  String toString() => 'IdempotencyPayloadMismatchException: $message';
}

/// Generates a standard RFC 4122 version 4 UUID string.
String generateUuidV4() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122
  return [
    bytes.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(10, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
  ].join('-');
}
