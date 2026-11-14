/// Utility for Indian mobile number normalization, validation, and formatting
/// compliant with the Telecom Regulatory Authority of India (TRAI) National Numbering Plan.
class PhoneSanitizer {
  PhoneSanitizer._();

  /// Canonicalizes raw phone input by stripping non-digit characters and
  /// trimming common Indian dialing prefixes (+91, 91, leading 0, 910).
  static String canonicalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');

    // Handle +910 or 910 prefix (13 digits: 91 + 0 + 10-digit mobile)
    if (digits.startsWith('910') && digits.length == 13) {
      digits = digits.substring(3);
    }
    // Handle +91 or 91 country code prefix (12 digits: 91 + 10-digit mobile)
    else if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    // Handle leading 0 trunk prefix (11 digits: 0 + 10-digit mobile)
    else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    return digits;
  }

  /// Normalizes an input string to a valid 10-digit Indian mobile number.
  ///
  /// Returns a clean 10-digit string if valid (length == 10 and starts with 6, 7, 8, or 9).
  /// Returns `null` if the input is null, empty, or cannot be resolved to a valid Indian mobile.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final digits = canonicalize(trimmed);

    if (digits.length == 10 && _isValidIndianMobileStart(digits)) {
      return digits;
    }
    return null;
  }

  /// Checks if the first digit of a 10-digit mobile number matches the TRAI
  /// allocation for mobile services (6, 7, 8, or 9).
  static bool _isValidIndianMobileStart(String tenDigitNumber) {
    if (tenDigitNumber.isEmpty) return false;
    final firstChar = tenDigitNumber[0];
    return firstChar == '6' || firstChar == '7' || firstChar == '8' || firstChar == '9';
  }

  /// Returns `true` if [raw] is or can be normalized to a valid 10-digit Indian mobile number.
  static bool isValidIndianMobile(String? raw) {
    return normalize(raw) != null;
  }

  /// Validates [raw] and returns `null` if valid, or a human-readable error message.
  static String? validateIndianMobile(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Mobile number is required';
    }

    final digits = canonicalize(raw.trim());

    if (digits.length < 10) {
      return 'Mobile number must be at least 10 digits';
    }

    if (digits.length > 10) {
      return 'Mobile number cannot exceed 10 digits (excluding country code)';
    }

    if (!_isValidIndianMobileStart(digits)) {
      return 'Indian mobile numbers must start with 6, 7, 8, or 9';
    }

    return null; // Valid
  }

  /// Formats a phone number for display with country code (+91 XXXXX XXXXX).
  /// If the number cannot be normalized, returns the raw input trimmed.
  static String formatDisplay(String? raw) {
    final norm = normalize(raw);
    if (norm == null) return raw?.trim() ?? '';
    return '+91 ${norm.substring(0, 5)} ${norm.substring(5)}';
  }

  /// Formats a phone number in national 10-digit format with a space (XXXXX XXXXX).
  static String formatNational(String? raw) {
    final norm = normalize(raw);
    if (norm == null) return raw?.trim() ?? '';
    return '${norm.substring(0, 5)} ${norm.substring(5)}';
  }

  /// Formats a phone number in standard E.164 format (+91XXXXXXXXXX).
  static String formatE164(String? raw) {
    final norm = normalize(raw);
    if (norm == null) return raw?.trim() ?? '';
    return '+91$norm';
  }
}
