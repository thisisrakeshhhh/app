/// Immutable inventory stock model supporting integer carton and loose-piece mathematics.
/// Zero floating-point calculations are used to guarantee precision in wholesale FMCG operations.
class InventoryStock {
  final int cartons;
  final int loosePieces;
  final int piecesPerCarton;
  final int reservedCartons;
  final int reservedLoosePieces;

  const InventoryStock({
    required this.cartons,
    required this.loosePieces,
    required this.piecesPerCarton,
    this.reservedCartons = 0,
    this.reservedLoosePieces = 0,
  })  : assert(cartons >= 0, 'Cartons cannot be negative'),
        assert(loosePieces >= 0, 'Loose pieces cannot be negative'),
        assert(piecesPerCarton > 0, 'Pieces per carton must be greater than zero'),
        assert(reservedCartons >= 0, 'Reserved cartons cannot be negative'),
        assert(reservedLoosePieces >= 0, 'Reserved loose pieces cannot be negative');

  /// Total physical pieces across unopened cartons and loose pieces
  int get physicalPieces => (cartons * piecesPerCarton) + loosePieces;

  /// Alias for physicalPieces to maintain backward compatibility
  int get totalPieces => physicalPieces;

  /// Total reserved pieces across reserved cartons and loose pieces
  int get reservedPieces => (reservedCartons * piecesPerCarton) + reservedLoosePieces;

  /// Available pieces that can be sold or reserved without overselling:
  /// Available Stock = Physical Stock - Reserved Stock (clamped at 0)
  int get availablePieces {
    final net = physicalPieces - reservedPieces;
    return net > 0 ? net : 0;
  }

  /// Available unopened full cartons
  int get availableCartons => availablePieces ~/ piecesPerCarton;

  /// Available loose pieces after full cartons
  int get availableLoosePieces => availablePieces % piecesPerCarton;

  /// Physical full cartons (including normalized loose pieces if loose >= piecesPerCarton)
  int get normalizedPhysicalCartons => cartons + (loosePieces ~/ piecesPerCarton);

  /// Physical loose pieces normalized to < piecesPerCarton
  int get normalizedPhysicalLoose => loosePieces % piecesPerCarton;

  /// Reserved full cartons normalized
  int get normalizedReservedCartons => reservedCartons + (reservedLoosePieces ~/ piecesPerCarton);

  /// Reserved loose pieces normalized to < piecesPerCarton
  int get normalizedReservedLoose => reservedLoosePieces % piecesPerCarton;

  /// Whether sufficient available (unreserved) stock is available to satisfy [requiredPieces]
  bool hasSufficientStock(int requiredPieces) {
    return requiredPieces >= 0 && availablePieces >= requiredPieces;
  }

  /// Whether sufficient physical stock exists regardless of reservations
  bool hasSufficientPhysicalStock(int requiredPieces) {
    return requiredPieces >= 0 && physicalPieces >= requiredPieces;
  }

  /// Reserves [piecesToReserve] units from available stock.
  /// Throws [StateError] if available stock is insufficient.
  InventoryStock reservePieces(int piecesToReserve) {
    if (piecesToReserve < 0) {
      throw ArgumentError('Reservation cannot be negative: $piecesToReserve');
    }
    if (piecesToReserve == 0) return this;
    if (availablePieces < piecesToReserve) {
      throw StateError(
        'Insufficient available stock: requested $piecesToReserve piece(s), but only $availablePieces available '
        '(physical: $physicalPieces, reserved: $reservedPieces)',
      );
    }

    final newTotalReserved = reservedPieces + piecesToReserve;
    return InventoryStock(
      cartons: cartons,
      loosePieces: loosePieces,
      piecesPerCarton: piecesPerCarton,
      reservedCartons: newTotalReserved ~/ piecesPerCarton,
      reservedLoosePieces: newTotalReserved % piecesPerCarton,
    );
  }

  /// Releases [piecesToRelease] previously reserved units back to available stock.
  /// Throws [StateError] if releasing more pieces than are currently reserved.
  InventoryStock releaseReservation(int piecesToRelease) {
    if (piecesToRelease < 0) {
      throw ArgumentError('Released pieces cannot be negative: $piecesToRelease');
    }
    if (piecesToRelease == 0) return this;
    if (reservedPieces < piecesToRelease) {
      throw StateError(
        'Cannot release $piecesToRelease piece(s): only $reservedPieces piece(s) currently reserved',
      );
    }

    final newTotalReserved = reservedPieces - piecesToRelease;
    return InventoryStock(
      cartons: cartons,
      loosePieces: loosePieces,
      piecesPerCarton: piecesPerCarton,
      reservedCartons: newTotalReserved ~/ piecesPerCarton,
      reservedLoosePieces: newTotalReserved % piecesPerCarton,
    );
  }

