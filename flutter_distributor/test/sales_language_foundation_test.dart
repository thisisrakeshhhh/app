import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/features/sales/services/sales_feature_service.dart';
import 'package:lala_distributor/features/sales/widgets/sales_language_picker.dart';
import 'package:lala_distributor/l10n/app_language.dart';
import 'package:lala_distributor/l10n/app_strings.dart';
import 'package:lala_distributor/l10n/language_controller.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/screens/views/sales_route_map_view.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  group('Slice S1: Language Foundation, Invariants & Trade Glossary', () {
    late LanguageController languageController;
    late InMemoryLanguageStorage storage;

    setUp(() {
      storage = InMemoryLanguageStorage();
      languageController = LanguageController(storage: storage);
      LanguageController.resetInstanceForTesting(languageController);
    });

    test('1. Key Coverage: Every registered key has non-empty en, hinglish, hi and gu translations', () {
      final translations = AppStrings.translations;
      expect(translations.isNotEmpty, isTrue);

      final languages = [
        AppLanguage.en,
        AppLanguage.hinglish,
        AppLanguage.hi,
        AppLanguage.gu,
      ];

      for (final entry in translations.entries) {
        final key = entry.key;
        final map = entry.value;

        for (final lang in languages) {
          final text = map[lang];
          expect(
            text != null && text.trim().isNotEmpty,
            isTrue,
            reason: 'Key "$key" is missing or blank for language ${lang.code}',
          );
        }
      }
    });

    test('2. Glossary Table: Core trade invariant terms match required specifications', () {
      final stringsEn = AppStrings(AppLanguage.en);
      final stringsHinglish = AppStrings(AppLanguage.hinglish);
      final stringsHi = AppStrings(AppLanguage.hi);
      final stringsGu = AppStrings(AppLanguage.gu);

      // Box / Case
      expect(stringsEn.t('box'), equals('Box'));
      expect(stringsHinglish.t('box'), equals('Peti'));
      expect(stringsHi.t('box'), equals('पेटी'));
      expect(stringsGu.t('box'), equals('પેટી'));

      // Piece / Nag
      expect(stringsEn.t('piece'), equals('Piece'));
      expect(stringsHinglish.t('piece'), equals('Nag'));
      expect(stringsHi.t('piece'), equals('नग'));
      expect(stringsGu.t('piece'), equals('નંગ'));

      // Strip
      expect(stringsEn.t('strip'), equals('Strip'));
      expect(stringsHinglish.t('strip'), equals('Strip'));
      expect(stringsHi.t('strip'), equals('स्ट्रिप'));
      expect(stringsGu.t('strip'), equals('સ્ટ્રિપ'));

      // Stock / Maal
      expect(stringsEn.t('stock'), equals('Stock'));
      expect(stringsHinglish.t('stock'), equals('Maal'));
      expect(stringsHi.t('stock'), equals('माल'));
      expect(stringsGu.t('stock'), equals('માલ'));

      // Collection / Vasooli
      expect(stringsEn.t('collection'), equals('Collection'));
      expect(stringsHinglish.t('collection'), equals('Vasooli'));
      expect(stringsHi.t('collection'), equals('वसूली'));
      expect(stringsGu.t('collection'), equals('ઉઘરાણી'));

      // Cash / Nakad
      expect(stringsEn.t('cash'), equals('Cash'));
      expect(stringsHinglish.t('cash'), equals('Nakad'));
      expect(stringsHi.t('cash'), equals('नकद'));
      expect(stringsGu.t('cash'), equals('રોકડા'));

      // Saved on this phone
      expect(stringsEn.t('saved_on_phone'), equals('Saved on this phone'));
      expect(stringsHinglish.t('saved_on_phone'), equals('Phone me save hua'));
      expect(stringsHi.t('saved_on_phone'), equals('फ़ोन में सेव हुआ'));
      expect(stringsGu.t('saved_on_phone'), equals('ફોનમાં સેવ થયું'));
    });

    test('3. Codebase Scan: lib/features/sales/ contains zero hardcoded Text(\'...\') literals', () {
      final salesDir = Directory('lib/features/sales');
      if (!salesDir.existsSync()) {
        // Fallback for execution from different working dir
        final altDir = Directory('flutter_distributor/lib/features/sales');
        if (altDir.existsSync()) {
          _assertNoHardcodedTextLiterals(altDir);
          return;
        }
      }
      _assertNoHardcodedTextLiterals(salesDir);
    });

    test('4. Currency & Number Formatting: Latin digits with Indian grouping (₹1,42,800)', () {
      // 142800 rupees = 14280000 paise
      expect(AppStrings.formatPaise(14280000), equals('₹1,42,800'));
      expect(AppStrings.formatPaise(500000), equals('₹5,000'));
      expect(AppStrings.formatPaise(75050), equals('₹750.50'));
      expect(AppStrings.formatPaise(1000000000), equals('₹1,00,00,000'));
    });

    test('5. Per-User Language Isolation & Restart Persistence', () async {
      await languageController.setLanguage(AppLanguage.gu, userId: 'sales_rep_gujarat');
      await languageController.setLanguage(AppLanguage.hi, userId: 'sales_rep_jodhpur');

      final freshController = LanguageController(storage: storage);

      await freshController.loadSavedLanguage(userId: 'sales_rep_gujarat');
      expect(freshController.currentLanguage, equals(AppLanguage.gu));

      await freshController.loadSavedLanguage(userId: 'sales_rep_jodhpur');
      expect(freshController.currentLanguage, equals(AppLanguage.hi));

      // Brand new user defaults to Hinglish
      await freshController.loadSavedLanguage(userId: 'new_sales_rep');
      expect(freshController.currentLanguage, equals(AppLanguage.hinglish));
    });

    test('6. Question 5 SCO / Unit Label: Matches "Shop 12" and "Plot 5B" as unitNo without "SCO" prefix', () {
      final shop1 = RetailerShop(
        id: 's1',
        name: 'Shop 1',
        ownerName: 'O1',
        phone: '111',
        address: 'Shop No. 12, Main Market, Jodhpur',
        area: 'Sardarpura',
        creditLimitPaise: 100000,
        outstandingPaise: 0,
      );
      final shop2 = RetailerShop(
        id: 's2',
        name: 'Shop 2',
        ownerName: 'O2',
        phone: '222',
        address: 'Plot 5B, Industrial Phase 1',
        area: 'Basni',
        creditLimitPaise: 100000,
        outstandingPaise: 0,
      );
      final shop3 = RetailerShop(
        id: 's3',
        name: 'Shop 3',
        ownerName: 'O3',
        phone: '333',
        address: 'SCO 42, Commercial Complex',
        area: 'Ratanada',
        creditLimitPaise: 100000,
        outstandingPaise: 0,
      );

      expect(shop1.unitNo, equals('Shop No. 12'));
      expect(shop2.unitNo, equals('Plot 5B'));
      expect(shop3.unitNo, equals('SCO 42'));

      // Backward compatible alias
      expect(shop1.scoNo, equals('Shop No. 12'));
    });

    testWidgets('7. Language Picker: Instant switch updates UI across 4 languages without restart', (tester) async {
      final controller = LanguageController();

      await tester.pumpWidget(
        LanguageScope(
          controller: controller,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                final strings = AppStrings.of(ctx);
                return Scaffold(
                  body: Column(
                    children: [
                      Text(strings.t('today'), key: const Key('today_text')),
                      Text(strings.t('box'), key: const Key('box_text')),
                      ElevatedButton(
                        key: const Key('btn_open_picker'),
                        onPressed: () => SalesLanguagePicker.showSheet(ctx),
                        child: const Text('Change Language'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Initial: Hinglish default
      expect(find.text('Aaj'), findsOneWidget);
      expect(find.text('Peti'), findsOneWidget);

      // Open picker
      await tester.tap(find.byKey(const Key('btn_open_picker')));
      await tester.pumpAndSettle();

      // Tap Gujarati
      await tester.tap(find.text('ગુજરાતી'));
      await tester.pumpAndSettle();

      expect(find.text('આજ'), findsOneWidget);
      expect(find.text('પેટી'), findsOneWidget);

      // Open picker again and tap Hindi
      await tester.tap(find.byKey(const Key('btn_open_picker')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();

      expect(find.text('आज'), findsOneWidget);
      expect(find.text('पेटी'), findsOneWidget);

      // Open picker again and tap English
      await tester.tap(find.byKey(const Key('btn_open_picker')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English').first);
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Box'), findsOneWidget);
    });

    testWidgets('8. 130% Text Scale Check: No clipping or overflow on 360dp mobile screen for Indic text', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 740 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LanguageController(initialLanguage: AppLanguage.hi);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 740),
            textScaler: TextScaler.linear(1.3), // 130% text scaling
          ),
          child: LanguageScope(
            controller: controller,
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SalesLanguagePicker(isDismissible: false),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('ગુજરાતી'), findsOneWidget);
    });

    testWidgets('9. Question 6 Map Pins: Shops without coordinates excluded from canvas sketch and placed in unlocated list', (tester) async {
      final api = ApiService();

      // Clear existing demo retailers and inject controlled set
      api.retailers.clear();
      final shopWithGeo1 = RetailerShop(
        id: 'geo_1',
        name: 'Mahadev Kirana',
        ownerName: 'M1',
        phone: '111',
        address: 'Nai Sadak',
        area: 'Sardarpura',
        latitude: 26.2800,
        longitude: 73.0200,
        creditLimitPaise: 100000,
        outstandingPaise: 0,
      );
      final shopWithGeo2 = RetailerShop(
        id: 'geo_2',
        name: 'Kailash Stores',
        ownerName: 'K1',
        phone: '222',
        address: 'Clock Tower',
        area: 'Sardarpura',
        latitude: 26.2900,
        longitude: 73.0300,
        creditLimitPaise: 100000,
        outstandingPaise: 0,
      );
      final shopWithoutGeo = RetailerShop(
        id: 'no_geo_3',
        name: 'Bhawani General Store',
        ownerName: 'B1',
        phone: '333',
        address: 'Deep Gali',
        area: 'Sardarpura',
        latitude: null, // No GPS coordinate
        longitude: null,
        creditLimitPaise: 100000,
        outstandingPaise: 0,
      );

      api.retailers.addAll([shopWithGeo1, shopWithGeo2, shopWithoutGeo]);
      api.setAssignedBeatShopIds(['geo_1', 'geo_2', 'no_geo_3']);

      await tester.pumpWidget(
        LanguageScope(
          controller: LanguageController(initialLanguage: AppLanguage.en),
          child: MaterialApp(
            home: SalesRouteMapView(api: api),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pin labels on map canvas should exist ONLY for geo_1 (A) and geo_2 (B)
      // 'A' appears on canvas pin + bottom card for selected stop (2 widgets)
      expect(find.text('A'), findsNWidgets(2));
      // 'B' appears on canvas pin (1 widget)
      expect(find.text('B'), findsOneWidget);
      // 'C' should NOT be plotted on canvas sketch as a pin badge
      expect(find.text('C'), findsNothing);

      // Instead, shopWithoutGeo must appear in the dedicated "Location not added" section
      expect(find.byKey(const Key('location_not_added_section')), findsOneWidget);
      expect(find.textContaining('Bhawani General Store'), findsAtLeastNWidgets(1));
      expect(find.text('Add location'), findsOneWidget);
    });

    test('10. Question 4 Extra Visits Service: Add / remove extra visit and check route schedule', () async {
      final api = ApiService();
      final service = SalesFeatureService(api: api);

      await service.initialize();
      expect(service.isShopInTodaySchedule('extra_shop_99'), isFalse);

      await service.addExtraVisit('extra_shop_99');
      expect(service.isShopInTodaySchedule('extra_shop_99'), isTrue);
      expect(service.extraVisitShopIds.contains('extra_shop_99'), isTrue);

      await service.removeExtraVisit('extra_shop_99');
      expect(service.isShopInTodaySchedule('extra_shop_99'), isFalse);
    });
  });
}

void _assertNoHardcodedTextLiterals(Directory dir) {
  final dartFiles = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  final regex = RegExp(r"Text\(\s*[']([A-Za-z0-9\s]{3,})[']");

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Skip imports, comments, keys
      if (line.trim().startsWith('//') || line.contains('Key(') || line.contains("t('")) continue;
      final match = regex.firstMatch(line);
      if (match != null) {
        fail('Found hardcoded user-facing Text literal in ${file.path}:${i + 1} -> "${match.group(0)}"');
      }
    }
  }
}
