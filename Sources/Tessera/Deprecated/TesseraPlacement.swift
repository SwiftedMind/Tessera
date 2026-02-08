// By Dennis Müller

import SwiftUI

/// Describes how Tessera chooses symbol positions.
public enum TesseraPlacement: Hashable, Sendable {
  /// Evenly spaced, organic placement using wrap-aware rejection sampling.
  case organic(Organic)
  /// Grid-based placement with optional offsets between rows or columns.
  case grid(Grid)

  /// Position-based scalar field used to steer placement values.
  public struct SteeringField: Hashable, Sendable {
    /// Unit-space point (`0...1`) used as a field anchor.
    public struct Point: Hashable, Sendable {
      /// Horizontal unit position.
      public var x: Double
      /// Vertical unit position.
      public var y: Double

      /// Creates a unit-space point.
      public init(x: Double, y: Double) {
        self.x = x
        self.y = y
      }

      /// Creates a point from a SwiftUI `UnitPoint`.
      public init(_ unitPoint: UnitPoint) {
        x = unitPoint.x
        y = unitPoint.y
      }
    }

    /// Easing used to shape interpolation from `from` to `to`.
    public enum Easing: Hashable, Sendable {
      /// Linear interpolation.
      case linear
      /// Smoothstep interpolation (`t²(3 - 2t)`).
      case smoothStep
      /// Quadratic ease-in.
      case easeIn
      /// Quadratic ease-out.
      case easeOut
      /// Cubic ease-in-out.
      case easeInOut
    }

    /// Interpolated scalar range.
    public var values: ClosedRange<Double>
    /// Start anchor in unit space.
    public var from: Point
    /// End anchor in unit space.
    public var to: Point
    /// Easing applied to interpolation progress.
    public var easing: Easing

    /// Creates a steering field.
    public init(
      values: ClosedRange<Double>,
      from: UnitPoint,
      to: UnitPoint,
      easing: Easing = .smoothStep,
    ) {
      self.values = values
      self.from = Point(from)
      self.to = Point(to)
      self.easing = easing
    }
  }

  /// Organic-only steering controls.
  public struct OrganicSteering: Hashable, Sendable {
    /// Position-based multiplier applied to `minimumSpacing`.
    public var minimumSpacingMultiplier: SteeringField?
    /// Position-based multiplier applied to sampled symbol scale.
    public var scaleMultiplier: SteeringField?
    /// Position-based multiplier applied to sampled symbol rotation (radians).
    public var rotationMultiplier: SteeringField?
    /// Position-based additive rotation offset in degrees.
    public var rotationOffsetDegrees: SteeringField?

    /// Disables organic steering.
    public static let none = Self()

    /// Creates organic steering controls.
    public init(
      minimumSpacingMultiplier: SteeringField? = nil,
      scaleMultiplier: SteeringField? = nil,
      rotationMultiplier: SteeringField? = nil,
      rotationOffsetDegrees: SteeringField? = nil,
    ) {
      self.minimumSpacingMultiplier = minimumSpacingMultiplier
      self.scaleMultiplier = scaleMultiplier
      self.rotationMultiplier = rotationMultiplier
      self.rotationOffsetDegrees = rotationOffsetDegrees
    }
  }

  /// Grid-only steering controls.
  public struct GridSteering: Hashable, Sendable {
    /// Position-based multiplier applied to symbol scale.
    public var scaleMultiplier: SteeringField?
    /// Position-based multiplier applied to symbol rotation (radians).
    public var rotationMultiplier: SteeringField?
    /// Position-based additive rotation offset in degrees.
    public var rotationOffsetDegrees: SteeringField?

    /// Disables grid steering.
    public static let none = Self()

    /// Creates grid steering controls.
    public init(
      scaleMultiplier: SteeringField? = nil,
      rotationMultiplier: SteeringField? = nil,
      rotationOffsetDegrees: SteeringField? = nil,
    ) {
      self.scaleMultiplier = scaleMultiplier
      self.rotationMultiplier = rotationMultiplier
      self.rotationOffsetDegrees = rotationOffsetDegrees
    }
  }

  /// Configuration for organic placement.
  public struct Organic: Hashable, Sendable {
    /// Seed for deterministic randomness. Defaults to a random seed.
    public var seed: UInt64
    /// Additional spacing buffer between symbol collision shapes.
    public var minimumSpacing: Double
    /// Desired fill density between 0 and 1.
    public var density: Double
    /// Default scale range applied when a symbol does not provide its own scale range.
    public var baseScaleRange: ClosedRange<Double>
    /// Upper bound on how many generated symbols may be placed.
    public var maximumSymbolCount: Int
    /// Position-based steering controls.
    public var steering: OrganicSteering
    /// Whether to render a debug overlay for collision shapes in on-screen canvases.
    ///
    /// Exported renders ignore this setting unless `TesseraRenderOptions.showsCollisionOverlay` is enabled.
    public var showsCollisionOverlay: Bool

    /// Creates an organic placement configuration.
    /// - Parameters:
    ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
    ///   - minimumSpacing: Additional spacing buffer between symbol collision shapes.
    ///   - density: Desired fill density between 0 and 1.
    ///   - baseScaleRange: Default scale range applied when a symbol does not provide its own scale range.
    ///   - maximumSymbolCount: Upper bound on how many generated symbols may be placed.
    ///   - steering: Position-based steering controls for organic placement.
    ///   - showsCollisionOverlay: Whether to render a debug overlay for collision shapes in on-screen canvases.
    public init(
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      minimumSpacing: Double,
      density: Double = 0.5,
      baseScaleRange: ClosedRange<Double> = 0.9...1.1,
      maximumSymbolCount: Int = 512,
      steering: OrganicSteering = .none,
      showsCollisionOverlay: Bool = false,
    ) {
      self.seed = seed
      self.minimumSpacing = minimumSpacing
      self.density = density
      self.baseScaleRange = baseScaleRange
      self.maximumSymbolCount = maximumSymbolCount
      self.steering = steering
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
    /// Position-based steering controls.
    public var steering: GridSteering

    /// Creates a grid placement configuration.
    /// - Parameters:
    ///   - columnCount: The number of columns in the grid.
    ///   - rowCount: The number of rows in the grid.
    ///   - offsetStrategy: Offset strategy applied to grid rows or columns.
    ///   - symbolOrder: Order in which symbols are assigned to grid cells.
    ///   - seed: Seed used to drive deterministic randomness for grid symbol assignment.
    ///   - steering: Position-based steering controls for grid placement.
    public init(
      columnCount: Int,
      rowCount: Int,
      offsetStrategy: GridOffsetStrategy = .none,
      symbolOrder: GridSymbolOrder = .sequence,
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      steering: GridSteering = .none,
    ) {
      self.columnCount = columnCount
      self.rowCount = rowCount
      self.offsetStrategy = offsetStrategy
      self.symbolOrder = symbolOrder
      self.seed = seed
      self.steering = steering
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
