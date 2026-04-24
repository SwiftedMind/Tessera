// By Dennis Müller

import SwiftUI

/// Describes how Tessera chooses symbol positions.
public enum PlacementModel: Hashable, Sendable {
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
        self.x = Self.sanitizedCoordinate(x)
        self.y = Self.sanitizedCoordinate(y)
      }

      /// Creates a point from a SwiftUI `UnitPoint`.
      public init(_ unitPoint: UnitPoint) {
        self.init(x: unitPoint.x, y: unitPoint.y)
      }

      private static func sanitizedCoordinate(_ value: Double) -> Double {
        let sanitized = value.isFinite ? value : 0
        return max(0, min(1, sanitized))
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

    /// Radial radius behavior.
    public enum Radius: Hashable, Sendable {
      /// Uses the farthest canvas corner from `center`.
      case autoFarthestCorner
      /// Uses a fraction of the shortest canvas side.
      case shortestSideFraction(Double)
    }

    /// Steering field shape.
    public enum Shape: Hashable, Sendable {
      /// Linear gradient projected from `from` to `to` in unit space.
      case linear(from: Point, to: Point)
      /// Radial gradient expanding from `center`.
      case radial(center: Point, radius: Radius)
    }

    /// Interpolated scalar range.
    public var values: ClosedRange<Double> {
      didSet {
        let canonical = Self.canonicalizedValues(values)
        if canonical != values {
          values = canonical
        }
      }
    }

    /// Steering field shape.
    public var shape: Shape {
      didSet {
        let canonical = Self.canonicalizedShape(shape)
        if canonical != shape {
          shape = canonical
        }
      }
    }

    /// Easing applied to interpolation progress.
    public var easing: Easing

    /// Creates a linear steering field.
    public init(
      values: ClosedRange<Double>,
      from: UnitPoint,
      to: UnitPoint,
      easing: Easing = .smoothStep,
    ) {
      self.values = Self.canonicalizedValues(values)
      shape = Self.canonicalizedShape(
        .linear(from: Point(from), to: Point(to)),
      )
      self.easing = easing
    }

    /// Creates a radial steering field.
    public init(
      values: ClosedRange<Double>,
      center: UnitPoint,
      radius: Radius = .autoFarthestCorner,
      easing: Easing = .smoothStep,
    ) {
      self.values = Self.canonicalizedValues(values)
      shape = Self.canonicalizedShape(
        .radial(center: Point(center), radius: radius),
      )
      self.easing = easing
    }

    /// Convenience constructor for linear steering.
    public static func linear(
      values: ClosedRange<Double>,
      from: UnitPoint,
      to: UnitPoint,
      easing: Easing = .smoothStep,
    ) -> Self {
      .init(values: values, from: from, to: to, easing: easing)
    }

    /// Convenience constructor for radial steering.
    public static func radial(
      values: ClosedRange<Double>,
      center: UnitPoint,
      radius: Radius = .autoFarthestCorner,
      easing: Easing = .smoothStep,
    ) -> Self {
      .init(values: values, center: center, radius: radius, easing: easing)
    }

    private static func canonicalizedValues(_ values: ClosedRange<Double>) -> ClosedRange<Double> {
      let lowerBound = sanitizedFinite(values.lowerBound, fallback: 0)
      let upperBound = sanitizedFinite(values.upperBound, fallback: lowerBound)
      let resolvedUpperBound = max(lowerBound, upperBound)
      return lowerBound...resolvedUpperBound
    }

    private static func canonicalizedShape(_ shape: Shape) -> Shape {
      switch shape {
      case let .linear(from: from, to: to):
        .linear(
          from: Point(x: from.x, y: from.y),
          to: Point(x: to.x, y: to.y),
        )
      case let .radial(center: center, radius: radius):
        .radial(
          center: Point(x: center.x, y: center.y),
          radius: canonicalizedRadius(radius),
        )
      }
    }

    private static func canonicalizedRadius(_ radius: Radius) -> Radius {
      switch radius {
      case .autoFarthestCorner:
        return .autoFarthestCorner
      case let .shortestSideFraction(fraction):
        guard fraction.isFinite, fraction > 0 else {
          return .autoFarthestCorner
        }

        return .shortestSideFraction(fraction)
      }
    }

    private static func sanitizedFinite(_ value: Double, fallback: Double) -> Double {
      value.isFinite ? value : fallback
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

  /// Organic placement algorithm.
  public enum OrganicFillStrategy: Hashable, Sendable {
    /// Places each accepted symbol with the existing wrap-aware rejection sampler.
    case rejection
    /// Scores a batch of valid candidates before accepting each symbol, favoring tighter dense fills.
    case dense
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
    /// The organic placement algorithm used to choose accepted symbols.
    public var fillStrategy: OrganicFillStrategy
    /// Whether to render a debug overlay for collision shapes in on-screen canvases.
    ///
    /// Exported renders ignore this setting unless `RenderOptions.showsCollisionOverlay` is enabled.
    public var showsCollisionOverlay: Bool

    /// Creates an organic placement configuration.
    /// - Parameters:
    ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
    ///   - minimumSpacing: Additional spacing buffer between symbol collision shapes.
    ///   - density: Desired fill density between 0 and 1.
    ///   - baseScaleRange: Default scale range applied when a symbol does not provide its own scale range.
    ///   - maximumSymbolCount: Upper bound on how many generated symbols may be placed.
    ///   - steering: Position-based steering controls for organic placement.
    ///   - fillStrategy: The organic placement algorithm used to choose accepted symbols.
    ///   - showsCollisionOverlay: Whether to render a debug overlay for collision shapes in on-screen canvases.
    public init(
      seed: UInt64 = TesseraConfiguration.randomSeed(),
      minimumSpacing: Double,
      density: Double = 0.5,
      baseScaleRange: ClosedRange<Double> = 0.9...1.1,
      maximumSymbolCount: Int = 512,
      steering: OrganicSteering = .none,
      fillStrategy: OrganicFillStrategy = .rejection,
      showsCollisionOverlay: Bool = false,
    ) {
      self.seed = seed
      self.minimumSpacing = minimumSpacing
      self.density = density
      self.baseScaleRange = baseScaleRange
      self.maximumSymbolCount = maximumSymbolCount
      self.steering = steering
      self.fillStrategy = fillStrategy
      self.showsCollisionOverlay = showsCollisionOverlay
    }
  }
}
