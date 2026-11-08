import 'package:flutter/material.dart';
import 'app_language.dart';
import 'language_controller.dart';

/// Centralized localization dictionary for RouteFlow.
///
/// Supports 4 languages:
/// 1. English (en)
/// 2. Hinglish (hi-Latn: Hindi written in Roman script)
/// 3. Hindi (hi: Devanagari script)
/// 4. Gujarati (gu: Gujarati script)
class AppStrings {
  final AppLanguage language;

  AppStrings([AppLanguage? language])
      : language = language ?? LanguageController.instance.currentLanguage;

  /// Retrieve localized strings bound to the active [LanguageScope] or global controller.
  static AppStrings of([BuildContext? context]) {
    if (context != null) {
      final controller = LanguageScope.of(context);
      return AppStrings(controller.currentLanguage);
    }
    return AppStrings(LanguageController.instance.currentLanguage);
  }

  /// Legacy compatibility flag.
  static bool get isHindi => LanguageController.instance.currentLanguage == AppLanguage.hi;
  static set isHindi(bool value) {
    LanguageController.instance.setLanguage(value ? AppLanguage.hi : AppLanguage.en);
  }

  /// Active language accessor.
  static AppLanguage get activeLanguage => LanguageController.instance.currentLanguage;
  static set activeLanguage(AppLanguage lang) {
    LanguageController.instance.setLanguage(lang);
  }

  /// Translate a key with optional named parameter interpolation `{name}`.
  /// Falls back to English if the translation is missing for the active language.
  /// Never displays the raw key unless no translation exists at all.
  String t(String key, [Map<String, dynamic>? params]) {
    final langMap = _translations[key];
    String? text;
    if (langMap != null) {
      text = langMap[language] ?? langMap[AppLanguage.en];
    }
    text ??= key;

    if (params != null && params.isNotEmpty) {
      params.forEach((placeholder, value) {
        text = text!.replaceAll('{$placeholder}', value.toString());
      });
    }
    return text!;
  }

