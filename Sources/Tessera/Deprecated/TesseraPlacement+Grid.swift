// By Dennis Müller

import CoreGraphics
import Foundation

public extension PlacementModel {
  /// Configuration for grid placement.
  struct Grid: Hashable, Sendable {
    /// A rectangular subgrid definition in base grid coordinates.
    ///
    /// - Note: Invalid subgrids (negative origin, non-positive span, out of bounds, overlap, empty symbols)
    ///   are ignored by the placement engine.
    public struct Subgrid: Hashable, Sendable {
      /// Local lattice configuration used to subdivide this subgrid rectangle.
      public struct LocalGrid: Hashable, Sendable {
        /// The canonical local grid sizing definition.
        public var sizing: Grid.Sizing {
          didSet {
            let canonical = Grid.canonicalizedSizing(sizing)
            if canonical != sizing {
              sizing = canonical
            }
          }
        }

        /// Offset strategy applied within the local lattice.
        public var offsetStrategy: GridOffsetStrategy
        /// Symbol assignment order used within the local lattice.
        public var symbolOrder: GridSymbolOrder
        /// Optional local seed for deterministic random-based orders.
        public var seed: UInt64?

        /// Creates a local lattice definition for this subgrid.
        public init(
          sizing: Grid.Sizing,
          offsetStrategy: GridOffsetStrategy = .none,
          symbolOrder: GridSymbolOrder = .rowMajor,
          seed: UInt64? = nil,
        ) {
          self.sizing = Grid.canonicalizedSizing(sizing)
          self.offsetStrategy = offsetStrategy
          self.symbolOrder = symbolOrder
          self.seed = seed
        }
      }

      /// Zero-based origin of a subgrid rectangle in base grid coordinates.
      public struct Origin: Hashable, Sendable {
        /// Top row index (zero-based).
        public var row: Int
        /// Leading column index (zero-based).
        public var column: Int

        /// Creates a zero-based subgrid origin.
        public init(row: Int, column: Int) {
          self.row = row
          self.column = column
        }
      }

      /// Span of a subgrid rectangle in base grid cell counts.
      public struct Span: Hashable, Sendable {
        /// Number of rows covered by the subgrid.
        public var rows: Int
        /// Number of columns covered by the subgrid.
        public var columns: Int

        /// Creates a subgrid span.
        public init(rows: Int, columns: Int) {
          self.rows = rows
          self.columns = columns
        }
      }

      /// Zero-based origin of the subgrid rectangle in base grid coordinates.
      public var origin: Origin
      /// Size of the subgrid rectangle in base grid cell counts.
      public var span: Span
      /// Symbol identifiers dedicated to this subgrid.
      public var symbolIDs: [UUID]
      /// Symbol assignment order used when `grid` is `nil`.
      public var symbolOrder: GridSymbolOrder
      /// Optional subgrid-local seed used when `grid` is `nil`.
      public var seed: UInt64?
      /// Whether rendered subgrid content is clipped to the subgrid rectangle.
      public var clipsToBounds: Bool
      /// Optional local lattice definition.
      ///
      /// When present, Tessera subdivides this subgrid rectangle into its own local grid
      /// and places symbols using `grid.symbolOrder` and `grid.seed`.
      public var grid: LocalGrid?

      /// Creates a rectangular subgrid definition.
      ///
      /// - Parameters:
      ///   - origin: Top-leading origin in base grid coordinates.
      ///     Fixed-cell grids can expose negative coordinates when partially visible edge cells remain on-screen.
      ///   - span: Rectangle size in base grid cell counts.
      ///   - symbolIDs: Symbol identifiers dedicated to this subgrid.
      ///   - symbolOrder: Symbol assignment order used within this subgrid when `grid` is `nil`.
      ///   - seed: Optional subgrid-local seed used when `grid` is `nil`.
      ///   - clipsToBounds: Whether rendered subgrid content is clipped to the subgrid rectangle.
      ///   - grid: Optional local lattice definition used to subdivide the subgrid rectangle.
      ///     When present, `grid.symbolOrder` and `grid.seed` are used within the local lattice.
      public init(
        origin: Origin,
        span: Span,
        symbolIDs: [UUID],
        symbolOrder: GridSymbolOrder = .rowMajor,
        seed: UInt64? = nil,
        clipsToBounds: Bool = false,
        grid: LocalGrid? = nil,
      ) {
        self.origin = origin
        self.span = span
        self.symbolIDs = symbolIDs
        self.symbolOrder = symbolOrder
        self.seed = seed
        self.clipsToBounds = clipsToBounds
        self.grid = grid
      }

      /// Creates a rectangular subgrid definition.
      ///
      /// - Parameters:
      ///   - at: Top-leading origin in base grid coordinates.
      ///     Fixed-cell grids can expose negative coordinates when partially visible edge cells remain on-screen.
      ///   - spanning: Rectangle size in base grid cell counts.
      ///   - symbolIDs: Symbol identifiers dedicated to this subgrid.
      ///   - symbolOrder: Symbol assignment order used within this subgrid when `grid` is `nil`.
      ///   - seed: Optional subgrid-local seed used when `grid` is `nil`.
      ///   - clipsToBounds: Whether rendered subgrid content is clipped to the subgrid rectangle.
      ///   - grid: Optional local lattice definition used to subdivide the subgrid rectangle.
      ///     When present, `grid.symbolOrder` and `grid.seed` are used within the local lattice.
      public init(
        at origin: Origin,
        spanning span: Span,
        symbolIDs: [UUID],
        symbolOrder: GridSymbolOrder = .rowMajor,
        seed: UInt64? = nil,
        clipsToBounds: Bool = false,
        grid: LocalGrid? = nil,
      ) {
        self.init(
          origin: origin,
          span: span,
          symbolIDs: symbolIDs,
          symbolOrder: symbolOrder,
          seed: seed,
          clipsToBounds: clipsToBounds,
          grid: grid,
        )
      }