  /// Commits and deducts [piecesToDeduct] reserved units upon order fulfillment/dispatch.
  /// Both physical stock and reserved stock are decremented.
  InventoryStock commitAndDeductReserved(int piecesToDeduct) {
    if (piecesToDeduct < 0) {
      throw ArgumentError('Committed deduction cannot be negative: $piecesToDeduct');
    }
    if (piecesToDeduct == 0) return this;
    if (reservedPieces < piecesToDeduct) {
      throw StateError(
        'Cannot commit $piecesToDeduct piece(s): only $reservedPieces piece(s) currently reserved',
      );
    }

    // Deduct physical stock
    final updatedPhysical = deductPieces(piecesToDeduct);

    // Decrement reserved stock
    final newTotalReserved = reservedPieces - piecesToDeduct;
    return InventoryStock(
      cartons: updatedPhysical.cartons,
      loosePieces: updatedPhysical.loosePieces,
      piecesPerCarton: piecesPerCarton,
      reservedCartons: newTotalReserved ~/ piecesPerCarton,
      reservedLoosePieces: newTotalReserved % piecesPerCarton,
    );
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
      reservedCartons: reservedCartons,
      reservedLoosePieces: reservedLoosePieces,
    );
  }

  /// Deducts [piecesToDeduct] loose pieces from physical stock.
  /// If insufficient loose pieces are open, cartons are automatically opened as needed.
  InventoryStock deductPieces(int piecesToDeduct) {
    if (piecesToDeduct < 0) {
      throw ArgumentError('Deduction cannot be negative: $piecesToDeduct');
    }
    if (piecesToDeduct == 0) return this;
    if (physicalPieces < piecesToDeduct) {
      throw StateError(
        'Insufficient stock: requested $piecesToDeduct piece(s), but only $physicalPieces piece(s) available',
      );
    }

    if (loosePieces >= piecesToDeduct) {
      return InventoryStock(
        cartons: cartons,
        loosePieces: loosePieces - piecesToDeduct,
        piecesPerCarton: piecesPerCarton,
        reservedCartons: reservedCartons,
        reservedLoosePieces: reservedLoosePieces,
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
      reservedCartons: reservedCartons,
      reservedLoosePieces: reservedLoosePieces,
    );
  }

  /// Adds [cartonsToAdd] unopened cartons and [looseToAdd] loose pieces into physical inventory (e.g. Inward GRN)
  InventoryStock addStock({int cartonsToAdd = 0, int looseToAdd = 0}) {
    if (cartonsToAdd < 0 || looseToAdd < 0) {
      throw ArgumentError('Added stock cannot be negative');
    }
    final totalLoose = loosePieces + looseToAdd;
    final normalizedCartons = cartons + cartonsToAdd + (totalLoose ~/ piecesPerCarton);
    final normalizedLoose = totalLoose % piecesPerCarton;

    return InventoryStock(
      cartons: normalizedCartons,
      loosePieces: normalizedLoose,
      piecesPerCarton: piecesPerCarton,
      reservedCartons: reservedCartons,
      reservedLoosePieces: reservedLoosePieces,
    );
  }

  /// Adjusts physical stock (audit reconciliation).
  /// Ensures physical stock does not fall below reserved stock.
  InventoryStock adjustStock({int cartonDelta = 0, int loosePieceDelta = 0}) {
    final netPhysicalDelta = (cartonDelta * piecesPerCarton) + loosePieceDelta;
    final newPhysicalPieces = physicalPieces + netPhysicalDelta;
    if (newPhysicalPieces < 0) {
      throw StateError('Stock adjustment would result in negative physical stock ($newPhysicalPieces)');
    }
    if (newPhysicalPieces < reservedPieces) {
      throw StateError(
        'Stock adjustment would cause physical stock ($newPhysicalPieces) to be less than reserved stock ($reservedPieces)',
      );
    }

    final newCartons = newPhysicalPieces ~/ piecesPerCarton;
    final newLoose = newPhysicalPieces % piecesPerCarton;

    return InventoryStock(
      cartons: newCartons,
      loosePieces: newLoose,
      piecesPerCarton: piecesPerCarton,
      reservedCartons: reservedCartons,
      reservedLoosePieces: reservedLoosePieces,
    );
  }

  @override
  String toString() =>
      'InventoryStock(cartons: $cartons, loose: $loosePieces, perCarton: $piecesPerCarton, physical: $physicalPieces, reserved: $reservedPieces, available: $availablePieces)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryStock &&
          runtimeType == other.runtimeType &&
          cartons == other.cartons &&
          loosePieces == other.loosePieces &&
          piecesPerCarton == other.piecesPerCarton &&
          reservedCartons == other.reservedCartons &&
          reservedLoosePieces == other.reservedLoosePieces;

  @override
  int get hashCode => Object.hash(cartons, loosePieces, piecesPerCarton, reservedCartons, reservedLoosePieces);
}
