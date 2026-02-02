// By Dennis Müller

import SwiftUI

/// Describes how Tessera chooses symbol positions.
public enum TesseraPlacement: Hashable, Sendable {
  /// Evenly spaced, organic placement using wrap-aware rejection sampling.
  case organic(Organic)
  /// Grid-based placement with optional offsets between rows or columns.
  case grid(Grid)

  /// Configuration for organic placement.
  public struct Organic: Hashable, Sendable {
    /// Seed for deterministic randomness. Defaults to a random seed.
    public var seed: UInt64
    /// Minimum distance between symbol centers.
    public var minimumSpacing: Double
    /// Desired fill density between 0 and 1.
    public var density: Double
    /// Default scale range applied when a symbol does not provide its own scale range.
    public var baseScaleRange: ClosedRange<Double>
    /// Upper bound on how many generated symbols may be placed.
    public var maximumSymbolCount: Int
    /// Whether to render a debug overlay for collision shapes in on-screen canvases.
    ///
    /// Exported renders ignore this setting unless `TesseraRenderOptions.showsCollisionOverlay` is enabled.
    public var showsCollisionOverlay: Bool

    /// Creates an organic placement configuration.
    /// - Parameters:
    ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
    ///   - minimumSpacing: Minimum distance between symbol centers.
    ///   - density: Desired fill density between 0 and 1.
    ///   - baseScaleRange: Default scale range applied when a symbol does not provide its own scale range.
    ///   - maximumSymbolCount: Upper bound on how many generated symbols may be placed.
    ///   - showsCollisionOverlay: Whether to render a debug overlay for collision shapes in on-screen canvases.
    public init(
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      minimumSpacing: Double,
      density: Double = 0.5,
      baseScaleRange: ClosedRange<Double> = 0.9...1.1,
      maximumSymbolCount: Int = 512,
      showsCollisionOverlay: Bool = false,
    ) {
      self.seed = seed
      self.minimumSpacing = minimumSpacing
      self.density = density
      self.baseScaleRange = baseScaleRange
      self.maximumSymbolCount = maximumSymbolCount
      self.showsCollisionOverlay = showsCollisionOverlay
    }
  }

  /// Configuration for grid placement.
  public struct Grid: Hashable, Sendable {
    /// The number of columns in the grid.
    ///
    /// The engine may round up to an even value when seamless wrapping and non-zero offset strategies require it.
    public var columnCount: Int
    /// The number of rows in the grid.
    ///
    /// The engine may round up to an even value when seamless wrapping and non-zero offset strategies require it.
    public var rowCount: Int
    /// Offset strategy applied to grid rows or columns.
    public var offsetStrategy: GridOffsetStrategy
    /// Order in which symbols are assigned to grid cells.
    public var symbolOrder: GridSymbolOrder
    /// Seed used to drive deterministic randomness for grid symbol assignment.
    ///
    /// This affects symbol orders that rely on randomness such as `.randomWeightedPerCell` and `.shuffle`.
    public var seed: UInt64

    /// Creates a grid placement configuration.
    /// - Parameters:
    ///   - columnCount: The number of columns in the grid.
    ///   - rowCount: The number of rows in the grid.
    ///   - offsetStrategy: Offset strategy applied to grid rows or columns.
    ///   - symbolOrder: Order in which symbols are assigned to grid cells.
    ///   - seed: Seed used to drive deterministic randomness for grid symbol assignment.
    public init(
      columnCount: Int,
      rowCount: Int,
      offsetStrategy: GridOffsetStrategy = .none,
      symbolOrder: GridSymbolOrder = .sequence,
      seed: UInt64 = TesseraConfiguration.randomSeed(),
    ) {
      self.columnCount = columnCount
      self.rowCount = rowCount
      self.offsetStrategy = offsetStrategy
      self.symbolOrder = symbolOrder
      self.seed = seed
    }
  }

  /// Offset strategies for grid placement.
  public enum GridOffsetStrategy: Hashable, Sendable {
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
  public enum GridSymbolOrder: Hashable, Sendable {
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
