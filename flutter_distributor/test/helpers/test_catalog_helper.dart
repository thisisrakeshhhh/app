import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';

ProductItem createTestKurkure({
  String id = 'KURK-01',
  String name = 'Kurkure Masala Munch',
  String hindiName = 'कुरकुरे मसाला मंच',
  int boxQty = 96,
  int stripQty = 12,
  int godownStockBoxes = 180,
  int carStockBoxes = 24,
  int piecePricePaise = 850,
}) {
  return ProductItem(
    id: id,
    name: name,
    hindiName: hindiName,
    category: 'Snacks',
    mrpRupees: 20.0,
    piecePricePaise: piecePricePaise,
    stripQty: stripQty,
    boxQty: boxQty,
    gstRate: 12.0,
    godownStockBoxes: godownStockBoxes,
    carStockBoxes: carStockBoxes,
    badge: 'Popular',
    batchNumber: 'LOT-KURK-01',
    expiryDate: DateTime(2027, 4, 15),
    reorderLevelBoxes: 30,
  );
}

ProductItem createTestKurkure02() {
  return ProductItem(
    id: 'KURK-02',
    name: 'Kurkure Chilli Chatka',
    hindiName: 'कुरकुरे चिल्ली झटका',
    category: 'Snacks',
    mrpRupees: 20.0,
    piecePricePaise: 850,
    stripQty: 12,
    boxQty: 96,
    gstRate: 12.0,
    godownStockBoxes: 120,
    carStockBoxes: 18,
    badge: 'Spicy',
    batchNumber: 'LOT-KURK-02',
    expiryDate: DateTime(2027, 4, 15),
    reorderLevelBoxes: 25,
  );
}

ProductItem createTestLays01() {
  return ProductItem(
    id: 'LAYS-01',
    name: 'Lays Classic Salted',
    hindiName: 'लेज क्लासिक नमकीन',
    category: 'Snacks',
    mrpRupees: 20.0,
    piecePricePaise: 1700,
    stripQty: 10,
    boxQty: 50,
    gstRate: 12.0,
    godownStockBoxes: 120,
    carStockBoxes: 15,
    badge: 'Classic',
    batchNumber: 'LOT-LAYS-01',
    expiryDate: DateTime(2027, 4, 15),
    reorderLevelBoxes: 20,
  );
}

ProductItem createTestLays02() {
  return ProductItem(
    id: 'LAYS-02',
    name: 'Lays Magic Masala',
    hindiName: 'लेज मैजिक मसाला',
    category: 'Snacks',
    mrpRupees: 20.0,
    piecePricePaise: 1700,
    stripQty: 10,
    boxQty: 50,
    gstRate: 12.0,
    godownStockBoxes: 100,
    carStockBoxes: 15,
    badge: 'Hot Seller',
    batchNumber: 'LOT-LAYS-02',
    expiryDate: DateTime(2027, 4, 15),
    reorderLevelBoxes: 20,
  );
}

ProductItem createTestPepsi500() {
  return ProductItem(
    id: 'PEPSI-500',
    name: 'Pepsi 500ml Pet Bottle',
    hindiName: 'पेप्सी 500ml',
    category: 'Beverages',
    mrpRupees: 40.0,
    piecePricePaise: 3400,
    stripQty: 6,
    boxQty: 24,
    gstRate: 28.0,
    godownStockBoxes: 100,
    carStockBoxes: 10,
    badge: 'Beverage',
    batchNumber: 'LOT-PEP-500',
    expiryDate: DateTime(2027, 4, 15),
    reorderLevelBoxes: 15,
  );
}

ProductItem createTestSting250() {
  return ProductItem(
    id: 'STING-250',
    name: 'Sting Energy 250ml Can',
    hindiName: 'स्टिंग एनर्जी',
    category: 'Beverages',
    mrpRupees: 20.0,
    piecePricePaise: 1700,
    stripQty: 6,
    boxQty: 30,
    gstRate: 28.0,
    godownStockBoxes: 80,
    carStockBoxes: 12,
    badge: 'Energy',
    batchNumber: 'LOT-STING-250',
    expiryDate: DateTime(2027, 4, 15),
    reorderLevelBoxes: 15,
  );
}

Future<void> registerTestCatalogFixtures(ApiService api, [LocalRepository? repo]) async {
  final fixtures = [
    createTestKurkure(),
    createTestKurkure02(),
    createTestLays01(),
    createTestLays02(),
    createTestPepsi500(),
    createTestSting250(),
  ];
  for (final item in fixtures) {
    if (!api.products.any((p) => p.id == item.id)) {
      api.products.add(item);
    }
    if (repo != null) {
      await repo.upsertProduct(item);
    }
  }
}
