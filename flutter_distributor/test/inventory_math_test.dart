import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/domain/models/inventory_math.dart';

void main() {
  group('InventoryStock Mathematics (Integer Precision)', () {
    test('10 cartons * 48 pieces = 480 pieces initial total', () {
      final stock = InventoryStock(cartons: 10, loosePieces: 0, piecesPerCarton: 48);
      expect(stock.cartons, 10);
      expect(stock.loosePieces, 0);
      expect(stock.piecesPerCarton, 48);
      expect(stock.totalPieces, 480);
    });

    test('Opening one carton produces 9 unopened cartons and 48 loose pieces', () {
      final stock = InventoryStock(cartons: 10, loosePieces: 0, piecesPerCarton: 48);
      final opened = stock.openCarton(1);

      expect(opened.cartons, 9);
      expect(opened.loosePieces, 48);
      expect(opened.totalPieces, 480, reason: 'Carton opening must not change total piece count');
    });

    test('Selling 1 piece leaves 9 cartons and 47 loose pieces', () {
      // Case A: From already opened carton
      final stockAlreadyOpened = InventoryStock(cartons: 9, loosePieces: 48, piecesPerCarton: 48);
      final afterSale = stockAlreadyOpened.deductPieces(1);
      expect(afterSale.cartons, 9);
      expect(afterSale.loosePieces, 47);
      expect(afterSale.totalPieces, 479);

      // Case B: Directly deducting 1 piece from 10 full cartons auto-opens 1 carton
      final stockFullCartons = InventoryStock(cartons: 10, loosePieces: 0, piecesPerCarton: 48);
      final autoOpenedSale = stockFullCartons.deductPieces(1);
      expect(autoOpenedSale.cartons, 9);
      expect(autoOpenedSale.loosePieces, 47);
      expect(autoOpenedSale.totalPieces, 479);
    });

    test('Selling 50 pieces from 10 cartons leaves 8 cartons and 46 loose pieces', () {
      final stock = InventoryStock(cartons: 10, loosePieces: 0, piecesPerCarton: 48);
      // 50 pieces requires opening 2 cartons (96 pieces).
      // Remaining cartons: 10 - 2 = 8 cartons.
      // Remaining loose: 96 - 50 = 46 loose pieces.
      // Total pieces: (8 * 48) + 46 = 384 + 46 = 430 pieces.
      final afterSale = stock.deductPieces(50);
      expect(afterSale.cartons, 8);
      expect(afterSale.loosePieces, 46);
      expect(afterSale.totalPieces, 430);
      expect(afterSale.totalPieces, stock.totalPieces - 50);
    });

    test('Selling exact full carton (48 pieces) when no loose pieces exist', () {
      final stock = InventoryStock(cartons: 5, loosePieces: 0, piecesPerCarton: 48);
      final afterSale = stock.deductPieces(48);
      expect(afterSale.cartons, 4);
      expect(afterSale.loosePieces, 0);
      expect(afterSale.totalPieces, 192);
    });

    test('Selling from existing loose pieces without breaking another carton', () {
      final stock = InventoryStock(cartons: 5, loosePieces: 10, piecesPerCarton: 48);
      final afterSale = stock.deductPieces(4);
      expect(afterSale.cartons, 5);
      expect(afterSale.loosePieces, 6);
      expect(afterSale.totalPieces, 246);
    });

    test('Cannot deduct more pieces than total inventory', () {
      final stock = InventoryStock(cartons: 1, loosePieces: 0, piecesPerCarton: 48);
      expect(() => stock.deductPieces(49), throwsStateError);
    });

    test('Inward stock addition normalizes excess loose pieces into cartons', () {
      final stock = InventoryStock(cartons: 2, loosePieces: 40, piecesPerCarton: 48);
      // Add 2 cartons and 10 loose pieces -> 4 cartons and 50 loose -> 5 cartons and 2 loose
      final replenished = stock.addStock(cartonsToAdd: 2, looseToAdd: 10);
      expect(replenished.cartons, 5);
      expect(replenished.loosePieces, 2);
      expect(replenished.totalPieces, (5 * 48) + 2);
    });
  });
}
