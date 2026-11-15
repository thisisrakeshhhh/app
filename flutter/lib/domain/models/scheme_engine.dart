import '../../models/models.dart';

/// Supported types of pricing schemes in Indian FMCG wholesale distribution.
enum SchemeType {
  /// Wholesale volume promotion: Buy X quantity, get Y quantity free (e.g. Buy 10 Peti, get 1 Peti Free).
  buyXGetYFree,

  /// Cash discount on immediate payment (e.g. 3% off on COD, Cash, or UPI).
  cashDiscount,

  /// Bulk crate-to-piece tiered volume pricing (e.g. 1-4 boxes = ₹800, 5-9 boxes = ₹780, 10+ boxes = ₹750).
  volumePriceBreak,

  /// Flat discount per unit or per line (e.g. ₹50 off per box).
  flatDiscount,
}

/// A quantity-based price break tier for bulk purchasing.
class PriceBreakTier {
  /// Minimum quantity (inclusive) required to trigger this tier.
  final int minQuantity;

  /// Optional maximum quantity (inclusive). Null means open-ended (e.g. 10+).
  final int? maxQuantity;

  /// Authoritative wholesale unit price in integer paise for this tier (if fixed).
  final int? unitPricePaise;

  /// Optional percentage discount applied to base unit price (e.g. 5.0 for 5% off).
  final double? discountPercent;

  /// Optional flat discount per unit in integer paise (e.g. 2000 for ₹20 off).
  final int? discountPaise;

  /// Optional human-readable label for the tier (e.g. "5-9 Boxes Tier", "10+ Bulk Tier").
  final String? tierLabel;

  const PriceBreakTier({
    required this.minQuantity,
    this.maxQuantity,
    this.unitPricePaise,
    this.discountPercent,
    this.discountPaise,
    this.tierLabel,
  });

  int resolveUnitPricePaise(int basePricePaise) {
    if (unitPricePaise != null) return unitPricePaise!;
    if (discountPercent != null && discountPercent! > 0) {
      final disc = (basePricePaise * discountPercent! / 100.0).round();
      return basePricePaise - disc;
    }
    if (discountPaise != null && discountPaise! > 0) {
      final res = basePricePaise - discountPaise!;
      return res < 0 ? 0 : res;
    }
    return basePricePaise;
  }

  bool applies(int quantity) {
    if (quantity < minQuantity) return false;
    if (maxQuantity != null && quantity > maxQuantity!) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'minQuantity': minQuantity,
        if (maxQuantity != null) 'maxQuantity': maxQuantity,
        if (unitPricePaise != null) 'unitPricePaise': unitPricePaise,
        if (discountPercent != null) 'discountPercent': discountPercent,
        if (discountPaise != null) 'discountPaise': discountPaise,
        if (tierLabel != null) 'tierLabel': tierLabel,
      };

  factory PriceBreakTier.fromJson(Map<String, dynamic> json) => PriceBreakTier(
        minQuantity: (json['minQuantity'] as num).toInt(),
        maxQuantity: (json['maxQuantity'] as num?)?.toInt(),
        unitPricePaise: (json['unitPricePaise'] as num?)?.toInt(),
        discountPercent: (json['discountPercent'] as num?)?.toDouble(),
        discountPaise: (json['discountPaise'] as num?)?.toInt(),
        tierLabel: json['tierLabel'] as String?,
      );
}

/// Represents a dynamic pricing scheme or wholesale volume promotion.
class PricingScheme {
  final String id;
  final String name;
  final String description;
  final SchemeType type;

  /// Specific product ID to match, or null to apply across all products.
  final String? productId;

  /// Specific unit name ('box', 'strip', 'piece') to match, or null for all units.
  final String? unitName;

  /// Minimum ordered quantity to qualify for this scheme.
  final int minQuantity;

  /// Free units awarded per minQuantity (for buyXGetYFree).
  final int freeQuantity;

  /// Percentage discount (e.g. 3.0 for 3% cash discount).
  final double discountPercent;

  /// Fixed discount in integer paise (for flatDiscount).
  final int discountPaise;

  /// List of quantity-based price break tiers (for volumePriceBreak).
  final List<PriceBreakTier> priceBreakTiers;

