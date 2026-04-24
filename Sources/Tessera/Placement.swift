// By Dennis Müller

import CoreGraphics
import Foundation

/// Primary placement API for Tessera v4.
///
/// This public surface keeps authoring ergonomic while still resolving to the internal
/// engine-facing `PlacementModel` at render time.
public enum TesseraPlacement: Sendable {
  /// Organic placement configuration type.
  public typealias Organic = PlacementModel.Organic
  /// Grid row/column offset strategy.
  public typealias GridOffsetStrategy = PlacementModel.GridOffsetStrategy
  /// Grid symbol assignment strategy.
  public typealias GridSymbolOrder = PlacementModel.GridSymbolOrder
  /// Grid steering controls.
  public typealias GridSteering = PlacementModel.GridSteering
  /// Organic steering controls.
  public typealias OrganicSteering = PlacementModel.OrganicSteering
  /// Organic fill algorithm.
  public typealias OrganicFillStrategy = PlacementModel.OrganicFillStrategy
  /// Shared steering field type.
  public typealias SteeringField = PlacementModel.SteeringField

  /// Organic placement.
  case organic(Organic)
  /// Grid placement.
  case grid(Grid)

  /// Public grid placement options.
  ///
  /// Grid option fields are forwarded to `base` so we keep a single source of truth for
  /// engine-facing placement behavior (`PlacementModel.Grid`), while subgrid authoring
  /// overlays can carry inline symbol definitions.
  public struct Grid: Sendable {
    /// Alias for `PlacementModel.Grid.Sizing`.
    public typealias Sizing = PlacementModel.Grid.Sizing
    /// Alias for `PlacementModel.Grid.SymbolPhase`.
    public typealias SymbolPhase = PlacementModel.Grid.SymbolPhase
    /// Alias for `PlacementModel.Grid.Subgrid.Origin`.
    public typealias Origin = PlacementModel.Grid.Subgrid.Origin
    /// Alias for `PlacementModel.Grid.Subgrid.Span`.
    public typealias Span = PlacementModel.Grid.Subgrid.Span

    /// Public subgrid configuration for grid placement.
    public struct Subgrid: Hashable, Sendable {
      /// Public local lattice configuration for a subgrid rectangle.
      public struct LocalGrid: Hashable, Sendable {
        /// Alias for `PlacementModel.Grid.Sizing`.
        public typealias Sizing = PlacementModel.Grid.Sizing

        /// The canonical local grid sizing definition.
        public var sizing: Sizing {
          didSet {
            let canonical = Self.canonicalizedSizing(sizing)
            if canonical != sizing {
              sizing = canonical
            }
          }
        }

        /// Offset strategy applied within the local lattice.
        public var offsetStrategy: GridOffsetStrategy
        /// Symbol assignment order used within the local lattice.
        public var symbolOrder: GridSymbolOrder
        /// Optional local seed used for deterministic random-based orders.
        public var seed: UInt64?

        /// Creates a local lattice definition for this subgrid.
        public init(
          sizing: Sizing,
          offsetStrategy: GridOffsetStrategy = .none,
          symbolOrder: GridSymbolOrder = .rowMajor,
          seed: UInt64? = nil,
        ) {
          self.sizing = Self.canonicalizedSizing(sizing)
          self.offsetStrategy = offsetStrategy
          self.symbolOrder = symbolOrder
          self.seed = seed
        }

        init(internalLocalGrid: PlacementModel.Grid.Subgrid.LocalGrid) {
          sizing = internalLocalGrid.sizing
          offsetStrategy = internalLocalGrid.offsetStrategy
          symbolOrder = internalLocalGrid.symbolOrder
          seed = internalLocalGrid.seed
        }

        var internalLocalGrid: PlacementModel.Grid.Subgrid.LocalGrid {
          PlacementModel.Grid.Subgrid.LocalGrid(
            sizing: sizing,
            offsetStrategy: offsetStrategy,
            symbolOrder: symbolOrder,
            seed: seed,
          )
        }

