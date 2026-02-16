// By Dennis Müller

import Foundation

/// Primary placement API for Tessera v4.
///
/// This public surface keeps authoring ergonomic while still resolving to the internal
/// engine-facing `PlacementModel` at render time.
public enum TesseraPlacement {
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
  /// Shared steering field type.
  public typealias SteeringField = PlacementModel.SteeringField

  /// Organic placement.
  case organic(Organic)
  /// Grid placement.
  case grid(Grid)

  /// Public grid placement options.
  ///
  /// Grid option fields are forwarded to `base` so we keep a single source of truth for
  /// engine-facing placement behavior (`PlacementModel.Grid`), while merged-cell authoring
  /// overlays can carry richer symbol overrides.
  public struct Grid {
    /// Alias for `PlacementModel.Grid.SymbolPhase`.
    public typealias SymbolPhase = PlacementModel.Grid.SymbolPhase
    /// Alias for `PlacementModel.Grid.MergedCellSymbolSizing`.
    public typealias MergedCellSymbolSizing = PlacementModel.Grid.MergedCellSymbolSizing
    /// Alias for `PlacementModel.Grid.CellMerge.Origin`.
    public typealias Origin = PlacementModel.Grid.CellMerge.Origin
    /// Alias for `PlacementModel.Grid.CellMerge.Span`.
    public typealias Span = PlacementModel.Grid.CellMerge.Span

    /// Public merged-cell configuration for grid placement.
    public struct CellMerge: Hashable {
      /// Symbol override mode for a merged cell.
      ///
      /// `inline` is the recommended API because it keeps override configuration co-located.
      /// Inline symbols are automatically appended to the resolved pattern symbol list (uniqued by `id`).
      public enum SymbolOverride {
        /// No special merged-cell symbol.
        case none
        /// Inline symbol override for this merged cell.
        case inline(Symbol)
        /// Reference an already-known symbol by ID.
        ///
        /// Prefer `inline` unless you explicitly need ID-based wiring.
        case existing(UUID)
      }

      /// Zero-based top-leading origin in base grid coordinates.
      public var origin: Origin
      /// Rectangle size in base grid cell counts.
      public var span: Span
      /// Symbol override mode for this merged cell.
      public var symbolOverride: SymbolOverride
      /// Symbol sizing behavior for this merged cell.
      public var symbolSizing: MergedCellSymbolSizing

      var resolvedSymbolID: UUID? {
        switch symbolOverride {
        case .none:
          nil
        case let .inline(symbol):
          symbol.id
        case let .existing(symbolID):
          symbolID
        }
      }

      /// Convenience accessor for inline symbol overrides.
      ///
      /// Setting this writes `.inline(symbol)` or `.none`.
      public var symbol: Symbol? {
        get {
          if case let .inline(symbol) = symbolOverride {
            symbol
          } else {
            nil
          }
        }
        set {
          symbolOverride = newValue.map(SymbolOverride.inline) ?? .none
        }
      }

      /// Creates a merged-cell definition.
      ///
      /// - Parameters:
      ///   - origin: Zero-based top-leading origin in base grid coordinates.
      ///   - span: Rectangle size in base grid cell counts.
      ///   - symbolOverride: Symbol override mode for this merged cell.
      ///   - symbolSizing: Symbol sizing behavior for this merged cell.
      public init(
        origin: Origin,
        span: Span,
        symbolOverride: SymbolOverride = .none,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.origin = origin
        self.span = span
        self.symbolOverride = symbolOverride
        self.symbolSizing = symbolSizing
      }

      /// Creates a merged-cell definition.
      ///
      /// - Parameters:
      ///   - at: Zero-based top-leading origin in base grid coordinates.
      ///   - spanning: Rectangle size in base grid cell counts.
      ///   - symbolOverride: Symbol override mode for this merged cell.
      ///   - symbolSizing: Symbol sizing behavior for this merged cell.
      public init(
        at origin: Origin,
        spanning span: Span,
        symbolOverride: SymbolOverride = .none,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.init(
          origin: origin,
          span: span,
          symbolOverride: symbolOverride,
          symbolSizing: symbolSizing,
        )
      }

      /// Creates a merged-cell definition with an inline symbol override.
      public init(
        origin: Origin,
        span: Span,
        symbol: Symbol?,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.init(
          origin: origin,
          span: span,
          symbolOverride: symbol.map(SymbolOverride.inline) ?? .none,
          symbolSizing: symbolSizing,
        )
      }