      public static func == (lhs: Subgrid, rhs: Subgrid) -> Bool {
        let lhsIdentity = lhs.identityConfiguration
        let rhsIdentity = rhs.identityConfiguration
        return lhs.origin == rhs.origin &&
          lhs.span == rhs.span &&
          lhs.symbolIDs == rhs.symbolIDs &&
          lhs.clipsToBounds == rhs.clipsToBounds &&
          lhsIdentity.symbolOrder == rhsIdentity.symbolOrder &&
          lhsIdentity.seed == rhsIdentity.seed &&
          lhs.grid == rhs.grid
      }

      public func hash(into hasher: inout Hasher) {
        let identity = identityConfiguration
        hasher.combine(origin)
        hasher.combine(span)
        hasher.combine(symbolIDs)
        hasher.combine(clipsToBounds)
        hasher.combine(identity.symbolOrder)
        hasher.combine(identity.seed)
        hasher.combine(grid)
      }

      private var identityConfiguration: (symbolOrder: GridSymbolOrder?, seed: UInt64?) {
        guard grid == nil else {
          return (nil, nil)
        }

        return (symbolOrder, seed)
      }
    }

    /// Grid sizing configuration.
    public enum Sizing: Hashable, Sendable {
      /// Resolves cell size by dividing the placement bounds into a fixed row and column count.
      case count(columns: Int, rows: Int)
      /// Preserves a fixed cell size and places the lattice origin at the provided top-left point.
      case fixed(cellSize: CGSize, origin: CGPoint = .zero)

      /// Convenience constructor for square cells.
      public static func square(
        _ side: Double,
        origin: CGPoint = .zero,
      ) -> Self {
        .fixed(
          cellSize: CGSize(width: side, height: side),
          origin: origin,
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

    /// The canonical grid sizing definition.
    public var sizing: Sizing {
      didSet {
        let canonical = Self.canonicalizedSizing(sizing)
        if canonical != sizing {
          sizing = canonical
        }
      }
    }

    /// Offset strategy applied to grid rows or columns.
    public var offsetStrategy: GridOffsetStrategy
    /// Order in which symbols are assigned to regular grid cells.
    public var symbolOrder: GridSymbolOrder
    /// Seed used to drive deterministic randomness for grid symbol assignment.
    ///
    /// This affects symbol orders that rely on randomness such as `.randomWeightedPerCell` and `.shuffle`.
    public var seed: UInt64
    /// Optional per-symbol phase offsets in grid cell units keyed by `TesseraSymbol.id`.
    ///
    /// The engine looks up the selected symbol's `id` for each cell and applies the matching phase (if present).
    /// Cells assigned to symbols without an entry use `.init(x: 0, y: 0)`.
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
    /// Optional rectangular subgrid definitions.
    ///
    /// Subgrid coordinates are interpreted against the resolved grid dimensions used for placement.
    /// Invalid, overlapping, or symbol-empty subgrids are ignored. When subgrids overlap, the first valid subgrid wins.
    public var subgrids: [Subgrid]

    /// Creates a grid placement configuration.
    /// - Parameters:
    ///   - sizing: Canonical grid sizing definition.
    ///   - offsetStrategy: Offset strategy applied to grid rows or columns.
    ///   - symbolOrder: Order in which symbols are assigned to regular grid cells.
    ///   - seed: Seed used to drive deterministic randomness for regular grid symbol assignment.
    ///   - symbolPhases: Optional per-symbol phase offsets keyed by symbol `id`.
    ///   - steering: Position-based steering controls for grid placement.
    ///   - showsGridOverlay: Whether to draw a debug overlay for the resolved grid.
    ///   - subgrids: Optional rectangular subgrid definitions.
    public init(
      sizing: Sizing,
      offsetStrategy: GridOffsetStrategy = .none,
      symbolOrder: GridSymbolOrder = .rowMajor,
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      symbolPhases: [UUID: SymbolPhase] = [:],
      steering: GridSteering = .none,
      showsGridOverlay: Bool = false,
      subgrids: [Subgrid] = [],
    ) {
      self.sizing = Self.canonicalizedSizing(sizing)
      self.offsetStrategy = offsetStrategy
      self.symbolOrder = symbolOrder
      self.seed = seed
      self.symbolPhases = Self.canonicalizedSymbolPhases(symbolPhases)
      self.steering = steering
      self.showsGridOverlay = showsGridOverlay
      self.subgrids = subgrids
    }

    private static func canonicalizedSymbolPhases(_ symbolPhases: [UUID: SymbolPhase]) -> [UUID: SymbolPhase] {
      symbolPhases.mapValues { phase in
        SymbolPhase(x: phase.x, y: phase.y)
      }
    }

    private static func canonicalizedSizing(_ sizing: Sizing) -> Sizing {
      switch sizing {
      case let .count(columns, rows):
        .count(
          columns: max(1, columns),
          rows: max(1, rows),
        )

      case let .fixed(cellSize, origin):
        .fixed(
          cellSize: CGSize(
            width: sanitizedCellDimension(cellSize.width),
            height: sanitizedCellDimension(cellSize.height),
          ),
          origin: CGPoint(
            x: sanitizedOriginComponent(origin.x),
            y: sanitizedOriginComponent(origin.y),
          ),
        )
      }
    }

    private static func sanitizedCellDimension(_ value: CGFloat) -> CGFloat {
      guard value.isFinite, value > 0 else { return 1 }

      return max(1, value)
    }

    private static func sanitizedOriginComponent(_ value: CGFloat) -> CGFloat {
      value.isFinite ? value : 0
    }
  }
}
