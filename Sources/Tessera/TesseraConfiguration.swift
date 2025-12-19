// By Dennis Müller

import CoreGraphics

/// Describes the configuration used to generate a tessera layout.
///
/// A configuration is size-less. Concrete rendering is performed by providing a tile size
/// (`TesseraTile` / `TesseraTiledCanvas`) or a canvas size (`TesseraCanvas`).
public struct TesseraConfiguration {
  public var symbols: [TesseraSymbol]
  /// Seed for deterministic randomness. Defaults to a random seed.
  public var seed: UInt64
  /// Minimum distance between symbol centers.
  public var minimumSpacing: Double
  /// Desired fill density between 0 and 1.
  public var density: Double
  /// Default scale range applied when an symbol does not provide its own scale range.
  public var baseScaleRange: ClosedRange<Double>
  /// Offsets applied to all generated symbols before optional wrapping.
  public var patternOffset: CGSize
  /// Upper bound on how many generated symbols may be placed.
  public var maximumSymbolCount: Int
  /// Whether to render a debug overlay for collision shapes in on-screen canvases.
  ///
  /// Exported renders ignore this setting unless `TesseraRenderOptions.showsCollisionOverlay` is enabled.
  public var showsCollisionOverlay: Bool

  /// Creates a tessera configuration.
  /// - Parameters:
  ///   - symbols: Symbols that can be placed in the layout.
  ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
  ///   - minimumSpacing: Minimum distance between symbol centers.
  ///   - density: Desired fill density between 0 and 1.
  ///   - baseScaleRange: Default scale range applied when an symbol does not provide its own scale range.
  ///   - patternOffset: Positional offset applied to all generated symbols.
  ///   - maximumSymbolCount: Upper bound on how many generated symbols may be placed.
  ///   - showsCollisionOverlay: Whether to render a debug overlay for collision shapes in on-screen canvases.
  public init(
    symbols: [TesseraSymbol],
    seed: UInt64 = TesseraConfiguration.randomSeed(),
    minimumSpacing: Double,
    density: Double = 0.5,
    baseScaleRange: ClosedRange<Double> = 0.9...1.1,
    patternOffset: CGSize = .zero,
    maximumSymbolCount: Int = 512,
    showsCollisionOverlay: Bool = false,
  ) {
    self.symbols = symbols
    self.seed = seed
    self.minimumSpacing = minimumSpacing
    self.density = density
    self.baseScaleRange = baseScaleRange
    self.patternOffset = patternOffset
    self.maximumSymbolCount = maximumSymbolCount
    self.showsCollisionOverlay = showsCollisionOverlay
  }

  /// Generates a new random seed.
  public static func randomSeed() -> UInt64 {
    UInt64.random(in: 1...UInt64.max)
  }
}
