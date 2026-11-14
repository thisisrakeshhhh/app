/// Domain model representing Retailer Classification and Beat Scheduling in FMCG distribution.
///
/// Canonical Classification Tiers:
/// - `A`: Top retail / supermarket. High volume, daily beat frequency.
/// - `B`: Standard busy kirana store. Medium volume, alternate days beat frequency.
/// - `C`: Small kirana / tea stall / paan shop. Low volume, twice-weekly beat frequency.
/// - `D`: High credit risk / defaulter. Weekly beat frequency (Strictly Cash Only).
/// - `NEW`: Newly onboarded shop pending owner verification (Cash Only).
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

  /// Baseline default credit limit in paise for each classification tier.
  ///
  /// NOTE: This is a configurable baseline guideline (from distributor class settings),
  /// NOT a fixed universal business rule. An individual retailer's stored negotiated
  /// credit limit takes precedence and is NEVER overwritten by baseline defaults.
  static int defaultCreditLimitPaise(String? raw) {
    return RetailerCreditPolicy.getBaselinePolicy(raw).baselineCreditLimitPaise;
  }

  /// Baseline default credit payment terms in days.
  ///
  /// NOTE: An individual retailer's negotiated payment terms take precedence.
  static int defaultCreditDays(String? raw) {
    return RetailerCreditPolicy.getBaselinePolicy(raw).baselineCreditDays;
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

/// Represents distributor-configurable baseline credit policy guidelines.
///
/// These represent initial default templates that can be configured by distributor
/// management (OWNER/ADMIN) via class settings. They do NOT override or overwrite
/// an individual retailer's explicitly negotiated credit limit or payment terms.
class RetailerCreditPolicy {
  final int baselineCreditLimitPaise;
  final int baselineCreditDays;

  const RetailerCreditPolicy({
    required this.baselineCreditLimitPaise,
    required this.baselineCreditDays,
  });

  /// Baseline guidelines per class tier.
  static RetailerCreditPolicy getBaselinePolicy(String? classType) {
    switch (RetailerClassification.normalize(classType)) {
      case RetailerClassification.classA:
        return const RetailerCreditPolicy(
          baselineCreditLimitPaise: 5000000, // ₹50,000 baseline guideline
          baselineCreditDays: 14,
        );
      case RetailerClassification.classB:
        return const RetailerCreditPolicy(
          baselineCreditLimitPaise: 2500000, // ₹25,000 baseline guideline
          baselineCreditDays: 7,
        );
      case RetailerClassification.classC:
        return const RetailerCreditPolicy(
          baselineCreditLimitPaise: 1000000, // ₹10,000 baseline guideline
          baselineCreditDays: 3,
        );
      case RetailerClassification.classD:
      case RetailerClassification.classNew:
      default:
        return const RetailerCreditPolicy(
          baselineCreditLimitPaise: 0, // Strictly cash on delivery
          baselineCreditDays: 0,
        );
    }
  }
}
