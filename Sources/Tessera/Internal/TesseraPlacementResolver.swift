// By Dennis Müller

import Foundation

/// Resolves public placement authoring types into engine-facing placement models.
enum TesseraPlacementResolver {
  /// Resolves symbols and placement for one layer (base or mosaic).
  ///
  /// This expands grid subgrid symbols into the final symbol pool and forwards the
  /// placement seed used for deterministic generation.
  static func resolve(
    symbols: [Symbol],
    placement: TesseraPlacement,
  ) -> (symbols: [Symbol], placement: PlacementModel, placementSeed: UInt64?) {
    switch placement {
    case let .organic(options):
      return (
        symbols: symbols,
        placement: .organic(options),
        placementSeed: options.seed,
      )

    case let .grid(options):
      let resolvedGrid = options.resolvedInternalGridOptions()
      let resolvedSymbols = symbols.appendingUniqueByID(resolvedGrid.subgridSymbols)

      #if DEBUG
      let knownSymbolIDs = Set(resolvedSymbols.map(\.id))
      let missingSubgridSymbolIDs = Set(
        resolvedGrid.options.subgrids.flatMap(\.symbolIDs).filter { knownSymbolIDs.contains($0) == false },
      )
      assert(
        missingSubgridSymbolIDs.isEmpty,
        "Subgrid symbol IDs were not found in Pattern.symbols: \(missingSubgridSymbolIDs)",
      )
      #endif

      return (
        symbols: resolvedSymbols,
        placement: .grid(resolvedGrid.options),
        placementSeed: resolvedGrid.options.seed,
      )
    }
  }
}

extension [Symbol] {
  /// Returns this collection plus additional symbols, deduplicated by `Symbol.id`.
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
