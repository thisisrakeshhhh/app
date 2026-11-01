/// Immutable inventory stock model supporting integer carton and loose-piece mathematics.
/// Zero floating-point calculations are used to guarantee precision in wholesale FMCG operations.
class InventoryStock {
  final int cartons;
  final int loosePieces;
  final int piecesPerCarton;

  const InventoryStock({
    required this.cartons,
    required this.loosePieces,
    required this.piecesPerCarton,
  })  : assert(cartons >= 0, 'Cartons cannot be negative'),
        assert(loosePieces >= 0, 'Loose pieces cannot be negative'),
        assert(piecesPerCarton > 0, 'Pieces per carton must be greater than zero');

  /// Total pieces available across unopened cartons and loose pieces
  int get totalPieces => (cartons * piecesPerCarton) + loosePieces;

  /// Whether sufficient stock is available to satisfy [requiredPieces]
  bool hasSufficientStock(int requiredPieces) {
    return requiredPieces >= 0 && totalPieces >= requiredPieces;
  }

  /// Opens [count] unopened carton(s) and converts them into loose pieces.
  /// Example: 10 cartons (48 pcs/carton) + 0 loose pieces -> open 1 carton ->
  /// 9 cartons and 48 loose pieces. Total pieces remain 480.
  InventoryStock openCarton([int count = 1]) {
    if (count <= 0) return this;
    if (cartons < count) {
      throw StateError('Cannot open $count carton(s): only $cartons carton(s) available in stock');
    }
    return InventoryStock(
      cartons: cartons - count,
      loosePieces: loosePieces + (count * piecesPerCarton),
      piecesPerCarton: piecesPerCarton,
    );
  }

  /// Deducts [piecesToDeduct] loose pieces.
  /// If insufficient loose pieces are open, cartons are automatically opened as needed.
  /// Example: 10 cartons (48 pcs/carton), 0 loose pieces:
  /// - Deduct 1 piece: Opens 1 carton -> 9 cartons, 47 loose pieces (479 total).
  /// - Deduct 50 pieces: Opens 2 cartons -> 8 cartons, 46 loose pieces (430 total).
  InventoryStock deductPieces(int piecesToDeduct) {
    if (piecesToDeduct < 0) {
      throw ArgumentError('Deduction cannot be negative: $piecesToDeduct');
    }
    if (piecesToDeduct == 0) return this;
    if (totalPieces < piecesToDeduct) {
      throw StateError(
        'Insufficient stock: requested $piecesToDeduct piece(s), but only $totalPieces piece(s) available'
      );
    }

    if (loosePieces >= piecesToDeduct) {
      return InventoryStock(
        cartons: cartons,
        loosePieces: loosePieces - piecesToDeduct,
        piecesPerCarton: piecesPerCarton,
      );
    }

    // Need more loose pieces than currently open: calculate how many cartons must be opened
    final deficit = piecesToDeduct - loosePieces;
    final cartonsToOpen = (deficit / piecesPerCarton).ceil();

    final remainingCartons = cartons - cartonsToOpen;
    final totalLooseAfterOpening = loosePieces + (cartonsToOpen * piecesPerCarton);
    final remainingLoose = totalLooseAfterOpening - piecesToDeduct;

    return InventoryStock(
      cartons: remainingCartons,
      loosePieces: remainingLoose,
      piecesPerCarton: piecesPerCarton,
    );
  }

  /// Adds [cartonsToAdd] unopened cartons and [looseToAdd] loose pieces into inventory (e.g. Inward GRN)
  InventoryStock addStock({int cartonsToAdd = 0, int looseToAdd = 0}) {
    if (cartonsToAdd < 0 || looseToAdd < 0) {
      throw ArgumentError('Added stock cannot be negative');
    }
    final totalLoose = loosePieces + looseToAdd;
    // Normalize if loose pieces exceed a full carton
    final normalizedCartons = cartons + cartonsToAdd + (totalLoose ~/ piecesPerCarton);
    final normalizedLoose = totalLoose % piecesPerCarton;

    return InventoryStock(
      cartons: normalizedCartons,
      loosePieces: normalizedLoose,
      piecesPerCarton: piecesPerCarton,
    );
  }

  @override
  String toString() => 'InventoryStock(cartons: $cartons, loose: $loosePieces, perCarton: $piecesPerCarton, totalPieces: $totalPieces)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryStock &&
          runtimeType == other.runtimeType &&
          cartons == other.cartons &&
          loosePieces == other.loosePieces &&
          piecesPerCarton == other.piecesPerCarton;

  @override
  int get hashCode => Object.hash(cartons, loosePieces, piecesPerCarton);
}
