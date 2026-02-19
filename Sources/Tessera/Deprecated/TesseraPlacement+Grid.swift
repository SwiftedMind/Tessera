// By Dennis Müller

import Foundation

public extension PlacementModel {
  /// Configuration for grid placement.
  struct Grid: Hashable, Sendable {
    /// Symbol sizing behavior for merged-cell symbol overrides.
    public enum MergedCellSymbolSizing: Hashable, Sendable {
      /// Keep symbol scale behavior unchanged.
      case natural
      /// Scales the symbol to fit inside the merged cell using collision-shape bounds.
      case fitMergedCell
    }

    /// A rectangular merged cell definition in base grid coordinates.
    ///
    /// - Note: Invalid merges (negative origin, non-positive span, out of bounds, overlap)
    ///   are ignored by the placement engine.
    public struct CellMerge: Hashable, Sendable {
      /// Zero-based origin of a merged rectangle in base grid coordinates.
      public struct Origin: Hashable, Sendable {
        /// Top row index (zero-based).
        public var row: Int
        /// Leading column index (zero-based).
        public var column: Int

        /// Creates a zero-based merged-cell origin.
        public init(row: Int, column: Int) {
          self.row = row
          self.column = column
        }
      }

      /// Span of a merged rectangle in base grid cell counts.
      public struct Span: Hashable, Sendable {
        /// Number of rows to merge.
        public var rows: Int
        /// Number of columns to merge.
        public var columns: Int

        /// Creates a merged-cell span.
        public init(rows: Int, columns: Int) {
          self.rows = rows
          self.columns = columns
        }
      }

      /// Zero-based origin of the merged rectangle in base grid coordinates.
      public var origin: Origin
      /// Size of the merged rectangle in base grid cell counts.
      public var span: Span
      /// Optional symbol identifier used specifically for this merged cell.
      ///
      /// When `nil`, the merged cell uses regular grid symbol assignment.
      public var symbolID: UUID?
      /// Symbol sizing behavior for this merged cell.
      public var symbolSizing: MergedCellSymbolSizing

      /// Creates a rectangular merged-cell definition.
      ///
      /// - Parameters:
      ///   - origin: Zero-based top-leading origin in base grid coordinates.
      ///   - span: Rectangle size in base grid cell counts.
      ///   - symbolID: Optional symbol identifier used specifically for this merged cell.
      ///   - symbolSizing: Symbol sizing behavior for this merged cell.
      public init(
        origin: Origin,
        span: Span,
        symbolID: UUID? = nil,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.origin = origin
        self.span = span
        self.symbolID = symbolID
        self.symbolSizing = symbolSizing
      }

      /// Creates a rectangular merged-cell definition.
      ///
      /// - Parameters:
      ///   - at: Zero-based top-leading origin in base grid coordinates.
      ///   - spanning: Rectangle size in base grid cell counts.
      ///   - symbolID: Optional symbol identifier used specifically for this merged cell.
      ///   - symbolSizing: Symbol sizing behavior for this merged cell.
      public init(
        at origin: Origin,
        spanning span: Span,
        symbolID: UUID? = nil,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.init(
          origin: origin,
          span: span,
          symbolID: symbolID,
          symbolSizing: symbolSizing,
        )
      }
    }

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
    /// Important: a single grid pass still chooses one symbol per resolved placement cell.
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
    /// Whether to draw a debug overlay for the resolved grid.
    public var showsGridOverlay: Bool
    /// Optional merged-cell rectangles.
    ///
    /// Merge coordinates are interpreted against the resolved grid dimensions used for placement.
    /// Invalid or overlapping merges are ignored. When merges overlap, the first valid merge wins.
    public var mergedCells: [CellMerge]
    /// Whether symbol IDs referenced by `mergedCells.symbolID` should be excluded from regular-cell assignment.
    public var excludeMergedSymbolsFromRegularCells: Bool

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
    ///   - showsGridOverlay: Whether to draw a debug overlay for the resolved grid.
    ///   - mergedCells: Optional rectangular merged-cell definitions.
    ///   - excludeMergedSymbolsFromRegularCells: Whether merged-cell override symbols should be excluded from regular
    ///     grid assignment.
    public init(
      columnCount: Int,
      rowCount: Int,
      offsetStrategy: GridOffsetStrategy = .none,
      symbolOrder: GridSymbolOrder = .rowMajor,
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      symbolPhases: [UUID: SymbolPhase] = [:],
      steering: GridSteering = .none,
      showsGridOverlay: Bool = false,
      mergedCells: [CellMerge] = [],
      excludeMergedSymbolsFromRegularCells: Bool = true,
    ) {
      self.columnCount = columnCount
      self.rowCount = rowCount
      self.offsetStrategy = offsetStrategy
      self.symbolOrder = symbolOrder
      self.seed = seed
      self.symbolPhases = Self.canonicalizedSymbolPhases(symbolPhases)
      self.steering = steering
      self.showsGridOverlay = showsGridOverlay
      self.mergedCells = mergedCells
      self.excludeMergedSymbolsFromRegularCells = excludeMergedSymbolsFromRegularCells
    }

    private static func canonicalizedSymbolPhases(_ symbolPhases: [UUID: SymbolPhase]) -> [UUID: SymbolPhase] {
      symbolPhases.mapValues { phase in
        SymbolPhase(x: phase.x, y: phase.y)
      }
    }
  }
}
