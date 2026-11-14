/// Validator for Indian statutory business identifiers:
/// - Goods and Services Tax Identification Number (GSTIN)
/// - Permanent Account Number (PAN)
/// - Postal Index Number (PIN Code)
class RetailerBusinessValidator {
  RetailerBusinessValidator._();

  /// Standard 15-character Indian GSTIN pattern:
  /// - 2 digits state code (01-37, etc.)
  /// - 10 alphanumeric PAN
  /// - 1 entity number (1-9, A-Z)
  /// - 'Z' default alphabet
  /// - 1 checksum digit/char
  static final RegExp gstinRegex = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );

  /// Standard 10-character Indian PAN pattern:
  /// - 5 uppercase letters (first 3 alphabetic series, 4th status, 5th name)
  /// - 4 numeric digits
  /// - 1 uppercase letter
  static final RegExp panRegex = RegExp(
    r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
  );

  /// Standard 6-digit Indian Postal PIN code pattern:
  /// - First digit 1-9 (never 0)
  /// - 5 digits 0-9
  static final RegExp pincodeRegex = RegExp(
    r'^[1-9][0-9]{5}$',
  );

  /// Validates whether [gstin] conforms to the standard 15-character GSTIN structure.
  static bool isValidGstin(String? gstin) {
    if (gstin == null) return false;
    final clean = gstin.trim().toUpperCase();
    return clean.length == 15 && gstinRegex.hasMatch(clean);
  }

  /// Normalizes GSTIN to uppercase trimmed string, or `null` if empty.
  static String? normalizeGstin(String? gstin) {
    if (gstin == null) return null;
    final clean = gstin.trim().toUpperCase();
    return clean.isEmpty ? null : clean;
  }

  /// Validates whether [pan] conforms to the standard 10-character PAN structure.
  static bool isValidPan(String? pan) {
    if (pan == null) return false;
    final clean = pan.trim().toUpperCase();
    return clean.length == 10 && panRegex.hasMatch(clean);
  }

  /// Normalizes PAN to uppercase trimmed string, or `null` if empty.
  static String? normalizePan(String? pan) {
    if (pan == null) return null;
    final clean = pan.trim().toUpperCase();
    return clean.isEmpty ? null : clean;
  }

  /// Derives the 10-character PAN from a 15-character GSTIN (characters 3 through 12).
  ///
  /// For example, GSTIN `08AAACH1234F1Z5` -> PAN `AAACH1234F`.
  static String? extractPanFromGstin(String? gstin) {
    if (gstin == null) return null;
    final clean = gstin.trim().toUpperCase();
    if (clean.length == 15) {
      final pan = clean.substring(2, 12);
      if (isValidPan(pan)) {
        return pan;
      }
    }
    return null;
  }

  /// Resolves the effective PAN: prefers explicit valid [pan], falls back to extracting from [gstin].
  static String? resolvePan({String? pan, String? gstin}) {
    final cleanPan = normalizePan(pan);
    if (cleanPan != null && isValidPan(cleanPan)) {
      return cleanPan;
    }
    return extractPanFromGstin(gstin);
  }

  /// Validates whether [pincode] is a valid 6-digit Indian postal code.
  static bool isValidPincode(String? pincode) {
    if (pincode == null) return false;
    final clean = pincode.trim();
    return clean.length == 6 && pincodeRegex.hasMatch(clean);
  }
}
