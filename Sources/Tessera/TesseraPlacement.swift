// By Dennis Müller

import CoreGraphics

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
    /// Desired size of each grid cell.
    ///
    /// The engine adjusts the spacing to fit the tile size for seamless wrapping.
    public var cellSize: CGSize
    /// Offset strategy applied to grid rows or columns.
    public var offsetStrategy: GridOffsetStrategy
    /// Order in which symbols are assigned to grid cells.
    public var symbolOrder: GridSymbolOrder

    /// Creates a grid placement configuration.
    /// - Parameters:
    ///   - cellSize: Desired size of each grid cell. The engine adjusts the spacing to fit the tile size for seamless
    ///     wrapping.
    ///   - offsetStrategy: Offset strategy applied to grid rows or columns.
    ///   - symbolOrder: Order in which symbols are assigned to grid cells.
    public init(
      cellSize: CGSize,
      offsetStrategy: GridOffsetStrategy = .none,
      symbolOrder: GridSymbolOrder = .sequence,
    ) {
      self.cellSize = cellSize
      self.offsetStrategy = offsetStrategy
      self.symbolOrder = symbolOrder
    }
  }

  /// Offset strategies for grid placement.
  public enum GridOffsetStrategy: Hashable, Sendable {
    /// No grid offsets.
    case none
    /// Offsets every other row horizontally by a fraction of the cell width.
    ///
    /// Use values between 0 and 1 for predictable results.
    case rowShift(fraction: Double)
    /// Offsets every other column vertically by a fraction of the cell height.
    ///
    /// Use values between 0 and 1 for predictable results.
    case columnShift(fraction: Double)
    /// Offsets alternating cells diagonally by a fraction of the cell size.
    ///
    /// Use values between 0 and 1 for predictable results.
    case checkerShift(fraction: Double)
  }

  /// Symbol assignment order for grid placement.
  public enum GridSymbolOrder: Hashable, Sendable {
    /// Assign symbols in array order, repeating from the start as needed.
    case sequence
  }
}
