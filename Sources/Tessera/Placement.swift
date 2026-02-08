// By Dennis Müller

/// Primary placement API alias for Tessera v4.
public typealias Placement = TesseraPlacement

public extension Placement {
  /// Organic placement configuration type.
  typealias OrganicOptions = Organic
  /// Grid placement configuration type.
  typealias GridOptions = Grid

  /// Creates organic placement with pragmatic defaults.
  ///
  /// - Parameters:
  ///   - minimumSpacing: Additional spacing buffer between symbol collision shapes.
  ///   - density: Desired fill amount in the range `0...1`.
  ///   - scale: Default symbol scale range.
  ///   - maximumCount: Safety cap for placed symbol count.
  ///   - steering: Position-based steering controls.
  ///   - showsCollisionOverlay: Whether on-screen collision overlays are drawn.
  static func organic(
    minimumSpacing: Double = 10,
    density: Double = 0.6,
    scale: ClosedRange<Double> = 0.9...1.1,
    maximumCount: Int = 512,
    steering: OrganicSteering = .none,
    showsCollisionOverlay: Bool = false,
  ) -> Placement {
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
  ///   - steering: Position-based steering controls.
  static func grid(
    columns: Int,
    rows: Int,
    offset: GridOffsetStrategy = .none,
    symbolOrder: GridSymbolOrder = .sequence,
    seed: UInt64 = Pattern.randomSeed(),
    steering: GridSteering = .none,
  ) -> Placement {
    .grid(
      Grid(
        columnCount: columns,
        rowCount: rows,
        offsetStrategy: offset,
        symbolOrder: symbolOrder,
        seed: seed,
        steering: steering,
      ),
    )
  }
}

public extension Placement.OrganicOptions {
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

public extension Placement.GridOptions {
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
  var offset: Placement.GridOffsetStrategy {
    get { offsetStrategy }
    set { offsetStrategy = newValue }
  }
}
