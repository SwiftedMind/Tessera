// By Dennis Müller

import Foundation

struct SymbolRenderOrderMetadata: Sendable, Hashable {
  var zIndex: Double
  var sourceOrder: Int
}

enum RenderOrderLayer: Int, Sendable, Hashable {
  case generated = 0
  case pinned = 1
}

struct RenderOrderKey: Sendable, Hashable {
  var zIndex: Double
  var layerOrder: Int
  var sourceOrder: Int
  var placementSequence: Int
}

enum ShapePlacementOrdering {
  static func ordered<Element>(
    _ elements: [Element],
    renderOrder: (Int, Element) -> RenderOrderKey,
  ) -> [Element] {
    elements
      .enumerated()
      .sorted { lhs, rhs in
        compare(
          lhs: renderOrder(lhs.offset, lhs.element),
          rhs: renderOrder(rhs.offset, rhs.element),
        )
      }
      .map(\.element)
  }

  static func normalized(
    _ placedSymbols: [ShapePlacementEngine.PlacedSymbolDescriptor],
  ) -> [ShapePlacementEngine.PlacedSymbolDescriptor] {
    ordered(placedSymbols) { placementSequence, placedSymbol in
      RenderOrderKey(
        zIndex: placedSymbol.zIndex,
        layerOrder: RenderOrderLayer.generated.rawValue,
        sourceOrder: placedSymbol.sourceOrder,
        placementSequence: placementSequence,
      )
    }
  }

  static func normalized(
    _ placedSymbols: [SnapshotPlacementDescriptor],
    metadataBySymbolID: [UUID: SymbolRenderOrderMetadata],
  ) -> [SnapshotPlacementDescriptor] {
    ordered(placedSymbols) { fallbackSequence, placedSymbol in
      renderOrder(
        for: placedSymbol.symbolId,
        fallbackSequence: fallbackSequence,
        metadataBySymbolID: metadataBySymbolID,
      )
    }
  }

  static func normalized(
    _ placedSymbols: [TesseraCanvas.PlacementDescriptor],
    metadataBySymbolID: [UUID: SymbolRenderOrderMetadata],
  ) -> [TesseraCanvas.PlacementDescriptor] {
    ordered(placedSymbols) { fallbackSequence, placedSymbol in
      renderOrder(
        for: placedSymbol.symbolId,
        fallbackSequence: fallbackSequence,
        metadataBySymbolID: metadataBySymbolID,
      )
    }
  }

  private static func renderOrder(
    for symbolID: UUID,
    fallbackSequence: Int,
    metadataBySymbolID: [UUID: SymbolRenderOrderMetadata],
  ) -> RenderOrderKey {
    let metadata = metadataBySymbolID[symbolID] ?? SymbolRenderOrderMetadata(
      zIndex: 0,
      sourceOrder: Int.max,
    )
    return RenderOrderKey(
      zIndex: sanitizedZIndex(metadata.zIndex),
      layerOrder: RenderOrderLayer.generated.rawValue,
      sourceOrder: metadata.sourceOrder,
      placementSequence: fallbackSequence,
    )
  }

  private static func compare(
    lhs: RenderOrderKey,
    rhs: RenderOrderKey,
  ) -> Bool {
    let lhsZIndex = sanitizedZIndex(lhs.zIndex)
    let rhsZIndex = sanitizedZIndex(rhs.zIndex)

    if lhsZIndex != rhsZIndex {
      return lhsZIndex < rhsZIndex
    }
    if lhs.layerOrder != rhs.layerOrder {
      return lhs.layerOrder < rhs.layerOrder
    }
    if lhs.sourceOrder != rhs.sourceOrder {
      return lhs.sourceOrder < rhs.sourceOrder
    }
    return lhs.placementSequence < rhs.placementSequence
  }

  static func sanitizedZIndex(_ zIndex: Double) -> Double {
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