      /// Creates a merged-cell definition with an inline symbol override.
      public init(
        at origin: Origin,
        spanning span: Span,
        symbol: Symbol?,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.init(
          origin: origin,
          span: span,
          symbol: symbol,
          symbolSizing: symbolSizing,
        )
      }

      /// Convenience initializer with explicit zero-based coordinates and span counts.
      public init(
        row: Int,
        column: Int,
        rows: Int,
        columns: Int,
        symbolOverride: SymbolOverride = .none,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.init(
          origin: .init(row: row, column: column),
          span: .init(rows: rows, columns: columns),
          symbolOverride: symbolOverride,
          symbolSizing: symbolSizing,
        )
      }

      /// Convenience initializer with explicit zero-based coordinates and span counts.
      public init(
        row: Int,
        column: Int,
        rows: Int,
        columns: Int,
        symbol: Symbol?,
        symbolSizing: MergedCellSymbolSizing = .natural,
      ) {
        self.init(
          origin: .init(row: row, column: column),
          span: .init(rows: rows, columns: columns),
          symbol: symbol,
          symbolSizing: symbolSizing,
        )
      }

      init(internalMerge: PlacementModel.Grid.CellMerge) {
        self.init(
          origin: internalMerge.origin,
          span: internalMerge.span,
          symbolOverride: internalMerge.symbolID.map(SymbolOverride.existing) ?? .none,
          symbolSizing: internalMerge.symbolSizing,
        )
      }

      public static func == (lhs: CellMerge, rhs: CellMerge) -> Bool {
        lhs.origin == rhs.origin &&
          lhs.span == rhs.span &&
          lhs.symbolSizing == rhs.symbolSizing &&
          lhs.resolvedSymbolID == rhs.resolvedSymbolID
      }

      public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(span)
        hasher.combine(symbolSizing)
        hasher.combine(resolvedSymbolID)
      }
    }

    /// Backing engine-facing grid options.
    ///
    /// This stays ID-based and Hashable/Sendable for deterministic placement internals.
    var base: PlacementModel.Grid
    /// Optional merged-cell rectangles in zero-based base-grid coordinates.
    ///
    /// Merges are validated against the resolved grid dimensions used for placement.
    /// Invalid or overlapping merges are ignored at placement time (first valid merge wins).
    public var mergedCells: [CellMerge]

    /// Creates public grid options from an internal grid base.
    ///
    /// - Parameters:
    ///   - base: Engine-facing grid options.
    ///   - mergedCells: Optional authoring merged cells. When omitted, values are imported from `base`.
    public init(
      base: PlacementModel.Grid,
      mergedCells: [CellMerge]? = nil,
    ) {
      self.base = base
      self.mergedCells = mergedCells ?? base.mergedCells.map(CellMerge.init(internalMerge:))
    }

    /// Creates grid placement configuration.
    ///
    /// - Parameters:
    ///   - columnCount: The number of columns in the grid.
    ///   - rowCount: The number of rows in the grid.
    ///   - offsetStrategy: Offset strategy applied to grid rows or columns.
    ///   - symbolOrder: Order in which symbols are assigned to resolved placement cells.
    ///   - seed: Seed used for deterministic grid assignment.
    ///   - symbolPhases: Optional per-symbol phase offsets keyed by `Symbol.id`.
    ///   - steering: Position-based steering controls.
    ///   - showsGridOverlay: Whether to draw a debug overlay for the resolved grid.
    ///   - mergedCells: Optional merged-cell definitions in zero-based base-grid coordinates.
    ///   - excludeMergedSymbolsFromRegularCells: Whether merged-cell override symbols should be excluded from regular
    ///     grid assignment.
    public init(
      columnCount: Int,
      rowCount: Int,
      offsetStrategy: GridOffsetStrategy = .none,
      symbolOrder: GridSymbolOrder = .sequence,
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      symbolPhases: [UUID: SymbolPhase] = [:],
      steering: GridSteering = .none,
      showsGridOverlay: Bool = false,
      mergedCells: [CellMerge] = [],
      excludeMergedSymbolsFromRegularCells: Bool = true,
    ) {
      base = PlacementModel.Grid(
        columnCount: columnCount,
        rowCount: rowCount,
        offsetStrategy: offsetStrategy,
        symbolOrder: symbolOrder,
        seed: seed,
        symbolPhases: symbolPhases,
        steering: steering,
        showsGridOverlay: showsGridOverlay,
        mergedCells: [],
        excludeMergedSymbolsFromRegularCells: excludeMergedSymbolsFromRegularCells,
      )
      self.mergedCells = mergedCells
    }

