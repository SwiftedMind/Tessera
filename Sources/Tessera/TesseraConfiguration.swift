// By Dennis Müller

import CoreGraphics
import Foundation

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
  /// Optional render invalidation token.
  ///
  /// Tessera caches expensive placement results and may not recompute them when only the *rendered content* of symbols
  /// changes (for example, when a symbol's SwiftUI view output changes but its collision shape and size remain stable).
  ///
  /// Set this to a value that changes whenever you need the canvas to redraw existing placements with updated symbol
  /// content.
  public var renderID: UUID?

  /// Creates a tessera configuration.
  /// - Parameters:
  ///   - symbols: Symbols that can be placed in the layout.
  ///   - placement: Placement algorithm used to generate symbol positions.
  ///   - patternOffset: Positional offset applied to all generated symbols.
  public init(
    symbols: [TesseraSymbol],
    placement: TesseraPlacement,
    patternOffset: CGSize = .zero,
    renderID: UUID? = nil,
  ) {
    self.symbols = symbols
    self.placement = placement
    self.patternOffset = patternOffset
    self.renderID = renderID
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
