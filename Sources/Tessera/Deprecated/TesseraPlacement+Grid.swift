// By Dennis Müller

import Foundation

public extension TesseraPlacement {
  /// Configuration for grid placement.
  struct Grid: Hashable, Sendable {
    /// Per-symbol phase offset in grid cell units.
    ///
    /// Values are applied relative to each resolved grid cell center.
    /// For example, `x: 0.5` shifts the symbol by half a cell width.
    ///
    /// Non-finite values are sanitized to `0`.
    public struct SymbolPhase: Hashable, Sendable {
      /// Horizontal phase offset in cell widths.
      public var x: Double { didSet { x = Self.sanitizedComponent(x) } }
      /// Vertical phase offset in cell heights.
      public var y: Double { didSet { y = Self.sanitizedComponent(y) } }

      /// Creates a phase offset in grid cell units.
      ///
      /// - Parameters:
      ///   - x: Horizontal phase in cell widths.
      ///   - y: Vertical phase in cell heights.
      ///
      /// Example:
      /// ```swift
      /// .init(x: 0.5, y: 0.5) // half-cell shift on both axes
      /// ```
      public init(x: Double, y: Double) {
        self.x = Self.sanitizedComponent(x)
        self.y = Self.sanitizedComponent(y)
      }

      private static func sanitizedComponent(_ value: Double) -> Double {
        value.isFinite ? value : 0
      }
    }

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
    /// Optional per-symbol phase offsets in grid cell units keyed by `TesseraSymbol.id`.
    ///
    /// The engine looks up the selected symbol's `id` for each cell and applies the matching phase (if present).
    /// Cells assigned to symbols without an entry use `.init(x: 0, y: 0)`.
    ///
    /// This is useful for interleaved motifs or nudging one symbol family relative to others.
    ///
    /// Example:
    /// ```swift
    /// let primaryID = UUID()
    /// let secondaryID = UUID()
    /// let phases: [UUID: TesseraPlacement.Grid.SymbolPhase] = [
    ///   secondaryID: .init(x: 0.5, y: 0.5),
    /// ]
    /// ```
    ///
    /// Important: a single grid pass still chooses one symbol per cell.
    /// To render two full lattices on top of each other, overlay two Tessera layers.
    public var symbolPhases: [UUID: SymbolPhase] {
      didSet {
        let canonical = Self.canonicalizedSymbolPhases(symbolPhases)
        if canonical != symbolPhases {
          symbolPhases = canonical
        }
      }
    }

    /// Position-based steering controls.
    public var steering: GridSteering

    /// Creates a grid placement configuration.
    /// - Parameters:
    ///   - columnCount: The number of columns in the grid.
    ///   - rowCount: The number of rows in the grid.
    ///   - offsetStrategy: Offset strategy applied to grid rows or columns.
    ///   - symbolOrder: Order in which symbols are assigned to grid cells.
    ///   - seed: Seed used to drive deterministic randomness for grid symbol assignment.
    ///   - symbolPhases: Optional per-symbol phase offsets keyed by symbol `id`.
    ///     Use this when a symbol family needs a deterministic phase shift (for example `0.5, 0.5`).
    ///   - steering: Position-based steering controls for grid placement.
    public init(
      columnCount: Int,
      rowCount: Int,
      offsetStrategy: GridOffsetStrategy = .none,
      symbolOrder: GridSymbolOrder = .sequence,
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      symbolPhases: [UUID: SymbolPhase] = [:],
      steering: GridSteering = .none,
    ) {
      self.columnCount = columnCount
      self.rowCount = rowCount
      self.offsetStrategy = offsetStrategy
      self.symbolOrder = symbolOrder
      self.seed = seed
      self.symbolPhases = Self.canonicalizedSymbolPhases(symbolPhases)
      self.steering = steering
    }

    private static func canonicalizedSymbolPhases(_ symbolPhases: [UUID: SymbolPhase]) -> [UUID: SymbolPhase] {
      symbolPhases.mapValues { phase in
        SymbolPhase(x: phase.x, y: phase.y)
      }
    }
  }
}