  /// Eligible payment modes (e.g. ['COD', 'CASH', 'UPI']). Empty means any payment mode.
  final List<String> eligiblePaymentModes;

  /// Whether this scheme is currently active.
  final bool isActive;

  const PricingScheme({
    required this.id,
    required this.name,
    this.description = '',
    required this.type,
    this.productId,
    this.unitName,
    this.minQuantity = 1,
    this.freeQuantity = 0,
    this.discountPercent = 0.0,
    this.discountPaise = 0,
    this.priceBreakTiers = const [],
    this.eligiblePaymentModes = const [],
    this.isActive = true,
  });

  bool matchesProduct(String targetProductId) {
    return productId == null || productId == targetProductId;
  }

  bool matchesUnit(String targetUnitName) {
    return unitName == null || unitName!.toLowerCase() == targetUnitName.toLowerCase();
  }

  bool matchesPaymentMode(String targetPaymentMode) {
    if (eligiblePaymentModes.isEmpty) return true;
    final normalized = targetPaymentMode.trim().toUpperCase();
    return eligiblePaymentModes.any((m) => m.trim().toUpperCase() == normalized);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.name,
        if (productId != null) 'productId': productId,
        if (unitName != null) 'unitName': unitName,
        'minQuantity': minQuantity,
        'freeQuantity': freeQuantity,
        'discountPercent': discountPercent,
        'discountPaise': discountPaise,
        'priceBreakTiers': priceBreakTiers.map((t) => t.toJson()).toList(),
        'eligiblePaymentModes': eligiblePaymentModes,
        'isActive': isActive,
      };

