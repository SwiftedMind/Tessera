// By Dennis Müller

public extension TesseraPlacement {
  /// Offset strategies for grid placement.
  enum GridOffsetStrategy: Hashable, Sendable {
    /// No grid offsets.
    case none
    /// Offsets every other row horizontally by a fraction of the cell width.
    ///
    /// Values greater than 1 shift by whole cell widths (e.g. `2.5` shifts by 2½ cells).
    ///
    /// For predictable results, use finite values greater than or equal to 0.
    case rowShift(fraction: Double)
    /// Offsets every other column vertically by a fraction of the cell height.
    ///
    /// Values greater than 1 shift by whole cell heights (e.g. `2.5` shifts by 2½ cells).
    ///
    /// For predictable results, use finite values greater than or equal to 0.
    case columnShift(fraction: Double)
    /// Offsets alternating cells diagonally by a fraction of the cell size.
    ///
    /// Values greater than 1 shift by whole cell sizes (e.g. `2.5` shifts by 2½ cells).
    ///
    /// For predictable results, use finite values greater than or equal to 0.
    case checkerShift(fraction: Double)
  }

  /// Symbol assignment order for grid placement.
  enum GridSymbolOrder: Hashable, Sendable {
    /// Assign symbols in array order, repeating from the start as needed.
    case sequence
    /// Assign a random symbol to each cell, sampling using `TesseraSymbol.weight`.
    ///
    /// Each cell is sampled independently using a deterministic per-cell random seed derived from `Grid.seed`.
    case randomWeightedPerCell
    /// Assign symbols by shuffling a repeated symbol sequence to cover the whole grid.
    ///
    /// This tends to distribute symbols more evenly than pure per-cell randomness.
    case shuffle
    /// Assign symbols based on the sum of row and column indices, repeating from the start as needed.
    case diagonal
    /// Assign symbols row-major, reversing the symbol index progression on odd rows.
    case snake
  }
}
