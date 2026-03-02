// By Dennis Müller

import CoreGraphics
import Foundation

/// A size-independent tessera pattern definition.
///
/// `Pattern` describes what can be placed (`symbols`) and how those symbols are placed (`placement`).
/// Concrete size is chosen later by `Tessera.mode(_:)`.
public struct Pattern: @unchecked Sendable {
  /// Symbols that may be placed by the engine.
  public var symbols: [Symbol]
  /// Placement strategy and options.
  public var placement: TesseraPlacement
  /// Mosaic definitions rendered natively as part of the pattern.
  public var mosaics: [Mosaic]
  /// Offset applied to all generated symbols before wrapping.
  public var offset: CGSize

  /// Creates a pattern definition.
  ///
  /// Example:
  /// ```swift
  /// let pattern = Pattern(
  ///   symbols: [
  ///     Symbol(collider: .automatic(size: .init(width: 24, height: 24))) {
  ///       Image(systemName: "sparkle")
  ///     }
  ///   ],
  ///   placement: .organic(minimumSpacing: 8, density: 0.6)
  /// )
  /// ```
  public init(
    symbols: [Symbol],
    placement: TesseraPlacement = .organic(),
    mosaics: [Mosaic] = [],
    offset: CGSize = .zero,
  ) {
    self.symbols = symbols
    self.placement = placement
    self.mosaics = mosaics
    self.offset = offset
  }

  /// Generates a random non-zero seed.
  public static func randomSeed() -> UInt64 {
    TesseraConfiguration.randomSeed()
  }

  var legacyConfiguration: TesseraConfiguration {
    let resolved = TesseraPlacementResolver.resolve(
      symbols: symbols,
      placement: placement,
    )
    return TesseraConfiguration(
      symbols: resolved.symbols,
      placement: resolved.placement,
      patternOffset: offset,
    )
  }

  var placementSeed: UInt64? {
    TesseraPlacementResolver.resolve(
      symbols: symbols,
      placement: placement,
    ).placementSeed
  }
}
