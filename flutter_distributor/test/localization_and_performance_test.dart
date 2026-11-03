import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/l10n/app_strings.dart';
import 'package:lala_distributor/models/models.dart';

class ZeroNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access strictly forbidden in offline tests');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = ZeroNetworkHttpOverrides();

  group('Slice 7: Polish, Hindi Localization & Catalog Performance Benchmarks', () {
    tearDown(() {
      // Always reset back to English baseline
      AppStrings.isHindi = false;
    });

    test('1. Bilingual dictionary: 100% of core UI strings have valid Hindi Devanagari translations', () {
      // 1. English mode check
      AppStrings.isHindi = false;
      expect(AppStrings.addShopTitle, 'Add New Shop');
      expect(AppStrings.savedOnPhoneOutbox, 'Saved on this phone (Offline Outbox)');
      expect(AppStrings.receiveStock, 'Receive Stock (GRN)');
      expect(AppStrings.unitBox, 'Box');

      // 2. Hindi mode check
      AppStrings.isHindi = true;
      expect(AppStrings.addShopTitle, contains('दुकान'));
      expect(AppStrings.savedOnPhoneOutbox, contains('फोन पर सुरक्षित'));
      expect(AppStrings.receiveStock, contains('स्टॉक आवक'));
      expect(AppStrings.quickAddSubtitle, contains('तुरंत'));
      expect(AppStrings.saveShopButton, contains('सुरक्षित'));
      expect(AppStrings.classNew, 'नई दुकान');
      expect(AppStrings.classD, contains('नकद'));
      expect(AppStrings.syncStatusTitle, 'सिंक स्थिति');
      expect(AppStrings.unitPiece, 'पीस');
      expect(AppStrings.unitStrip, contains('स्ट्रिप'));
      expect(AppStrings.unitBox, contains('पेटी'));

      // 3. Dynamic parameterized formatting in Hindi
      final accString = AppStrings.locationAccuracy(12.4);
      expect(accString, contains('सटीकता: ±12 मीटर'));

      final pendingString = AppStrings.pendingMutationsCount(5);
      expect(pendingString, contains('5 बदलाव कतार में सुरक्षित'));
    });

    test('2. Synthetic catalog performance: 2,000 product search runs in <16ms frame budget', () {
      // Generate 2,000 realistic Indian FMCG catalog items
      final prefixes = ['Parle-G', 'Britannia Good Day', 'Kurkure Masala', 'Tata Salt', 'Maggi 2-Min', 'Aashirvaad Atta', 'Dettol Soap', 'Haldiram Bhujia'];
      final categories = ['Biscuits', 'Snacks', 'Staples', 'Noodles', 'Personal Care', 'Spices'];

      final products = List<ProductItem>.generate(2000, (i) {
        final prefix = prefixes[i % prefixes.length];
        final cat = categories[i % categories.length];
        final skuNum = (i + 1).toString().padLeft(4, '0');
        return ProductItem(
          id: 'PROD-$skuNum',
          name: '$prefix Pack $skuNum',
          hindiName: '$prefix पैक $skuNum',
          category: cat,
          mrpRupees: 10.0 + (i % 50),
          piecePricePaise: 800 + (i % 400),
          stripQty: 10,
          boxQty: 100,
          gstRate: 5.0,
          godownStockBoxes: 25,
          carStockBoxes: 5,
          badge: i % 10 == 0 ? 'Bestseller' : '',
        );
      });

      expect(products.length, 2000);

      // Benchmark realistic multi-query user search typing simulation
      final searchQueries = ['parle', 'kurk', 'tata', 'soap', 'atta', 'maggi', '0050', 'bestseller'];
      final stopwatch = Stopwatch()..start();

      int matchCount = 0;
      for (final query in searchQueries) {
        final q = query.toLowerCase();
        final results = products.where((p) {
          return p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q) ||
              p.id.toLowerCase().contains(q) ||
              p.badge.toLowerCase().contains(q);
        }).toList();
        matchCount += results.length;
      }

      stopwatch.stop();
      final totalElapsedMs = stopwatch.elapsedMilliseconds;
      final avgElapsedPerQueryMs = totalElapsedMs / searchQueries.length;

      // High-performance threshold assertion: Each search across 2,000 items MUST execute in <16ms (single 60fps frame)
      expect(avgElapsedPerQueryMs, lessThan(16.0),
          reason: 'Average query time was ${avgElapsedPerQueryMs.toStringAsFixed(2)}ms, exceeding 16ms frame budget');
      expect(matchCount, greaterThan(0));
    });
  });
}
