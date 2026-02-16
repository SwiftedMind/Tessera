// By Dennis Müller

import CoreGraphics
import Foundation

/// A size-independent tessera pattern definition.
///
/// `Pattern` describes what can be placed (`symbols`) and how those symbols are placed (`placement`).
/// Concrete size is chosen later by `Tessera.mode(_:)`.
public struct Pattern {
  /// Symbols that may be placed by the engine.
  public var symbols: [Symbol]
  /// Placement strategy and options.
  public var placement: TesseraPlacement
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
    let resolved = resolvedPattern()
    return TesseraConfiguration(
      symbols: resolved.symbols,
      placement: resolved.placement,
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

private extension Pattern {
  func resolvedPattern() -> (symbols: [Symbol], placement: PlacementModel) {
    switch placement {
    case let .organic(options):
      return (symbols: symbols, placement: .organic(options))

    case let .grid(options):
      let resolvedGrid = options.resolvedInternalGridOptions()
      let allSymbols = symbols.appendingUniqueByID(resolvedGrid.mergedSymbols)

      #if DEBUG
      let knownSymbolIDs = Set(allSymbols.map(\.id))
      let missingMergedOverrideIDs = Set(
        resolvedGrid.options.mergedCells.compactMap(\.symbolID).filter { knownSymbolIDs.contains($0) == false },
      )
      assert(
        missingMergedOverrideIDs.isEmpty,
        "Merged cell override symbol IDs were not found in Pattern.symbols: \(missingMergedOverrideIDs)",
      )
      #endif

      return (symbols: allSymbols, placement: .grid(resolvedGrid.options))
    }
  }
}

private extension [Symbol] {
  func appendingUniqueByID(_ additionalSymbols: [Symbol]) -> [Symbol] {
    guard additionalSymbols.isEmpty == false else { return self }

    var result = self
    var seenIDs = Set(result.map(\.id))
    for symbol in additionalSymbols where seenIDs.insert(symbol.id).inserted {
      result.append(symbol)
    }
    return result
  }
}