        private static func canonicalizedSizing(_ sizing: Sizing) -> Sizing {
          PlacementModel.Grid.Subgrid.LocalGrid(sizing: sizing).sizing
        }
      }

      /// Top-leading origin in base grid coordinates.
      ///
      /// Count-sized grids use zero-based coordinates. Fixed-cell grids may use negative
      /// coordinates when the grid origin is offset and partially visible edge cells appear.
      public var origin: Origin
      /// Rectangle size in base grid cell counts.
      public var span: Span
      /// Symbols dedicated to this subgrid.
      ///
      /// When this subgrid originates from an internal ID-backed definition (`Grid(base:)`),
      /// imported IDs remain part of the resolved symbol set and these inline symbols are appended.
      public var symbols: [Symbol]

      /// Symbol assignment order used when `grid` is `nil`.
      public var symbolOrder: GridSymbolOrder
      /// Optional seed used when `grid` is `nil`.
      public var seed: UInt64?
      /// Whether rendered subgrid content is clipped to the subgrid rectangle.
      public var clipsToBounds: Bool
      /// Optional local lattice definition used to subdivide this subgrid rectangle.
      public var grid: LocalGrid?

      var resolvedSymbolIDs: [UUID] {
        Self.uniqueSymbolIDs(from: importedSymbolIDs + symbols.map(\.id))
      }

      private var importedSymbolIDs: [UUID]

      /// Creates a subgrid definition.
      ///
      /// - Parameters:
      ///   - origin: Top-leading origin in base grid coordinates.
      ///     Count-sized grids use zero-based coordinates. Fixed-cell grids may use negative
      ///     coordinates when the grid origin is offset and partially visible edge cells appear.
      ///   - span: Rectangle size in base grid cell counts.
      ///   - symbols: Symbols dedicated to this subgrid.
      ///   - symbolOrder: Symbol assignment order used within this subgrid when `grid` is `nil`.
      ///   - seed: Optional subgrid seed used when `grid` is `nil`.
      ///   - clipsToBounds: Whether rendered subgrid content is clipped to the subgrid rectangle.
      ///   - grid: Optional local lattice definition used to subdivide the subgrid rectangle.
      ///     When present, `grid.symbolOrder` and `grid.seed` are used within the local lattice.
      public init(
        origin: Origin,
        span: Span,
        symbols: [Symbol],
        symbolOrder: GridSymbolOrder = .rowMajor,
        seed: UInt64? = nil,
        clipsToBounds: Bool = false,
        grid: LocalGrid? = nil,
      ) {
        self.origin = origin
        self.span = span
        self.symbols = symbols
        self.symbolOrder = symbolOrder
        self.seed = seed
        self.clipsToBounds = clipsToBounds
        self.grid = grid
        importedSymbolIDs = []
      }

      /// Creates a subgrid definition.
      ///
      /// - Parameters:
      ///   - at: Top-leading origin in base grid coordinates.
      ///     Count-sized grids use zero-based coordinates. Fixed-cell grids may use negative
      ///     coordinates when the grid origin is offset and partially visible edge cells appear.
      ///   - spanning: Rectangle size in base grid cell counts.
      ///   - symbols: Symbols dedicated to this subgrid.
      ///   - symbolOrder: Symbol assignment order used within this subgrid when `grid` is `nil`.
      ///   - seed: Optional subgrid seed used when `grid` is `nil`.
      ///   - clipsToBounds: Whether rendered subgrid content is clipped to the subgrid rectangle.
      ///   - grid: Optional local lattice definition used to subdivide the subgrid rectangle.
      ///     When present, `grid.symbolOrder` and `grid.seed` are used within the local lattice.
      public init(
        at origin: Origin,
        spanning span: Span,
        symbols: [Symbol],
        symbolOrder: GridSymbolOrder = .rowMajor,
        seed: UInt64? = nil,
        clipsToBounds: Bool = false,
        grid: LocalGrid? = nil,
      ) {
        self.init(
          origin: origin,
          span: span,
          symbols: symbols,
          symbolOrder: symbolOrder,
          seed: seed,
          clipsToBounds: clipsToBounds,
          grid: grid,
        )
      }

