import 'package:flutter/material.dart';
import 'app_language.dart';

/// Storage contract for persisting language preference per user and device.
abstract class LanguageStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// In-memory storage adapter for testing and default fallback.
class InMemoryLanguageStorage implements LanguageStorageAdapter {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }
}

/// Controller managing active application language with instant reactive updates.
class LanguageController extends ChangeNotifier {
  static LanguageController? _instance;
  static LanguageController get instance => _instance ??= LanguageController();

  final LanguageStorageAdapter _storage;
  AppLanguage _currentLanguage;
  String? _currentUserId;

  LanguageController({
    LanguageStorageAdapter? storage,
    AppLanguage initialLanguage = AppLanguage.hinglish,
  })  : _storage = storage ?? InMemoryLanguageStorage(),
        _currentLanguage = initialLanguage;

  @visibleForTesting
  static void resetInstanceForTesting([LanguageController? newInstance]) {
    _instance = newInstance;
  }

  AppLanguage get currentLanguage => _currentLanguage;
  Locale get currentLocale => _currentLanguage.locale;
  String? get currentUserId => _currentUserId;

  /// Build storage key isolated per user and fallback to device.
  String _storageKey(String? userId) {
    final uid = (userId ?? _currentUserId ?? 'device').trim();
    return 'sales_language_choice_$uid';
  }

  /// Load persisted language choice for a specific user ID or device.
  Future<void> loadSavedLanguage({String? userId}) async {
    _currentUserId = userId;
    final key = _storageKey(userId);
    final savedCode = await _storage.read(key);
    if (savedCode != null && savedCode.isNotEmpty) {
      _currentLanguage = AppLanguageExtension.fromCode(savedCode);
    } else {
      // Default is Hinglish for new sales users
      _currentLanguage = AppLanguage.hinglish;
    }
    notifyListeners();
  }

  /// Switch the active language instantly and persist the preference.
  Future<void> setLanguage(AppLanguage language, {String? userId}) async {
    if (userId != null) _currentUserId = userId;
    _currentLanguage = language;
    final key = _storageKey(userId);
    await _storage.write(key, language.code);
    notifyListeners();
  }
}

/// Inherited widget for providing [LanguageController] down the widget tree.
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    return scope?.notifier ?? LanguageController.instance;
  }
}
