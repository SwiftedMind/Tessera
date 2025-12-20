// By Dennis Müller

import CoreGraphics

/// Describes the configuration used to generate a tessera layout.
///
/// A configuration is size-less. Concrete rendering is performed by providing a tile size
/// (`TesseraTile` / `TesseraTiledCanvas`) or a canvas size (`TesseraCanvas`).
public struct TesseraConfiguration {
  public var symbols: [TesseraSymbol]
  /// Placement algorithm used to generate symbol positions.
  public var placement: TesseraPlacement
  /// Offsets applied to all generated symbols before optional wrapping.
  public var patternOffset: CGSize

  /// Creates a tessera configuration.
  /// - Parameters:
  ///   - symbols: Symbols that can be placed in the layout.
  ///   - placement: Placement algorithm used to generate symbol positions.
  ///   - patternOffset: Positional offset applied to all generated symbols.
  public init(
    symbols: [TesseraSymbol],
    placement: TesseraPlacement,
    patternOffset: CGSize = .zero,
  ) {
    self.symbols = symbols
    self.placement = placement
    self.patternOffset = patternOffset
  }

  /// Generates a new random seed.
  public static func randomSeed() -> UInt64 {
    UInt64.random(in: 1...UInt64.max)
  }
}

extension TesseraConfiguration {
  var organicPlacement: TesseraPlacement.Organic? {
    if case let .organic(placement) = placement {
      return placement
    }
    return nil
  }

  var showsCollisionOverlay: Bool {
    organicPlacement?.showsCollisionOverlay ?? false
  }
}
