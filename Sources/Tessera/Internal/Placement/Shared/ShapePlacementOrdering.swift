// By Dennis Müller

import Foundation

struct SymbolRenderOrderMetadata: Sendable, Hashable {
  var zIndex: Double
  var sourceOrder: Int
}

enum ShapePlacementOrdering {
  static func normalized(
    _ placedSymbols: [ShapePlacementEngine.PlacedSymbolDescriptor],
  ) -> [ShapePlacementEngine.PlacedSymbolDescriptor] {
    placedSymbols
      .enumerated()
      .sorted { lhs, rhs in
        compare(
          lhs: (zIndex: lhs.element.zIndex, sourceOrder: lhs.element.sourceOrder, placementSequence: lhs.offset),
          rhs: (zIndex: rhs.element.zIndex, sourceOrder: rhs.element.sourceOrder, placementSequence: rhs.offset),
        )
      }
      .map(\.element)
  }

  static func normalized(
    _ placedSymbols: [SnapshotPlacementDescriptor],
    metadataBySymbolID: [UUID: SymbolRenderOrderMetadata],
  ) -> [SnapshotPlacementDescriptor] {
    placedSymbols
      .enumerated()
      .sorted { lhs, rhs in
        compare(
          lhs: renderOrder(
            for: lhs.element.symbolId,
            fallbackSequence: lhs.offset,
            metadataBySymbolID: metadataBySymbolID,
          ),
          rhs: renderOrder(
            for: rhs.element.symbolId,
            fallbackSequence: rhs.offset,
            metadataBySymbolID: metadataBySymbolID,
          ),
        )
      }
      .map(\.element)
  }

  static func normalized(
    _ placedSymbols: [TesseraCanvas.PlacementDescriptor],
    metadataBySymbolID: [UUID: SymbolRenderOrderMetadata],
  ) -> [TesseraCanvas.PlacementDescriptor] {
    placedSymbols
      .enumerated()
      .sorted { lhs, rhs in
        compare(
          lhs: renderOrder(
            for: lhs.element.symbolId,
            fallbackSequence: lhs.offset,
            metadataBySymbolID: metadataBySymbolID,
          ),
          rhs: renderOrder(
            for: rhs.element.symbolId,
            fallbackSequence: rhs.offset,
            metadataBySymbolID: metadataBySymbolID,
          ),
        )
      }
      .map(\.element)
  }

  private static func renderOrder(
    for symbolID: UUID,
    fallbackSequence: Int,
    metadataBySymbolID: [UUID: SymbolRenderOrderMetadata],
  ) -> (zIndex: Double, sourceOrder: Int, placementSequence: Int) {
    let metadata = metadataBySymbolID[symbolID] ?? SymbolRenderOrderMetadata(
      zIndex: 0,
      sourceOrder: Int.max,
    )
    return (
      zIndex: sanitizedZIndex(metadata.zIndex),
      sourceOrder: metadata.sourceOrder,
      placementSequence: fallbackSequence,
    )
  }

  private static func compare(
    lhs: (zIndex: Double, sourceOrder: Int, placementSequence: Int),
    rhs: (zIndex: Double, sourceOrder: Int, placementSequence: Int),
  ) -> Bool {
    let lhsZIndex = sanitizedZIndex(lhs.zIndex)
    let rhsZIndex = sanitizedZIndex(rhs.zIndex)

    if lhsZIndex != rhsZIndex {
      return lhsZIndex < rhsZIndex
    }
    if lhs.sourceOrder != rhs.sourceOrder {
      return lhs.sourceOrder < rhs.sourceOrder
    }
    return lhs.placementSequence < rhs.placementSequence
  }

  private static func sanitizedZIndex(_ zIndex: Double) -> Double {
    zIndex.isFinite ? zIndex : 0
  }
}

extension Collection<TesseraSymbol> {
  var renderOrderMetadataBySymbolID: [UUID: SymbolRenderOrderMetadata] {
    enumerated().reduce(into: [UUID: SymbolRenderOrderMetadata]()) { metadataBySymbolID, entry in
      let (sourceOrder, symbol) = entry
      guard metadataBySymbolID[symbol.id] == nil else { return }

      metadataBySymbolID[symbol.id] = SymbolRenderOrderMetadata(
        zIndex: symbol.zIndex.isFinite ? symbol.zIndex : 0,
        sourceOrder: sourceOrder,
      )
    }
  }
}
