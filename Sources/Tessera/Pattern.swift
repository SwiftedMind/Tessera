// By Dennis Müller

import CoreGraphics

/// A size-independent tessera pattern definition.
///
/// `Pattern` describes what can be placed (`symbols`) and how those symbols are placed (`placement`).
/// Concrete size is chosen later by `Tessera.mode(_:)`.
public struct Pattern {
  /// Symbols that may be placed by the engine.
  public var symbols: [Symbol]
  /// Placement strategy and options.
  public var placement: Placement
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
    placement: Placement = .organic(),
    offset: CGSize = .zero,
  ) {
    self.symbols = symbols
    self.placement = placement
    self.offset = offset
  }

  /// Generates a random non-zero seed.
  public static func randomSeed() -> UInt64 {
    TesseraConfiguration.randomSeed()
  }

  var legacyConfiguration: TesseraConfiguration {
    TesseraConfiguration(
      symbols: symbols,
      placement: placement,
      patternOffset: offset,
    )
  }

  var placementSeed: UInt64? {
    switch placement {
    case let .organic(options):
      options.seed
    case let .grid(options):
      options.seed
    }
  }
}