      /// Convenience initializer with explicit zero-based coordinates and span counts.
      public init(
        row: Int,
        column: Int,
        rows: Int,
        columns: Int,
        symbols: [Symbol],
        symbolOrder: GridSymbolOrder = .rowMajor,
        seed: UInt64? = nil,
        clipsToBounds: Bool = false,
        grid: LocalGrid? = nil,
      ) {
        self.init(
          origin: .init(row: row, column: column),
          span: .init(rows: rows, columns: columns),
          symbols: symbols,
          symbolOrder: symbolOrder,
          seed: seed,
          clipsToBounds: clipsToBounds,
          grid: grid,
        )
      }

      init(internalSubgrid: PlacementModel.Grid.Subgrid) {
        origin = internalSubgrid.origin
        span = internalSubgrid.span
        symbols = []
        symbolOrder = internalSubgrid.symbolOrder
        seed = internalSubgrid.seed
        clipsToBounds = internalSubgrid.clipsToBounds
        grid = internalSubgrid.grid.map(LocalGrid.init(internalLocalGrid:))
        importedSymbolIDs = Self.uniqueSymbolIDs(from: internalSubgrid.symbolIDs)
      }

      public static func == (lhs: Subgrid, rhs: Subgrid) -> Bool {
        let lhsIdentity = lhs.identityConfiguration
        let rhsIdentity = rhs.identityConfiguration
        return lhs.origin == rhs.origin &&
          lhs.span == rhs.span &&
          lhs.clipsToBounds == rhs.clipsToBounds &&
          lhsIdentity.symbolOrder == rhsIdentity.symbolOrder &&
          lhsIdentity.seed == rhsIdentity.seed &&
          lhs.grid == rhs.grid &&
          lhs.resolvedSymbolIDs == rhs.resolvedSymbolIDs
      }

      public func hash(into hasher: inout Hasher) {
        let identity = identityConfiguration
        hasher.combine(origin)
        hasher.combine(span)
        hasher.combine(clipsToBounds)
        hasher.combine(identity.symbolOrder)
        hasher.combine(identity.seed)
        hasher.combine(grid)
        hasher.combine(resolvedSymbolIDs)
      }

      private var identityConfiguration: (symbolOrder: GridSymbolOrder?, seed: UInt64?) {
        guard grid == nil else {
          return (nil, nil)
        }

        return (symbolOrder, seed)
      }

      private static func uniqueSymbolIDs(from symbolIDs: [UUID]) -> [UUID] {
        var seenSymbolIDs: Set<UUID> = []
        var uniqueSymbolIDs: [UUID] = []
        uniqueSymbolIDs.reserveCapacity(symbolIDs.count)
        for symbolID in symbolIDs where seenSymbolIDs.insert(symbolID).inserted {
          uniqueSymbolIDs.append(symbolID)
        }
        return uniqueSymbolIDs
      }
    }

    /// Backing engine-facing grid options.
    ///
    /// This stays ID-based and Hashable/Sendable for deterministic placement internals.
    var base: PlacementModel.Grid
    /// Optional subgrid rectangles in base-grid coordinates.
    ///
    /// Subgrids are validated against the resolved grid dimensions used for placement.
    /// Invalid or overlapping subgrids are ignored at placement time (first valid subgrid wins).
    public var subgrids: [Subgrid]

    /// Creates public grid options from an internal grid base.
    ///
    /// - Parameters:
    ///   - base: Engine-facing grid options.
    ///   - subgrids: Optional authoring subgrids. When omitted, values are imported from `base` as ID-backed
    ///     subgrid placeholders.
    public init(
      base: PlacementModel.Grid,
      subgrids: [Subgrid]? = nil,
    ) {
      self.base = base
      self.subgrids = subgrids ?? base.subgrids.map(Subgrid.init(internalSubgrid:))
    }

