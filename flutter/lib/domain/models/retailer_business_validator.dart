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

  /// Alphanumeric code table for Indian GSTIN Luhn Modulo-36 check-digit algorithm.
  static const String _base36Chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Validates whether [gstin] conforms to the standard 15-character GSTIN structure (regex).
  static bool isValidGstinStructure(String? gstin) {
    if (gstin == null) return false;
    final clean = gstin.trim().toUpperCase();
    return clean.length == 15 && gstinRegex.hasMatch(clean);
  }

  /// Computes the 15th check digit for a 14-character GSTIN prefix using the
  /// official GSTN Luhn Modulo-36 algorithm.
  ///
  /// Returns null if the prefix is not 14 characters or contains characters outside [0-9A-Z].
  static String? computeGstinCheckDigit(String gstin14) {
    final clean = gstin14.trim().toUpperCase();
    if (clean.length != 14) return null;

    var sum = 0;
    for (var i = 0; i < 14; i++) {
      final cp = _base36Chars.indexOf(clean[i]);
      if (cp == -1) return null;

      // Alternating weight factor: 1 for even index (0, 2, 4...), 2 for odd index (1, 3, 5...)
      final factor = (i % 2 == 0) ? 1 : 2;
      final product = cp * factor;

      // Hash: quotient + remainder upon dividing by 36
      final quotient = product ~/ 36;
      final remainder = product % 36;
      sum += quotient + remainder;
    }

    final checkCode = (36 - (sum % 36)) % 36;
    return _base36Chars[checkCode];
  }

  /// Verifies whether the 15th character of [gstin] matches the official GSTN
  /// Luhn Modulo-36 checksum calculation.
  static bool isValidGstinChecksum(String? gstin) {
    if (gstin == null) return false;
    final clean = gstin.trim().toUpperCase();
    if (clean.length != 15) return false;

    final expectedCheckDigit = computeGstinCheckDigit(clean.substring(0, 14));
    if (expectedCheckDigit == null) return false;

    return clean[14] == expectedCheckDigit;
  }

  /// Validates [gstin]. By default checks structural conformance.
  /// When [verifyChecksum] is `true`, also validates the Modulo-36 check digit.
  static bool isValidGstin(String? gstin, {bool verifyChecksum = false}) {
    if (!isValidGstinStructure(gstin)) return false;
    if (verifyChecksum) {
      return isValidGstinChecksum(gstin);
    }
    return true;
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
  /// For example, GSTIN `27AAPFU0939F1ZV` -> PAN `AAPFU0939F`.
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
