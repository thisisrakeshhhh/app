import 'package:flutter/material.dart';

/// Supported languages across RouteFlow mobile clients.
enum AppLanguage {
  en,
  hinglish,
  hi,
  gu,
}

extension AppLanguageExtension on AppLanguage {
  /// ISO/BCP47 language code / tag.
  String get code {
    switch (this) {
      case AppLanguage.en:
        return 'en';
      case AppLanguage.hinglish:
        return 'hinglish';
      case AppLanguage.hi:
        return 'hi';
      case AppLanguage.gu:
        return 'gu';
    }
  }

  /// Native script display name.
  String get nativeName {
    switch (this) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.hinglish:
        return 'Hinglish';
      case AppLanguage.hi:
        return 'हिन्दी';
      case AppLanguage.gu:
        return 'ગુજરાતી';
    }
  }

  /// English name for settings/debug display.
  String get englishName {
    switch (this) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.hinglish:
        return 'Hinglish (Hindi in Roman)';
      case AppLanguage.hi:
        return 'Hindi (Devanagari)';
      case AppLanguage.gu:
        return 'Gujarati (Gujarati script)';
    }
  }

  /// Flutter [Locale] representation.
  Locale get locale {
    switch (this) {
      case AppLanguage.en:
        return const Locale('en', 'US');
      case AppLanguage.hinglish:
        // Hinglish: Hindi language written in Latin script
        return const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn');
      case AppLanguage.hi:
        return const Locale('hi', 'IN');
      case AppLanguage.gu:
        return const Locale('gu', 'IN');
    }
  }

  /// True if the script is Indic (Devanagari or Gujarati), requiring taller line-height.
  bool get isIndic => this == AppLanguage.hi || this == AppLanguage.gu;

  /// Line height recommended to prevent clipping of matras and diacritics.
  double get lineHeight => isIndic ? 1.4 : 1.2;

  /// Parse from code string, defaulting to Hinglish for sales reps.
  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.hinglish;
    final lower = code.toLowerCase().trim();
    if (lower == 'en' || lower == 'english') return AppLanguage.en;
    if (lower == 'hi' || lower == 'hindi') return AppLanguage.hi;
    if (lower == 'gu' || lower == 'gujarati') return AppLanguage.gu;
    return AppLanguage.hinglish;
  }
}