    /// The number of columns in the grid.
    public var columnCount: Int {
      get { base.columnCount }
      set { base.columnCount = newValue }
    }

    /// The number of rows in the grid.
    public var rowCount: Int {
      get { base.rowCount }
      set { base.rowCount = newValue }
    }

    /// Offset strategy applied to grid rows or columns.
    public var offsetStrategy: GridOffsetStrategy {
      get { base.offsetStrategy }
      set { base.offsetStrategy = newValue }
    }

    /// Order in which symbols are assigned to grid cells.
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

    /// Whether merged-cell override symbols should be excluded from regular grid assignment.
    public var excludeMergedSymbolsFromRegularCells: Bool {
      get { base.excludeMergedSymbolsFromRegularCells }
      set { base.excludeMergedSymbolsFromRegularCells = newValue }
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
    showsCollisionOverlay: Bool = false,
  ) -> TesseraPlacement {
    .organic(
      Organic(
        minimumSpacing: minimumSpacing,
        density: density,
        baseScaleRange: scale,
        maximumSymbolCount: maximumCount,
        steering: steering,
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
  ///   - symbolOrder: Symbol assignment strategy.
  ///   - seed: Seed used for deterministic grid assignment.
  ///   - symbolPhases: Optional per-symbol phase offsets keyed by symbol ID.
  ///   - showsGridOverlay: Whether to draw a debug overlay for the resolved grid.
  ///   - mergedCells: Optional merged-cell definitions in zero-based base-grid coordinates.
  ///   - excludeMergedSymbolsFromRegularCells: Whether merged-cell override symbols should be excluded from regular
  ///     grid assignment.
  ///   - steering: Position-based steering controls.
  static func grid(
    columns: Int,
    rows: Int,
    offset: GridOffsetStrategy = .none,
    symbolOrder: GridSymbolOrder = .sequence,
    seed: UInt64 = Pattern.randomSeed(),
    symbolPhases: [UUID: Grid.SymbolPhase] = [:],
    showsGridOverlay: Bool = false,
    mergedCells: [Grid.CellMerge] = [],
    excludeMergedSymbolsFromRegularCells: Bool = true,
    steering: GridSteering = .none,
  ) -> TesseraPlacement {
    .grid(
      Grid(
        columnCount: columns,
        rowCount: rows,
        offsetStrategy: offset,
        symbolOrder: symbolOrder,
        seed: seed,
        symbolPhases: symbolPhases,
        steering: steering,
        showsGridOverlay: showsGridOverlay,
        mergedCells: mergedCells,
        excludeMergedSymbolsFromRegularCells: excludeMergedSymbolsFromRegularCells,
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
  /// Alias for `columnCount`.
  var columns: Int {
    get { columnCount }
    set { columnCount = newValue }
  }

  /// Alias for `rowCount`.
  var rows: Int {
    get { rowCount }
    set { rowCount = newValue }
  }

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

  /// Alias for `mergedCells`.
  var merges: [TesseraPlacement.Grid.CellMerge] {
    get { mergedCells }
    set { mergedCells = newValue }
  }
}

extension TesseraPlacement.Grid {
  func resolvedInternalGridOptions() -> (options: PlacementModel.Grid, mergedSymbols: [Symbol]) {
    var mergedSymbols: [Symbol] = []
    var seenMergedSymbolIDs: Set<UUID> = []

    let resolvedMergedCells = mergedCells.map { merge in
      if let symbol = merge.symbol, seenMergedSymbolIDs.insert(symbol.id).inserted {
        mergedSymbols.append(symbol)
      }

      return PlacementModel.Grid.CellMerge(
        origin: merge.origin,
        span: merge.span,
        symbolID: merge.resolvedSymbolID,
        symbolSizing: merge.symbolSizing,
      )
    }

    var resolvedBase = base
    resolvedBase.mergedCells = resolvedMergedCells
    return (options: resolvedBase, mergedSymbols: mergedSymbols)
  }
}