    /// Creates grid placement configuration.
    ///
    /// - Parameters:
    ///   - sizing: Canonical grid sizing definition.
    ///   - offsetStrategy: Offset strategy applied to grid rows or columns.
    ///   - symbolOrder: Order in which symbols are assigned to regular grid cells.
    ///   - seed: Seed used for deterministic grid assignment.
    ///   - symbolPhases: Optional per-symbol phase offsets keyed by `Symbol.id`.
    ///   - steering: Position-based steering controls.
    ///   - showsGridOverlay: Whether to draw a debug overlay for the resolved grid.
    ///   - subgrids: Optional subgrid definitions in base-grid coordinates.
    ///     Fixed-cell grids can expose negative coordinates when partially visible edge cells remain on-screen.
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
      base = PlacementModel.Grid(
        sizing: sizing,
        offsetStrategy: offsetStrategy,
        symbolOrder: symbolOrder,
        seed: seed,
        symbolPhases: symbolPhases,
        steering: steering,
        showsGridOverlay: showsGridOverlay,
        subgrids: [],
      )
      self.subgrids = subgrids
    }

    /// The canonical grid sizing definition.
    public var sizing: Sizing {
      get { base.sizing }
      set { base.sizing = newValue }
    }

    /// Offset strategy applied to grid rows or columns.
    public var offsetStrategy: GridOffsetStrategy {
      get { base.offsetStrategy }
      set { base.offsetStrategy = newValue }
    }

    /// Order in which symbols are assigned to regular grid cells.
    public var symbolOrder: GridSymbolOrder {
      get { base.symbolOrder }
      set { base.symbolOrder = newValue }
    }

    /// Seed used for deterministic grid symbol assignment.
    public var seed: UInt64 {
      get { base.seed }
      set { base.seed = newValue }
    }

    /// Optional per-symbol phase offsets in grid cell units keyed by `Symbol.id`.
    public var symbolPhases: [UUID: SymbolPhase] {
      get { base.symbolPhases }
      set { base.symbolPhases = newValue }
    }

    /// Position-based steering controls.
    public var steering: GridSteering {
      get { base.steering }
      set { base.steering = newValue }
    }

    /// Whether to draw a debug overlay for the resolved grid.
    public var showsGridOverlay: Bool {
      get { base.showsGridOverlay }
      set { base.showsGridOverlay = newValue }
    }
  }
}

public extension TesseraPlacement {
  /// Creates organic placement with pragmatic defaults.
  static func organic(
    minimumSpacing: Double = 10,
    density: Double = 0.6,
    scale: ClosedRange<Double> = 0.9...1.1,
    maximumCount: Int = 512,
    steering: OrganicSteering = .none,
    fillStrategy: PlacementModel.OrganicFillStrategy = .rejection,
    showsCollisionOverlay: Bool = false,
  ) -> TesseraPlacement {
    .organic(
      Organic(
        minimumSpacing: minimumSpacing,
        density: density,
        baseScaleRange: scale,
        maximumSymbolCount: maximumCount,
        steering: steering,
        fillStrategy: fillStrategy,
        showsCollisionOverlay: showsCollisionOverlay,
      ),
    )
  }

  /// Creates grid placement with concise parameter names.
  ///
  /// - Parameters:
  ///   - columns: Number of grid columns.
  ///   - rows: Number of grid rows.
  ///   - offset: Row/column offset strategy.
  ///   - symbolOrder: Symbol assignment strategy for regular grid cells.
  ///   - seed: Seed used for deterministic grid assignment.
  ///   - symbolPhases: Optional per-symbol phase offsets keyed by symbol ID.
  ///   - showsGridOverlay: Whether to draw a debug overlay for the resolved grid.
  ///   - subgrids: Optional subgrid definitions in base-grid coordinates.
  ///     Count-sized grids use zero-based coordinates; fixed-cell grids can expose negative coordinates when
  ///     partially visible edge cells remain on-screen.
  ///   - steering: Position-based steering controls.
  static func grid(
    columns: Int,
    rows: Int,
    offset: GridOffsetStrategy = .none,
    symbolOrder: GridSymbolOrder = .rowMajor,
    seed: UInt64 = Pattern.randomSeed(),
    symbolPhases: [UUID: Grid.SymbolPhase] = [:],
    showsGridOverlay: Bool = false,
    subgrids: [Grid.Subgrid] = [],
    steering: GridSteering = .none,
  ) -> TesseraPlacement {
    .grid(
      Grid(
        sizing: .count(columns: columns, rows: rows),
        offsetStrategy: offset,
        symbolOrder: symbolOrder,
        seed: seed,
        symbolPhases: symbolPhases,
        steering: steering,
        showsGridOverlay: showsGridOverlay,
        subgrids: subgrids,
      ),
    )
  }

