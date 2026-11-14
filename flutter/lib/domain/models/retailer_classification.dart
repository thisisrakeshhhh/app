/// Domain model representing Retailer Classification in FMCG distribution.
///
/// Canonical Classes:
/// - `A`: Top retail / supermarket. High volume, daily beat, 14 days credit terms, ₹50,000 credit limit.
/// - `B`: Standard busy kirana store. Medium volume, alternate days beat, 7 days credit terms, ₹25,000 credit limit.
/// - `C`: Small kirana / tea stall / paan shop. Low volume, twice-weekly beat, 3 days credit terms, ₹10,000 credit limit.
/// - `D`: High credit risk / defaulter. Weekly beat, 0 days credit terms, ₹0 credit limit (Strictly Cash Only).
/// - `NEW`: Newly onboarded shop pending owner approval. Daily beat, 0 days terms, ₹0 credit limit (Cash Only).
class RetailerClassification {
  RetailerClassification._();

  static const String classA = 'A';
  static const String classB = 'B';
  static const String classC = 'C';
  static const String classD = 'D';
  static const String classNew = 'NEW';

  static const Set<String> validClasses = {
    classA,
    classB,
    classC,
    classD,
    classNew,
  };

  /// Normalizes arbitrary raw class string (e.g. 'CLASS_A', 'class_b', 'a')
  /// to its canonical single-letter or 'NEW' code.
  static String normalize(String? raw) {
    if (raw == null) return classNew;
    final upper = raw.trim().toUpperCase();

    if (upper == 'A' || upper == 'CLASS_A' || upper == 'CLASS A') return classA;
    if (upper == 'B' || upper == 'CLASS_B' || upper == 'CLASS B') return classB;
    if (upper == 'C' || upper == 'CLASS_C' || upper == 'CLASS C') return classC;
    if (upper == 'D' || upper == 'CLASS_D' || upper == 'CLASS D') return classD;
    return classNew;
  }

  /// Human-friendly display label (e.g. 'Class A', 'Class NEW').
  static String displayName(String? raw) {
    final code = normalize(raw);
    return 'Class $code';
  }

  /// Default credit limit in paise for each classification.
  static int defaultCreditLimitPaise(String? raw) {
    switch (normalize(raw)) {
      case classA:
        return 5000000; // ₹50,000
      case classB:
        return 2500000; // ₹25,000
      case classC:
        return 1000000; // ₹10,000
      case classD:
        return 0; // ₹0 (Cash on Delivery)
      case classNew:
      default:
        return 0; // ₹0 (Unapproved new shops are cash-first)
    }
  }

  /// Default payment terms in days for each classification.
  static int defaultCreditDays(String? raw) {
    switch (normalize(raw)) {
      case classA:
        return 14;
      case classB:
        return 7;
      case classC:
        return 3;
      case classD:
      case classNew:
      default:
        return 0;
    }
  }

  /// Recommended beat visit frequency in days.
  static int defaultVisitFrequencyDays(String? raw) {
    switch (normalize(raw)) {
      case classA:
        return 1; // Daily
      case classB:
        return 2; // Alternate days
      case classC:
        return 3; // Twice weekly
      case classD:
        return 7; // Weekly
      case classNew:
      default:
        return 1; // Active follow-up
    }
  }

  /// Returns whether a retailer with the given class and credit limit is eligible
  /// to purchase on credit / khata.
  ///
  /// Invariants:
  /// - `NEW` and `D` are strictly cash-only regardless of any local credit limit field.
  /// - `A`, `B`, `C` are eligible if and only if their credit limit in paise is > 0.
  static bool canUseCredit({
    required String? classType,
    required int creditLimitPaise,
  }) {
    final code = normalize(classType);
    if (code == classNew || code == classD) {
      return false;
    }
    return creditLimitPaise > 0;
  }

  /// Role-based access rule: determines whether a user role can directly assign
  /// a given classification when creating or updating a retailer.
  ///
  /// Invariants:
  /// - `SALES` role can ONLY create shops with class `NEW`.
  /// - `OWNER` and `ADMIN` can assign any valid classification (`A`, `B`, `C`, `D`, `NEW`).
  static bool canRoleAssignClass({
    required String role,
    required String targetClass,
  }) {
    final r = role.trim().toUpperCase();
    final target = normalize(targetClass);

    if (r == 'SALES') {
      return target == classNew;
    }
    if (r == 'OWNER' || r == 'ADMIN') {
      return validClasses.contains(target);
    }
    return false;
  }

  /// Role-based access rule: determines whether a user role can assign credit limit.
  ///
  /// Invariants:
  /// - `SALES` role can only assign 0 credit limit.
  /// - `OWNER` and `ADMIN` can assign any non-negative credit limit.
  static bool canRoleAssignCredit({
    required String role,
    required int creditLimitPaise,
  }) {
    final r = role.trim().toUpperCase();
    if (creditLimitPaise < 0) return false;

    if (r == 'SALES') {
      return creditLimitPaise == 0;
    }
    if (r == 'OWNER' || r == 'ADMIN') {
      return true;
    }
    return false;
  }
}