  /// Static shortcut for string translation without widget context.
  static String tr(String key, [Map<String, dynamic>? params]) {
    return of().t(key, params);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NUMBER & CURRENCY FORMATTING (Indian grouping, Latin digits only)
  // ──────────────────────────────────────────────────────────────────────────

  /// Formats an amount in paise to Indian grouped rupees with Latin digits (e.g. ₹1,42,800).
  static String formatPaise(int paise, {bool includeSymbol = true}) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupees = absPaise ~/ 100;
    final paiseRemainder = absPaise % 100;

    final rupeesStr = rupees.toString();
    String formattedRupees;
    if (rupeesStr.length <= 3) {
      formattedRupees = rupeesStr;
    } else {
      final lastThree = rupeesStr.substring(rupeesStr.length - 3);
      final remaining = rupeesStr.substring(0, rupeesStr.length - 3);
      final buffer = StringBuffer();
      for (int i = 0; i < remaining.length; i++) {
        if (i > 0 && (remaining.length - i) % 2 == 0) {
          buffer.write(',');
        }
        buffer.write(remaining[i]);
      }
      formattedRupees = '$buffer,$lastThree';
    }

    final sign = isNegative ? '-' : '';
    final symbol = includeSymbol ? '₹' : '';
    if (paiseRemainder > 0) {
      return '$sign$symbol$formattedRupees.${paiseRemainder.toString().padLeft(2, '0')}';
    }
    return '$sign$symbol$formattedRupees';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BACKWARD COMPATIBLE GETTERS (Preserving existing screens across all roles)
  // ──────────────────────────────────────────────────────────────────────────
  static String get save => tr('save');
  static String get cancel => tr('cancel');
  static String get close => tr('close');
  static String get retry => tr('retry');
  static String get continueLabel => tr('continue_label');

  // Pillar A: Add Shop
  static String get addShopTitle => tr('add_shop_title');
  static String get quickAddSubtitle => tr('quick_add_subtitle');
  static String get shopNameLabel => tr('shop_name_label');
  static String get shopNameHint => tr('shop_name_hint');
  static String get ownerNameLabel => tr('owner_name_label');
  static String get ownerNameHint => tr('owner_name_hint');
  static String get mobileLabel => tr('mobile_label');
  static String get mobileHint => tr('mobile_hint');
  static String get routeLabel => tr('route_label');
  static String get captureGpsButton => tr('capture_gps_button');
  static String get locationNotCaptured => tr('location_not_captured');
  static String locationAccuracy(double m) => tr('location_accuracy', {'meters': m.toStringAsFixed(0)});

  // Optional Shop Details
  static String get moreDetails => tr('more_details');
  static String get addressLabel => tr('address_label');
  static String get landmarkLabel => tr('landmark_label');
  static String get pincodeLabel => tr('pincode_label');
  static String get gstinLabel => tr('gstin_label');
  static String get saveShopButton => tr('save_shop_button');

  // Classification
  static String get classNew => tr('class_new');
  static String get classA => tr('class_a');
  static String get classB => tr('class_b');
  static String get classC => tr('class_c');
  static String get classD => tr('class_d');
  static String get cashOnlyWarning => tr('cash_only_warning');

  // Duplicate Detection
  static String get duplicateWarningTitle => tr('duplicate_warning_title');
  static String get openExistingShop => tr('open_existing_shop');
  static String get differentShopConfirm => tr('different_shop_confirm');

  // Sync & Storage Honesty (Legacy getters preserve exact pre-existing strings for other roles)
  static String get savedOnPhone => isHindi ? 'फोन पर सुरक्षित (लोकल)' : tr('saved_on_phone');
  static String get waitingToSync => tr('waiting_to_sync');
  static String get localOnlyMode => tr('local_only_mode');
  static String get syncStatusTitle => tr('sync_status_title');
  static String get savedOnPhoneOutbox => isHindi ? 'फोन पर सुरक्षित (ऑफलाइन आउटबॉक्स)' : tr('saved_on_phone_outbox');
  static String get uploadingToCloud => tr('uploading_to_cloud');
  static String get syncedToCloud => tr('synced_to_cloud');
  static String get syncWorkerNote => tr('sync_worker_note');
  static String pendingMutationsCount(int count) => tr('pending_mutations_count', {'count': count});
  static String get bookedOnDevice => tr('booked_on_device');
  static String get savedInLocalOutbox => tr('saved_in_local_outbox');
  static String get cloudSync => tr('cloud_sync');
  static String get pendingUploadCloudflare => tr('pending_upload_cloudflare');
  static String get auditTimeline => tr('audit_timeline');

  // Pillar C: Inventory & GRN
  static String get receiveStock => tr('receive_stock');
  static String get godownCartons => tr('godown_cartons');
  static String get loosePieces => tr('loose_pieces');
  static String get damagedStock => tr('damaged_stock');
  static String get invoiceNumber => tr('invoice_number');
  static String get supplierName => tr('supplier_name');

  // Pillar B & Units: Sales & Packaging
  static String get salesOrder => tr('sales_order');
  static String get unitPiece => tr('unit_piece');
  static String get unitStrip => tr('unit_strip');
  static String get unitBox => tr('unit_box');
  static String get cartDraftSaved => tr('cart_draft_saved');
  static String get noOrderRecorded => tr('no_order_recorded');
  static String get creditLimitExceeded => tr('credit_limit_exceeded');

  // Validation Errors
  static String get shopNameRequired => tr('shop_name_required');
  static String get ownerNameRequired => tr('owner_name_required');
  static String get validMobileRequired => tr('valid_mobile_required');

  // Product & Catalog UX
  static String get noOrdersBeatPrompt => tr('no_orders_beat_prompt');
  static String get productNameExample => tr('product_name_example');
  static String get productLocalNameExample => tr('product_local_name_example');
  static String get searchProductsHint => tr('search_products_hint');

  // ──────────────────────────────────────────────────────────────────────────
  // FOUR-LANGUAGE DICTIONARY
  // ──────────────────────────────────────────────────────────────────────────
  static const Map<String, Map<AppLanguage, String>> _translations = {
    // === 1. GLOSSARY TABLE (Prompt Section 4.1 Specification) ===
    'today': {
      AppLanguage.en: 'Today',
      AppLanguage.hinglish: 'Aaj',
      AppLanguage.hi: 'आज',
      AppLanguage.gu: 'આજ',
    },
    'shop': {
      AppLanguage.en: 'Shop',
      AppLanguage.hinglish: 'Dukaan',
      AppLanguage.hi: 'दुकान',
      AppLanguage.gu: 'દુકાન',
    },
    'order': {
      AppLanguage.en: 'Order',
      AppLanguage.hinglish: 'Order',
      AppLanguage.hi: 'ऑर्डर',
      AppLanguage.gu: 'ઓર્ડર',
    },
    'box': {
      AppLanguage.en: 'Box',
      AppLanguage.hinglish: 'Peti',
      AppLanguage.hi: 'पेटी',
      AppLanguage.gu: 'પેટી',
    },
    'piece': {
      AppLanguage.en: 'Piece',
      AppLanguage.hinglish: 'Nag',
      AppLanguage.hi: 'नग',
      AppLanguage.gu: 'નંગ',
    },
    'strip': {
      AppLanguage.en: 'Strip',
      AppLanguage.hinglish: 'Strip',
      AppLanguage.hi: 'स्ट्रिप',
      AppLanguage.gu: 'સ્ટ્રિપ',
    },
    'stock': {
      AppLanguage.en: 'Stock',
      AppLanguage.hinglish: 'Maal',
      AppLanguage.hi: 'माल',
      AppLanguage.gu: 'માલ',
    },
    'due': {
      AppLanguage.en: 'Due',
      AppLanguage.hinglish: 'Baaki',
      AppLanguage.hi: 'बाकी',
      AppLanguage.gu: 'બાકી',
    },
    'credit': {
      AppLanguage.en: 'Credit',
      AppLanguage.hinglish: 'Udhaar',
      AppLanguage.hi: 'उधार',
      AppLanguage.gu: 'ઉધાર',
    },
    'account': {
      AppLanguage.en: 'Account',
      AppLanguage.hinglish: 'Hisaab',
      AppLanguage.hi: 'हिसाब',
      AppLanguage.gu: 'હિસાબ',
    },
    'collection': {
      AppLanguage.en: 'Collection',
      AppLanguage.hinglish: 'Vasooli',
      AppLanguage.hi: 'वसूली',
      AppLanguage.gu: 'ઉઘરાણી',
    },
    'cash': {
      AppLanguage.en: 'Cash',
      AppLanguage.hinglish: 'Nakad',
      AppLanguage.hi: 'नकद',
      AppLanguage.gu: 'રોકડા',
    },
    'cheque': {
      AppLanguage.en: 'Cheque',
      AppLanguage.hinglish: 'Cheque',
      AppLanguage.hi: 'चेक',
      AppLanguage.gu: 'ચેક',
    },
    'scheme': {
      AppLanguage.en: 'Scheme',
      AppLanguage.hinglish: 'Scheme',
      AppLanguage.hi: 'स्कीम',
      AppLanguage.gu: 'સ્કીમ',
    },
    'discount': {
      AppLanguage.en: 'Discount',
      AppLanguage.hinglish: 'Chhoot',
      AppLanguage.hi: 'छूट',
      AppLanguage.gu: 'છૂટ',
    },
    'route': {
      AppLanguage.en: 'Route',
      AppLanguage.hinglish: 'Route',
      AppLanguage.hi: 'रूट',
      AppLanguage.gu: 'રૂટ',
    },
    'saved_on_phone': {
      AppLanguage.en: 'Saved on this phone',
      AppLanguage.hinglish: 'Phone me save hua',
      AppLanguage.hi: 'फ़ोन में सेव हुआ',
      AppLanguage.gu: 'ફોનમાં સેવ થયું',
    },

    // === 2. GENERAL ACTIONS & NAVIGATION ===
    'save': {
      AppLanguage.en: 'Save',
      AppLanguage.hinglish: 'Save karein',
      AppLanguage.hi: 'सुरक्षित करें',
      AppLanguage.gu: 'સાચવો',
    },
    'cancel': {
      AppLanguage.en: 'Cancel',
      AppLanguage.hinglish: 'Cancel',
      AppLanguage.hi: 'रद्द करें',
      AppLanguage.gu: 'રદ કરો',
    },
    'close': {
      AppLanguage.en: 'Close',
      AppLanguage.hinglish: 'Band karein',
      AppLanguage.hi: 'बंद करें',
      AppLanguage.gu: 'બંધ કરો',
    },
    'retry': {
      AppLanguage.en: 'Retry',
      AppLanguage.hinglish: 'Dobara koshish karein',
      AppLanguage.hi: 'पुनः प्रयास करें',
      AppLanguage.gu: 'ફરી પ્રયાસ કરો',
    },
    'continue_label': {
      AppLanguage.en: 'Continue',
      AppLanguage.hinglish: 'Aage badhein',
      AppLanguage.hi: 'आगे बढ़ें',
      AppLanguage.gu: 'આગળ વધો',
    },
    'today_assigned_beat': {
      AppLanguage.en: "TODAY'S ASSIGNED BEAT",
      AppLanguage.hinglish: 'AAJ KA ASSIGNED BEAT',
      AppLanguage.hi: 'आज का निर्धारित बीट',
      AppLanguage.gu: 'આજનો સોંપાયેલ બીટ',
    },
    'shops_assigned': {
      AppLanguage.en: '{count} Shops Assigned',
      AppLanguage.hinglish: '{count} Dukaanein Assigned',
      AppLanguage.hi: '{count} दुकानें निर्धारित',
      AppLanguage.gu: '{count} દુકાનો સોંપાયેલ',
    },
    'continue_route': {
      AppLanguage.en: 'Continue Route',
      AppLanguage.hinglish: 'Route Chalu Karein',
      AppLanguage.hi: 'रूट शुरू करें',
      AppLanguage.gu: 'રૂટ ચાલુ કરો',
    },
    'route_map': {
      AppLanguage.en: 'Route Map',
      AppLanguage.hinglish: 'Route Map',
      AppLanguage.hi: 'रूट मैप',
      AppLanguage.gu: 'રૂટ નકશો',
    },
    'performance_on_phone': {
      AppLanguage.en: 'Performance (On this phone)',
      AppLanguage.hinglish: 'Performance (Is phone par)',
      AppLanguage.hi: 'प्रदर्शन (इस फ़ोन पर)',
      AppLanguage.gu: 'પ્રદર્શન (આ ફોન પર)',
    },
    'timeframe_today': {
      AppLanguage.en: 'Today',
      AppLanguage.hinglish: 'Aaj',
      AppLanguage.hi: 'आज',
      AppLanguage.gu: 'આજે',
    },
    'timeframe_week': {
      AppLanguage.en: 'This Week',
      AppLanguage.hinglish: 'Is Hafte',
      AppLanguage.hi: 'इस हफ्ते',
      AppLanguage.gu: 'આ અઠવાડિયે',
    },
    'timeframe_month': {
      AppLanguage.en: 'This Month',
      AppLanguage.hinglish: 'Is Mahine',
      AppLanguage.hi: 'इस महीने',
      AppLanguage.gu: 'આ મહિને',
    },
    'timeframe_year': {
      AppLanguage.en: 'This Year',
      AppLanguage.hinglish: 'Is Saal',
      AppLanguage.hi: 'इस साल',
      AppLanguage.gu: 'આ વર્ષે',
    },
    'timeframe_all': {
      AppLanguage.en: 'Till Join',
      AppLanguage.hinglish: 'Shuruat Se',
      AppLanguage.hi: 'शुरुआत से',
      AppLanguage.gu: 'શરૂઆતથી',
    },
    'booked_orders': {
      AppLanguage.en: 'Booked Orders',
      AppLanguage.hinglish: 'Book Hue Orders',
      AppLanguage.hi: 'बुक किए गए ऑर्डर',
      AppLanguage.gu: 'બુક થયેલ ઓર્ડર',
    },
    'beat_coverage': {
      AppLanguage.en: 'Beat Coverage',
      AppLanguage.hinglish: 'Beat Coverage',
      AppLanguage.hi: 'बीट कवरेज',
      AppLanguage.gu: 'બીટ કવરેજ',
    },
    'aov_title': {
      AppLanguage.en: 'Avg Order Value (AOV)',
      AppLanguage.hinglish: 'Ausat Order Value (AOV)',
      AppLanguage.hi: 'औसत ऑर्डर मूल्य (AOV)',
      AppLanguage.gu: 'સરેરાશ ઓર્ડર મૂલ્ય',
    },
    'efficiency_strike': {
      AppLanguage.en: 'Efficiency Strike',
      AppLanguage.hinglish: 'Efficiency Strike',
      AppLanguage.hi: 'दक्षता स्ट्राइक',
      AppLanguage.gu: 'કાર્યક્ષમતા સ્ટ્રાઇક',
    },
    'next_scheduled_visit': {
      AppLanguage.en: 'NEXT SCHEDULED VISIT',
      AppLanguage.hinglish: 'AGLI SCHEDULED VISIT',
      AppLanguage.hi: 'अगली निर्धारित विज़िट',
      AppLanguage.gu: 'આગલી મુલાકાત',
    },
    'check_in': {
      AppLanguage.en: 'Check In',
      AppLanguage.hinglish: 'Check In',
      AppLanguage.hi: 'चेक-इन',
      AppLanguage.gu: 'ચેક-ઇન',
    },
    'live_timer': {
      AppLanguage.en: 'LIVE TIMER',
      AppLanguage.hinglish: 'LIVE TIMER',
      AppLanguage.hi: 'लाइव टाइमर',
      AppLanguage.gu: 'લાઇવ ટાઈમર',
    },
    'time_spent': {
      AppLanguage.en: 'Time Spent',
      AppLanguage.hinglish: 'Samay Lagaya',
      AppLanguage.hi: 'समय व्यतीत',
      AppLanguage.gu: 'ખર્ચેલ સમય',
    },
    'nav_home': {
      AppLanguage.en: 'Home',
      AppLanguage.hinglish: 'Home',
      AppLanguage.hi: 'होम',
      AppLanguage.gu: 'હોમ',
    },
    'nav_new_order': {
      AppLanguage.en: 'New Order',
      AppLanguage.hinglish: 'Naya Order',
      AppLanguage.hi: 'नया ऑर्डर',
      AppLanguage.gu: 'નવો ઓર્ડર',
    },
    'nav_retailers': {
      AppLanguage.en: 'Retailers',
      AppLanguage.hinglish: 'Dukaanein',
      AppLanguage.hi: 'दुकानें',
      AppLanguage.gu: 'દુકાનો',
    },
    'nav_products': {
      AppLanguage.en: 'Products',
      AppLanguage.hinglish: 'Items',
      AppLanguage.hi: 'उत्पाद',
      AppLanguage.gu: 'પ્રોડક્ટ્સ',
    },
    'nav_my_visits': {
      AppLanguage.en: 'My Visits',
      AppLanguage.hinglish: 'Mera Daura',
      AppLanguage.hi: 'मेरी विज़िट',
      AppLanguage.gu: 'મારી મુલાકાતો',
    },
    'all': {
      AppLanguage.en: 'All',
      AppLanguage.hinglish: 'Sabhi',
      AppLanguage.hi: 'सभी',
      AppLanguage.gu: 'બધા',
    },
    'pending': {
      AppLanguage.en: 'Pending',
      AppLanguage.hinglish: 'Baaki',
      AppLanguage.hi: 'बाकी',
      AppLanguage.gu: 'બાકી',
    },
    'visited': {
      AppLanguage.en: 'Visited',
      AppLanguage.hinglish: 'Visit kiya',
      AppLanguage.hi: 'दौरा पूर्ण',
      AppLanguage.gu: 'મુલાકાત પૂર્ણ',
    },
    'active_visit': {
      AppLanguage.en: 'Active Visit',
      AppLanguage.hinglish: 'Chalu visit',
      AppLanguage.hi: 'चालू दौरा',
      AppLanguage.gu: 'ચાલુ મુલાકાત',
    },
    'route_sketch': {
      AppLanguage.en: 'Route sketch (not to scale)',
      AppLanguage.hinglish: 'Route sketch (not to scale)',
      AppLanguage.hi: 'रूट स्केच (माप पर नहीं)',
      AppLanguage.gu: 'રૂટ સ્કેચ (માપ પર નહીં)',
    },
    'search_shops': {
      AppLanguage.en: 'Search shops or area...',
      AppLanguage.hinglish: 'Dukaan ya area khojein...',
      AppLanguage.hi: 'दुकान या क्षेत्र खोजें...',
      AppLanguage.gu: 'દુકાન અથવા વિસ્તાર શોધો...',
    },
    'shops': {
      AppLanguage.en: 'Shops',
      AppLanguage.hinglish: 'Dukaanein',
      AppLanguage.hi: 'दुकानें',
      AppLanguage.gu: 'દુકાનો',
    },
    'cart': {
      AppLanguage.en: 'Cart',
      AppLanguage.hinglish: 'Cart',
      AppLanguage.hi: 'कार्ट',
      AppLanguage.gu: 'કાર્ટ',
    },
    'earn': {
      AppLanguage.en: 'Earn',
      AppLanguage.hinglish: 'Kamai',
      AppLanguage.hi: 'कमाई',
      AppLanguage.gu: 'કમાણી',
    },
    'more': {
      AppLanguage.en: 'More',
      AppLanguage.hinglish: 'Aur',
      AppLanguage.hi: 'और',
      AppLanguage.gu: 'વધુ',
    },
    'language': {
      AppLanguage.en: 'Language',
      AppLanguage.hinglish: 'Bhasha',
      AppLanguage.hi: 'भाषा',
      AppLanguage.gu: 'ભાષા',
    },
    'choose_language': {
      AppLanguage.en: 'Choose Language',
      AppLanguage.hinglish: 'Bhasha chunein',
      AppLanguage.hi: 'भाषा चुनें',
      AppLanguage.gu: 'ભાષા પસંદ કરો',
    },
    'choose_language_subtitle': {
      AppLanguage.en: 'Choose your preferred language for the app',
      AppLanguage.hinglish: 'App ke liye apni pasandida bhasha chunein',
      AppLanguage.hi: 'ऐप के लिए अपनी पसंदीदा भाषा चुनें',
      AppLanguage.gu: 'ઍપ માટે તમારી પસંદગીની ભાષા પસંદ કરો',
    },

    // === 3. HONEST DATA & USER WORDING (Questions 4, 5, 6) ===
    'extra_visit_added': {
      AppLanguage.en: 'Added {name} for today only, not on permanent route.',
      AppLanguage.hinglish: '{name} aaj ke liye add kiya, kal nahi rahega.',
      AppLanguage.hi: '{name} आज के लिए जोड़ा, कल नहीं रहेगा।',
      AppLanguage.gu: '{name} આજના દિવસ માટે ઉમેર્યું, કાલે નહીં રહે.',
    },
    'extra_visit_removed': {
      AppLanguage.en: 'Removed {name} from today extra visits.',
      AppLanguage.hinglish: '{name} ko aaj ke extra visit se hataya.',
      AppLanguage.hi: '{name} को आज के अतिरिक्त दौरे से हटाया।',
      AppLanguage.gu: '{name} ને આજના વધારાના મુલાકાતમાંથી હટાવ્યું.',
    },
    'location_not_added': {
      AppLanguage.en: 'Location not added',
      AppLanguage.hinglish: 'Location nahi jodi gayi',
      AppLanguage.hi: 'लोकेशन नहीं जोड़ी गई',
      AppLanguage.gu: 'લોકેશન ઉમેરેલ નથી',
    },
    'add_location': {
      AppLanguage.en: 'Add location',
      AppLanguage.hinglish: 'Location jodo',
      AppLanguage.hi: 'लोकेशन जोड़ें',
      AppLanguage.gu: 'લોકેશન ઉમેરો',
    },
    'address_not_added': {
      AppLanguage.en: 'Address not added',
      AppLanguage.hinglish: 'Pata nahi joda gaya',
      AppLanguage.hi: 'पता नहीं जोड़ा गया',
      AppLanguage.gu: 'સરનામું ઉમેરેલ નથી',
    },
    'add_address': {
      AppLanguage.en: 'Add address',
      AppLanguage.hinglish: 'Pata jodo',
      AppLanguage.hi: 'पता जोड़ें',
      AppLanguage.gu: 'સરનામું ઉમેરો',
    },
    'target_not_set': {
      AppLanguage.en: 'Target not set by owner',
      AppLanguage.hinglish: 'Owner ne target set nahi kiya',
      AppLanguage.hi: 'मालिक द्वारा लक्ष्य तय नहीं किया गया',
      AppLanguage.gu: 'માલિક દ્વારા ટાર્ગેટ સેટ નથી થયો',
    },
    'estimated_earnings_note': {
      AppLanguage.en: 'Estimated earnings from orders booked on this phone. Final calculation by owner.',
      AppLanguage.hinglish: 'Is phone par book hue orders se andazan kamai. Final hisaab owner karenge.',
      AppLanguage.hi: 'इस फ़ोन पर बुक हुए ऑर्डर से अनुमानित कमाई। अंतिम हिसाब मालिक करेंगे।',
      AppLanguage.gu: 'આ ફોન પર બુક થયેલ ઓર્ડર પરથી અંદાજિત કમાણી. છેલ્લો હિસાબ માલિક કરશે.',
    },
    'request_saved_phone': {
      AppLanguage.en: 'Request saved on this phone',
      AppLanguage.hinglish: 'Request phone me save hui',
      AppLanguage.hi: 'अनुरोध फ़ोन में सेव हुआ',
      AppLanguage.gu: 'વિનંતી ફોનમાં સેવ થઈ',
    },
    'not_verified': {
      AppLanguage.en: 'Not verified',
      AppLanguage.hinglish: 'Verify nahi hua',
      AppLanguage.hi: 'सत्यापित नहीं',
      AppLanguage.gu: 'ચકાસાયેલ નથી',
    },
    'ask_owner': {
      AppLanguage.en: 'Ask Owner',
      AppLanguage.hinglish: 'Owner se puchho',
      AppLanguage.hi: 'मालिक से पूछें',
      AppLanguage.gu: 'માલિકને પૂછો',
    },
    'look_good': {
      AppLanguage.en: 'Looks good',
      AppLanguage.hinglish: 'Sahi hai',
      AppLanguage.hi: 'सही है',
      AppLanguage.gu: 'બરાબર છે',
    },
    'change_order': {
      AppLanguage.en: 'Change',
      AppLanguage.hinglish: 'Badlo',
      AppLanguage.hi: 'बदलें',
      AppLanguage.gu: 'બદલો',
    },

    // === 4. PILLAR A: SHOP ONBOARDING & DETAILS ===
    'add_shop_title': {
      AppLanguage.en: 'Add New Shop',
      AppLanguage.hinglish: 'Nayi dukaan jodo',
      AppLanguage.hi: 'नई दुकान जोड़ें',
      AppLanguage.gu: 'નવી દુકાન ઉમેરો',
    },
    'quick_add_subtitle': {
      AppLanguage.en: 'Quick-Add Shop (under 20s)',
      AppLanguage.hinglish: 'Jaldi dukaan jodo (20 second)',
      AppLanguage.hi: 'तुरंत दुकान जोड़ें (20 सेकंड)',
      AppLanguage.gu: 'ઝડપી દુકાન ઉમેરો (20 સેકન્ડ)',
    },
    'shop_name_label': {
      AppLanguage.en: 'Shop Name',
      AppLanguage.hinglish: 'Dukaan ka naam',
      AppLanguage.hi: 'दुकान का नाम',
      AppLanguage.gu: 'દુકાનનું નામ',
    },
    'shop_name_hint': {
      AppLanguage.en: 'e.g. Mahalaxmi Kirana',
      AppLanguage.hinglish: 'Jaise: Mahalaxmi Kirana',
      AppLanguage.hi: 'उदा. महालक्ष्मी किराना',
      AppLanguage.gu: 'દા.ત. મહાલક્ષ્મી કિરાણા',
    },
    'owner_name_label': {
      AppLanguage.en: 'Owner Name',
      AppLanguage.hinglish: 'Maalik ka naam',
      AppLanguage.hi: 'मालिक का नाम',
      AppLanguage.gu: 'માલિકનું નામ',
    },
    'owner_name_hint': {
      AppLanguage.en: 'e.g. Suresh Kumar',
      AppLanguage.hinglish: 'Jaise: Suresh Kumar',
      AppLanguage.hi: 'उदा. सुरेश कुमार',
      AppLanguage.gu: 'દા.ત. સુરેશ કુમાર',
    },
    'mobile_label': {
      AppLanguage.en: 'Mobile Number (10 digits)',
      AppLanguage.hinglish: 'Mobile number (10 ank)',
      AppLanguage.hi: 'मोबाइल नंबर (10 अंक)',
      AppLanguage.gu: 'મોબાઇલ નંબર (10 અંક)',
    },
    'mobile_hint': {
      AppLanguage.en: '98290XXXXX',
      AppLanguage.hinglish: '98290XXXXX',
      AppLanguage.hi: '98290XXXXX',
      AppLanguage.gu: '98290XXXXX',
    },
    'route_label': {
      AppLanguage.en: 'Beat / Route',
      AppLanguage.hinglish: 'Beat / Route',
      AppLanguage.hi: 'बीट / रूट',
      AppLanguage.gu: 'બીટ / રૂટ',
    },
    'capture_gps_button': {
      AppLanguage.en: '📍 Capture Current Location',
      AppLanguage.hinglish: '📍 GPS location capture karein',
      AppLanguage.hi: '📍 जीपीएस लोकेशन लें',
      AppLanguage.gu: '📍 જીપીએસ લોકેશન લો',
    },
    'location_not_captured': {
      AppLanguage.en: 'Location not captured',
      AppLanguage.hinglish: 'Location darj nahi hui',
      AppLanguage.hi: 'लोकेशन दर्ज नहीं की गई',
      AppLanguage.gu: 'લોકેશન મેળવેલ નથી',
    },
    'location_accuracy': {
      AppLanguage.en: 'Location accuracy: ±{meters} m',
      AppLanguage.hinglish: 'Location accuracy: ±{meters} m',
      AppLanguage.hi: 'सटीकता: ±{meters} मीटर',
      AppLanguage.gu: 'ચોકસાઈ: ±{meters} મીટર',
    },
    'more_details': {
      AppLanguage.en: '+ Add More Details (Optional)',
      AppLanguage.hinglish: '+ Aur jaankari jodein (Optional)',
      AppLanguage.hi: '+ अन्य विवरण (वैकल्पिक)',
      AppLanguage.gu: '+ વધુ વિગતો (વૈકલ્પિક)',
    },
    'address_label': {
      AppLanguage.en: 'Shop Address',
      AppLanguage.hinglish: 'Dukaan ka pata',
      AppLanguage.hi: 'दुकान का पता',
      AppLanguage.gu: 'દુકાનનું સરનામું',
    },
    'landmark_label': {
      AppLanguage.en: 'Landmark',
      AppLanguage.hinglish: 'Landmark / Nishani',
      AppLanguage.hi: 'लैंडमार्क / पहचान',
      AppLanguage.gu: 'લેન્ડમાર્ક / ઓળખ',
    },
    'pincode_label': {
      AppLanguage.en: 'PIN Code',
      AppLanguage.hinglish: 'Pin Code',
      AppLanguage.hi: 'पिन कोड',
      AppLanguage.gu: 'પીન કોડ',
    },
    'gstin_label': {
      AppLanguage.en: 'GSTIN (Optional)',
      AppLanguage.hinglish: 'GSTIN (Optional)',
      AppLanguage.hi: 'जीएसटी नंबर (GSTIN)',
      AppLanguage.gu: 'જીએસટી નંબર (વૈકલ્પિક)',
    },
    'save_shop_button': {
      AppLanguage.en: 'Save Shop',
      AppLanguage.hinglish: 'Dukaan save karein',
      AppLanguage.hi: 'दुकान सुरक्षित करें',
      AppLanguage.gu: 'દુકાન સાચવો',
    },

    // === 5. CLASSIFICATION & WARNINGS ===
    'class_new': {
      AppLanguage.en: 'New',
      AppLanguage.hinglish: 'Nayi',
      AppLanguage.hi: 'नई दुकान',
      AppLanguage.gu: 'નવી દુકાન',
    },
    'class_a': {
      AppLanguage.en: 'Class A',
      AppLanguage.hinglish: 'Class A',
      AppLanguage.hi: 'श्रेणी A',
      AppLanguage.gu: 'શ્રેણી A',
    },
    'class_b': {
      AppLanguage.en: 'Class B',
      AppLanguage.hinglish: 'Class B',
      AppLanguage.hi: 'श्रेणी B',
      AppLanguage.gu: 'શ્રેણી B',
    },
    'class_c': {
      AppLanguage.en: 'Class C',
      AppLanguage.hinglish: 'Class C',
      AppLanguage.hi: 'श्रेणी C',
      AppLanguage.gu: 'શ્રેણી C',
    },
    'class_d': {
      AppLanguage.en: 'Class D (Cash Only)',
      AppLanguage.hinglish: 'Class D (Sirf Nakad)',
      AppLanguage.hi: 'श्रेणी D (केवल नकद)',
      AppLanguage.gu: 'શ્રેણી D (ફક્ત રોકડા)',
    },
    'cash_only_warning': {
      AppLanguage.en: 'This shop is cash/COD only.',
      AppLanguage.hinglish: 'Is dukaan par sirf nakad / COD chalega.',
      AppLanguage.hi: 'यह दुकान केवल नकद/सीओडी पर है।',
      AppLanguage.gu: 'આ દુકાન ફક્ત રોકડ/COD પર છે.',
    },
    'duplicate_warning_title': {
      AppLanguage.en: 'Is this the same shop?',
      AppLanguage.hinglish: 'Kya ye wahi dukaan hai?',
      AppLanguage.hi: 'क्या यह वही दुकान है?',
      AppLanguage.gu: 'શું આ એ જ દુકાન છે?',
    },
    'open_existing_shop': {
      AppLanguage.en: 'Yes, open that shop',
      AppLanguage.hinglish: 'Haan, wahi dukaan kholein',
      AppLanguage.hi: 'हाँ, वही दुकान खोलें',
      AppLanguage.gu: 'હા, તે જ દુકાન ખોલો',
    },
    'different_shop_confirm': {
      AppLanguage.en: 'No, this is a different shop',
      AppLanguage.hinglish: 'Nahi, ye alag dukaan hai',
      AppLanguage.hi: 'नहीं, यह अलग दुकान है',
      AppLanguage.gu: 'ના, આ અલગ દુકાન છે',
    },

    // === 6. SYNC & STORAGE HONESTY ===
    'waiting_to_sync': {
      AppLanguage.en: 'Waiting to sync',
      AppLanguage.hinglish: 'Sync ki pratiksha me',
      AppLanguage.hi: 'सिंक की प्रतीक्षा में',
      AppLanguage.gu: 'સિંક કરવાની રાહમાં',
    },
    'local_only_mode': {
      AppLanguage.en: 'Local Outbox Mode',
      AppLanguage.hinglish: 'Local outbox mode',
      AppLanguage.hi: 'लोकल आउटबॉक्स मोड',
      AppLanguage.gu: 'લોકલ આઉટબોક્સ મોડ',
    },
    'sync_status_title': {
      AppLanguage.en: 'Sync Status',
      AppLanguage.hinglish: 'Sync status',
      AppLanguage.hi: 'सिंक स्थिति',
      AppLanguage.gu: 'સિંક સ્થિતિ',
    },
    'saved_on_phone_outbox': {
      AppLanguage.en: 'Saved on this phone (Offline Outbox)',
      AppLanguage.hinglish: 'Phone par save hua (Offline outbox)',
      AppLanguage.hi: 'फ़ोन में सुरक्षित (ऑफ़लाइन आउटबॉक्स)',
      AppLanguage.gu: 'ફોનમાં સાચવેલ (ઓફલાઇન આઉટબોક્સ)',
    },
    'uploading_to_cloud': {
      AppLanguage.en: 'Uploading to Cloud...',
      AppLanguage.hinglish: 'Cloud par upload ho raha hai...',
      AppLanguage.hi: 'क्लाउड पर अपलोड हो रहा है...',
      AppLanguage.gu: 'ક્લાઉડ પર અપલોડ થઈ રહ્યું છે...',
    },
    'synced_to_cloud': {
      AppLanguage.en: 'Synced to Cloud',
      AppLanguage.hinglish: 'Cloud par sync ho gaya',
      AppLanguage.hi: 'क्लाउड पर सिंक हो गया',
      AppLanguage.gu: 'ક્લાઉડ પર સિંક થઈ ગયું',
    },
    'sync_worker_note': {
      AppLanguage.en: 'Sync worker inactive — mutations remain safe on phone.',
      AppLanguage.hinglish: 'Sync worker band hai — saare badlav phone me surakshit hain.',
      AppLanguage.hi: 'सिंक वर्कर अभी निष्क्रिय है — सभी बदलाव फ़ोन पर पूरी तरह सुरक्षित हैं।',
      AppLanguage.gu: 'સિંક વર્કર બંધ છે — ફેરફારો ફોનમાં સુરક્ષિત છે.',
    },
    'pending_mutations_count': {
      AppLanguage.en: '{count} pending mutation(s) safely queued',
      AppLanguage.hinglish: '{count} badlav queue me surakshit hain',
      AppLanguage.hi: '{count} बदलाव कतार में सुरक्षित हैं',
      AppLanguage.gu: '{count} ફેરફાર કતારમાં સુરક્ષિત છે',
    },
    'booked_on_device': {
      AppLanguage.en: 'Booked on Device',
      AppLanguage.hinglish: 'Device par book hua',
      AppLanguage.hi: 'डिवाइस पर बुक हुआ',
      AppLanguage.gu: 'ડિવાઇસ પર બુક થયું',
    },
    'saved_in_local_outbox': {
      AppLanguage.en: 'Saved in Local Outbox',
      AppLanguage.hinglish: 'Local outbox me surakshit',
      AppLanguage.hi: 'लोकल आउटबॉक्स में सुरक्षित',
      AppLanguage.gu: 'લોકલ આઉટબોક્સમાં સુરક્ષિત',
    },
    'cloud_sync': {
      AppLanguage.en: 'Cloud Sync',
      AppLanguage.hinglish: 'Cloud sync',
      AppLanguage.hi: 'क्लाउड सिंक',
      AppLanguage.gu: 'ક્લાઉડ સિંક',
    },
    'pending_upload_cloudflare': {
      AppLanguage.en: 'Pending upload to Office Cloud',
      AppLanguage.hinglish: 'Office server par upload baaki',
      AppLanguage.hi: 'ऑफिस सर्वर पर अपलोड लंबित',
      AppLanguage.gu: 'ઓફિસ સર્વર પર અપલોડ બાકી',
    },
    'audit_timeline': {
      AppLanguage.en: 'Order Audit Timeline',
      AppLanguage.hinglish: 'Order audit timeline',
      AppLanguage.hi: 'ऑर्डर ऑडिट टाइमलाइन',
      AppLanguage.gu: 'ઓર્ડર ઓડિટ ટાઈમલાઈન',
    },

    // === 7. INVENTORY, GRN & PACKAGING ===
    'receive_stock': {
      AppLanguage.en: 'Receive Stock (GRN)',
      AppLanguage.hinglish: 'Maal aavak (GRN)',
      AppLanguage.hi: 'स्टॉक आवक (GRN)',
      AppLanguage.gu: 'માલ આવક (GRN)',
    },
    'godown_cartons': {
      AppLanguage.en: 'Godown Cartons',
      AppLanguage.hinglish: 'Godown petiyan',
      AppLanguage.hi: 'गोदाम पेटियां',
      AppLanguage.gu: 'ગોડાઉન પેટીઓ',
    },
    'loose_pieces': {
      AppLanguage.en: 'Loose Pieces',
      AppLanguage.hinglish: 'Khule nag',
      AppLanguage.hi: 'खुले नग',
      AppLanguage.gu: 'છૂટા નંગ',
    },
    'damaged_stock': {
      AppLanguage.en: 'Damaged / Quarantine',
      AppLanguage.hinglish: 'Kharab maal',
      AppLanguage.hi: 'खराब / क्षतिग्रस्त',
      AppLanguage.gu: 'ખરાબ / નુકસાનીવાળો માલ',
    },
    'invoice_number': {
      AppLanguage.en: 'Invoice / GRN No.',
      AppLanguage.hinglish: 'Challan / Bill no.',
      AppLanguage.hi: 'चालान / बिल नंबर',
      AppLanguage.gu: 'ચલણ / બિલ નંબર',
    },
    'supplier_name': {
      AppLanguage.en: 'Supplier Name',
      AppLanguage.hinglish: 'Supplier / Company naam',
      AppLanguage.hi: 'सप्लायर / कंपनी',
      AppLanguage.gu: 'સપ્લાયર / કંપની',
    },
    'sales_order': {
      AppLanguage.en: 'Sales Order',
      AppLanguage.hinglish: 'Sales order',
      AppLanguage.hi: 'बिक्री ऑर्डर',
      AppLanguage.gu: 'વેચાણ ઓર્ડર',
    },
    'unit_piece': {
      AppLanguage.en: 'Piece',
      AppLanguage.hinglish: 'Nag',
      AppLanguage.hi: 'पीस',
      AppLanguage.gu: 'નંગ',
    },
    'unit_strip': {
      AppLanguage.en: 'Strip',
      AppLanguage.hinglish: 'Strip',
      AppLanguage.hi: 'स्ट्रिप / पत्ता',
      AppLanguage.gu: 'સ્ટ્રિપ',
    },
    'unit_box': {
      AppLanguage.en: 'Box',
      AppLanguage.hinglish: 'Peti',
      AppLanguage.hi: 'पेटी / बॉक्स',
      AppLanguage.gu: 'પેટી',
    },
    'cart_draft_saved': {
      AppLanguage.en: 'Cart draft auto-saved',
      AppLanguage.hinglish: 'Cart draft auto-save hua',
      AppLanguage.hi: 'कार्ट ड्राफ्ट सुरक्षित',
      AppLanguage.gu: 'કાર્ટ ડ્રાફ્ટ સાચવેલ',
    },
    'no_order_recorded': {
      AppLanguage.en: 'No-order visit recorded',
      AppLanguage.hinglish: 'Bina order visit darj hua',
      AppLanguage.hi: 'बिना ऑर्डर दौरा दर्ज',
      AppLanguage.gu: 'ઓર્ડર વિના મુલાકાત નોંધાઈ',
    },
    'credit_limit_exceeded': {
      AppLanguage.en: 'Credit limit exceeded',
      AppLanguage.hinglish: 'Udhaar seema paar ho gayi',
      AppLanguage.hi: 'उधार सीमा समाप्त',
      AppLanguage.gu: 'ઉધાર મર્યાદા પૂરી થઈ',
    },

    // === 8. VALIDATION ERRORS ===
    'shop_name_required': {
      AppLanguage.en: 'Shop name is required',
      AppLanguage.hinglish: 'Dukaan ka naam likhna zaroori hai',
      AppLanguage.hi: 'कृपया दुकान का नाम लिखें',
      AppLanguage.gu: 'દુકાનનું નામ જરૂરી છે',
    },
    'owner_name_required': {
      AppLanguage.en: 'Owner name is required',
      AppLanguage.hinglish: 'Maalik ka naam likhna zaroori hai',
      AppLanguage.hi: 'कृपया मालिक का नाम लिखें',
      AppLanguage.gu: 'માલિકનું નામ જરૂરી છે',
    },
    'valid_mobile_required': {
      AppLanguage.en: 'Please enter a valid 10-digit mobile number',
      AppLanguage.hinglish: 'Kripya 10 ank ka sahi mobile number dalein',
      AppLanguage.hi: 'कृपया 10 अंकों का मान्य मोबाइल नंबर दर्ज करें',
      AppLanguage.gu: 'કૃપા કરીને માન્ય 10 અંકનો મોબાઇલ નંબર દાખલ કરો',
    },

    // === 9. PRODUCT & CATALOG UX ===
    'no_orders_beat_prompt': {
      AppLanguage.en: 'Select a retailer from your beat and book orders.',
      AppLanguage.hinglish: 'Apne beat se dukaan chunein aur order book karein.',
      AppLanguage.hi: 'अपनी बीट से दुकान चुनें और ऑर्डर बुक करें।',
      AppLanguage.gu: 'તમારી બીટમાંથી દુકાન પસંદ કરો અને ઓર્ડર બુક કરો.',
    },
    'no_orders_booked_today': {
      AppLanguage.en: 'No Orders Booked Yet Today',
      AppLanguage.hinglish: 'Aaj abhi tak koi order nahi hua',
      AppLanguage.hi: 'आज अभी तक कोई ऑर्डर दर्ज नहीं हुआ',
      AppLanguage.gu: 'આજે હજુ સુધી કોઈ ઓર્ડર નોંધાયેલ નથી',
    },
    'book_first_order': {
      AppLanguage.en: 'Book First Order',
      AppLanguage.hinglish: 'Pehla order book karein',
      AppLanguage.hi: 'पहला ऑर्डर बुक करें',
      AppLanguage.gu: 'પહેલો ઓર્ડર બુક કરો',
    },
    'product_name_example': {
      AppLanguage.en: 'Product Name (e.g. Masala Sev)',
      AppLanguage.hinglish: 'Product ka naam (jaise Masala Sev)',
      AppLanguage.hi: 'उत्पाद का नाम (उदा. मसाला सेव)',
      AppLanguage.gu: 'પ્રોડક્ટનું નામ (દા.ત. મસાલા સેવ)',
    },
    'product_local_name_example': {
      AppLanguage.en: 'Hindi / Local Name (e.g. ग्रीन चटनी)',
      AppLanguage.hinglish: 'Hindi / Local naam (jaise ग्रीन चटनी)',
      AppLanguage.hi: 'हिंदी / स्थानीय नाम (उदा. ग्रीन चटनी)',
      AppLanguage.gu: 'હિન્દી / સ્થાનિક નામ (દા.ત. ગ્રીન ચટણી)',
    },
    'search_products_hint': {
      AppLanguage.en: 'Search products, namkeen, wafers...',
      AppLanguage.hinglish: 'Products, namkeen, wafers khojein...',
      AppLanguage.hi: 'उत्पाद, नमकीन, वेफर्स खोजें...',
      AppLanguage.gu: 'પ્રોડક્ટ્સ, નમકીન, વેફર્સ શોધો...',
    },
  };

  /// Direct read-only access to all registered translations for test validation.
  @visibleForTesting
  static Map<String, Map<AppLanguage, String>> get translations => _translations;
}