  /// Creates grid placement with fixed cell dimensions and a lattice origin.
  ///
  /// - Parameters:
  ///   - cellSize: Fixed grid cell size in points.
  ///   - origin: Top-left position of lattice cell `(0, 0)` relative to the placement bounds.
  ///   - offset: Row/column offset strategy.
  ///   - symbolOrder: Symbol assignment strategy for regular grid cells.
  ///   - seed: Seed used for deterministic grid assignment.
  ///   - symbolPhases: Optional per-symbol phase offsets keyed by symbol ID.
  ///   - showsGridOverlay: Whether to draw a debug overlay for the resolved grid.
  ///   - subgrids: Optional subgrid definitions in base-grid coordinates.
  ///     Count-sized grids use zero-based coordinates; fixed-cell grids can expose negative coordinates when
  ///     partially visible edge cells remain on-screen.
  ///   - steering: Position-based steering controls.
  static func grid(
    cellSize: CGSize,
    origin: CGPoint = .zero,
    offset: GridOffsetStrategy = .none,
    symbolOrder: GridSymbolOrder = .rowMajor,
    seed: UInt64 = Pattern.randomSeed(),
    symbolPhases: [UUID: Grid.SymbolPhase] = [:],
    showsGridOverlay: Bool = false,
    subgrids: [Grid.Subgrid] = [],
    steering: GridSteering = .none,
  ) -> TesseraPlacement {
    .grid(
      Grid(
        sizing: .fixed(cellSize: cellSize, origin: origin),
        offsetStrategy: offset,
        symbolOrder: symbolOrder,
        seed: seed,
        symbolPhases: symbolPhases,
        steering: steering,
        showsGridOverlay: showsGridOverlay,
        subgrids: subgrids,
      ),
    )
  }
}

public extension TesseraPlacement.Organic {
  /// Alias for `baseScaleRange`.
  var scale: ClosedRange<Double> {
    get { baseScaleRange }
    set { baseScaleRange = newValue }
  }

  /// Alias for `maximumSymbolCount`.
  var maximumCount: Int {
    get { maximumSymbolCount }
    set { maximumSymbolCount = newValue }
  }
}

public extension TesseraPlacement.Grid {
  /// Alias for `offsetStrategy`.
  var offset: TesseraPlacement.GridOffsetStrategy {
    get { offsetStrategy }
    set { offsetStrategy = newValue }
  }

  /// Alias for `symbolPhases`.
  var phases: [UUID: TesseraPlacement.Grid.SymbolPhase] {
    get { symbolPhases }
    set { symbolPhases = newValue }
  }
}

extension TesseraPlacement.Grid {
  func resolvedInternalGridOptions() -> (options: PlacementModel.Grid, subgridSymbols: [Symbol]) {
    var subgridSymbols: [Symbol] = []
    var seenSubgridSymbolIDs: Set<UUID> = []

    let resolvedSubgrids = subgrids.map { subgrid in
      for symbol in subgrid.symbols where seenSubgridSymbolIDs.insert(symbol.id).inserted {
        subgridSymbols.append(symbol)
      }

      return PlacementModel.Grid.Subgrid(
        origin: subgrid.origin,
        span: subgrid.span,
        symbolIDs: subgrid.resolvedSymbolIDs,
        symbolOrder: subgrid.symbolOrder,
        seed: subgrid.seed,
        clipsToBounds: subgrid.clipsToBounds,
        grid: subgrid.grid?.internalLocalGrid,
      )
    }

    var resolvedBase = base
    resolvedBase.subgrids = resolvedSubgrids
    return (options: resolvedBase, subgridSymbols: subgridSymbols)
  }
}