  factory PricingScheme.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'buyXGetYFree';
    final type = SchemeType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => SchemeType.buyXGetYFree,
    );

    final rawTiers = json['priceBreakTiers'] as List<dynamic>?;
    final tiers = rawTiers != null
        ? rawTiers.map((t) => PriceBreakTier.fromJson(t as Map<String, dynamic>)).toList()
        : <PriceBreakTier>[];

    final rawModes = json['eligiblePaymentModes'] as List<dynamic>?;
    final modes = rawModes != null ? rawModes.map((m) => m.toString()).toList() : <String>[];

    return PricingScheme(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: type,
      productId: json['productId'] as String?,
      unitName: json['unitName'] as String?,
      minQuantity: (json['minQuantity'] as num?)?.toInt() ?? 1,
      freeQuantity: (json['freeQuantity'] as num?)?.toInt() ?? 0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
      priceBreakTiers: tiers,
      eligiblePaymentModes: modes,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Evaluated outcome of schemes on a single product packaging unit and quantity.
class SchemeEvaluationResult {
  final int effectiveUnitPricePaise;
  final int freeQuantity;
  final int discountPaise;
  final String? appliedSchemeName;
  final String? appliedTierLabel;
  final List<String> activeBadges;

  const SchemeEvaluationResult({
    required this.effectiveUnitPricePaise,
    this.freeQuantity = 0,
    this.discountPaise = 0,
    this.appliedSchemeName,
    this.appliedTierLabel,
    this.activeBadges = const [],
  });

  double get effectiveUnitPriceRupees => effectiveUnitPricePaise / 100.0;
  double get discountRupees => discountPaise / 100.0;
}

/// Deterministic, zero-float scheme calculation engine for FMCG sales orders.
class DynamicSchemeEngine {
  /// Evaluates all active schemes for a given product line item.
  static SchemeEvaluationResult evaluateItem({
    required ProductItem product,
    required OrderUnit unit,
    required int quantity,
    required List<PricingScheme> activeSchemes,
    String? paymentMode,
  }) {
    final unitName = unit.name;
    final baseUnitPricePaise = product.priceForUnit(unit);
    int effectiveUnitPricePaise = baseUnitPricePaise;
    int freeQuantity = 0;
    int discountPaise = 0;
    String? appliedSchemeName;
    String? appliedTierLabel;
    final badges = <String>[];

    // 1. Evaluate Volume Price Break Tiers
    final volumeSchemes = activeSchemes.where((s) =>
        s.isActive &&
        s.type == SchemeType.volumePriceBreak &&
        s.matchesProduct(product.id) &&
        s.matchesUnit(unitName)).toList();

    final prodVolSchemes = volumeSchemes.where((s) => s.productId == product.id).toList();
    final effectiveVolumeSchemes = prodVolSchemes.isNotEmpty ? prodVolSchemes : volumeSchemes;

    for (final scheme in effectiveVolumeSchemes) {
      for (final tier in scheme.priceBreakTiers) {
        if (tier.applies(quantity)) {
          effectiveUnitPricePaise = tier.resolveUnitPricePaise(baseUnitPricePaise);
          appliedTierLabel = tier.tierLabel ?? 'Volume Tier (${tier.minQuantity}+)';
          appliedSchemeName = scheme.name;
          badges.add('🏷️ $appliedTierLabel');
          break; // First matching tier takes precedence
        }
      }
    }

    // 2. Evaluate Buy X Get Y Free Schemes
    final buyXSchemes = activeSchemes.where((s) =>
        s.isActive &&
        s.type == SchemeType.buyXGetYFree &&
        s.matchesProduct(product.id) &&
        s.matchesUnit(unitName)).toList();

    final prodBuyXSchemes = buyXSchemes.where((s) => s.productId == product.id).toList();
    final effectiveBuyXSchemes = prodBuyXSchemes.isNotEmpty ? prodBuyXSchemes : buyXSchemes;

    for (final scheme in effectiveBuyXSchemes) {
      if (scheme.minQuantity > 0) {
        final multiplier = quantity ~/ scheme.minQuantity;
        if (multiplier > 0) {
          freeQuantity += multiplier * scheme.freeQuantity;
          appliedSchemeName ??= scheme.name;
          badges.add('🎁 ${scheme.name} (+$freeQuantity Free)');
        }
      }
    }

    // 3. Evaluate Cash Discount / Immediate Payment Schemes
    if (paymentMode != null) {
      final cashSchemes = activeSchemes.where((s) =>
          s.isActive &&
          s.type == SchemeType.cashDiscount &&
          s.matchesProduct(product.id) &&
          s.matchesUnit(unitName) &&
          s.matchesPaymentMode(paymentMode));

      final lineSubtotalPaise = quantity * effectiveUnitPricePaise;
      for (final scheme in cashSchemes) {
        if (scheme.discountPercent > 0.0) {
          final disc = (lineSubtotalPaise * scheme.discountPercent / 100.0).round();
          discountPaise += disc;
          appliedSchemeName ??= scheme.name;
          badges.add('💰 ${scheme.name} (-₹${(disc / 100.0).toStringAsFixed(2)})');
        } else if (scheme.discountPaise > 0) {
          discountPaise += scheme.discountPaise;
          appliedSchemeName ??= scheme.name;
        }
      }

      // 4. Evaluate Flat Line Discount Schemes
      final flatSchemes = activeSchemes.where((s) =>
          s.isActive &&
          s.type == SchemeType.flatDiscount &&
          s.matchesProduct(product.id) &&
          s.matchesUnit(unitName) &&
          s.matchesPaymentMode(paymentMode) &&
          quantity >= s.minQuantity);

      for (final scheme in flatSchemes) {
        if (scheme.discountPaise > 0) {
          discountPaise += scheme.discountPaise * quantity;
          appliedSchemeName ??= scheme.name;
        }
      }
    }

    return SchemeEvaluationResult(
      effectiveUnitPricePaise: effectiveUnitPricePaise,
      freeQuantity: freeQuantity,
      discountPaise: discountPaise,
      appliedSchemeName: appliedSchemeName,
      appliedTierLabel: appliedTierLabel,
      activeBadges: badges,
    );
  }

  /// Evaluates and mutates a list of CartItems in-place to apply all active schemes.
  static void applyToCart({
    required Iterable<CartItem> cartItems,
    required List<PricingScheme> activeSchemes,
    required String paymentMode,
  }) {
    for (final item in cartItems) {
      final result = evaluateItem(
        product: item.product,
        unit: item.unit,
        quantity: item.quantity,
        activeSchemes: activeSchemes,
        paymentMode: paymentMode,
      );

      item.customTierUnitPricePaise =
          result.effectiveUnitPricePaise != item.baseUnitPricePaise
              ? result.effectiveUnitPricePaise
              : null;
      item.freeQuantity = result.freeQuantity;
      item.discountPaise = result.discountPaise;
      item.appliedSchemeName = result.appliedSchemeName;
    }
  }
}
