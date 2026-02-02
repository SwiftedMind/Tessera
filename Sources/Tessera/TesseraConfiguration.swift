// By Dennis Müller

import CoreGraphics
import SwiftUI

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
  /// Rotates the pattern in placement space.
  ///
  /// Unlike rotating the final rendered tile, this rotates the placement positions used to generate symbols.
  /// The placement engines apply this rotation only when using `.seamlessWrapping` edge behavior.
  public var patternRotation: Angle
  /// Anchor used for rotating the pattern in placement space.
  ///
  /// This is expressed in unit coordinates of the rendered tile or canvas.
  public var patternRotationAnchor: UnitPoint

  /// Creates a tessera configuration.
  /// - Parameters:
  ///   - symbols: Symbols that can be placed in the layout.
  ///   - placement: Placement algorithm used to generate symbol positions.
  ///   - patternOffset: Positional offset applied to all generated symbols.
  ///   - patternRotation: Rotation applied to generated symbol placement positions. Applied only under
  ///     `.seamlessWrapping`.
  ///   - patternRotationAnchor: Anchor used to rotate placement positions.
  public init(
    symbols: [TesseraSymbol],
    placement: TesseraPlacement,
    patternOffset: CGSize = .zero,
    patternRotation: Angle = .zero,
    patternRotationAnchor: UnitPoint = .center,
  ) {
    self.symbols = symbols
    self.placement = placement
    self.patternOffset = patternOffset
    self.patternRotation = patternRotation
    self.patternRotationAnchor = patternRotationAnchor
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

  var gridPlacement: TesseraPlacement.Grid? {
    if case let .grid(placement) = placement {
      return placement
    }
    return nil
  }

  var placementSeed: UInt64? {
    switch placement {
    case let .organic(organicPlacement):
      organicPlacement.seed
    case let .grid(gridPlacement):
      gridPlacement.seed
    }
  }

  var showsCollisionOverlay: Bool {
    organicPlacement?.showsCollisionOverlay ?? false
  }
}
