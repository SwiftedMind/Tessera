// By Dennis Müller

import CoreGraphics

/// Describes the configuration used to generate a tessera layout.
///
/// A configuration is size-less. Concrete rendering is performed by providing a tile size
/// (`TesseraTile` / `TesseraPattern`) or a canvas size (`TesseraCanvas`).
public struct TesseraConfiguration {
  public var items: [TesseraItem]
  /// Seed for deterministic randomness. Defaults to a random seed.
  public var seed: UInt64
  /// Minimum distance between item centers.
  public var minimumSpacing: Double
  /// Desired fill density between 0 and 1.
  public var density: Double
  /// Default scale range applied when an item does not provide its own scale range.
  public var baseScaleRange: ClosedRange<Double>
  /// Offsets applied to all generated items before optional wrapping.
  public var patternOffset: CGSize
  /// Upper bound on how many generated items may be placed.
  public var maximumItemCount: Int

  /// Creates a tessera configuration.
  /// - Parameters:
  ///   - items: Items that can be placed in the layout.
  ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
  ///   - minimumSpacing: Minimum distance between item centers.
  ///   - density: Desired fill density between 0 and 1.
  ///   - baseScaleRange: Default scale range applied when an item does not provide its own scale range.
  ///   - patternOffset: Positional offset applied to all generated items.
  ///   - maximumItemCount: Upper bound on how many generated items may be placed.
  public init(
    items: [TesseraItem],
    seed: UInt64 = TesseraConfiguration.randomSeed(),
    minimumSpacing: Double,
    density: Double = 0.5,
    baseScaleRange: ClosedRange<Double> = 0.9...1.1,
    patternOffset: CGSize = .zero,
    maximumItemCount: Int = 512,
  ) {
    self.items = items
    self.seed = seed
    self.minimumSpacing = minimumSpacing
    self.density = density
    self.baseScaleRange = baseScaleRange
    self.patternOffset = patternOffset
    self.maximumItemCount = maximumItemCount
  }

  /// Generates a new random seed.
  public static func randomSeed() -> UInt64 {
    UInt64.random(in: 1...UInt64.max)
  }
}
