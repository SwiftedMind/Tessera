// By Dennis Müller

import Foundation

enum TesseraCanvasRenderSymbolKey: Hashable {
  case generated(UUID)
  case pinned(UUID)
}

enum TesseraCanvasRenderEntry {
  case generated(ShapePlacementEngine.PlacedSymbolDescriptor, placementSequence: Int)
  case pinned(TesseraPinnedSymbol, sourceOrder: Int)

  var symbolKey: TesseraCanvasRenderSymbolKey {
    switch self {
    case let .generated(placedSymbol, _):
      .generated(placedSymbol.renderSymbolId)
    case let .pinned(pinnedSymbol, _):
      .pinned(pinnedSymbol.id)
    }
  }

  var renderOrder: RenderOrderKey {
    switch self {
    case let .generated(placedSymbol, placementSequence):
      RenderOrderKey(
        zIndex: placedSymbol.zIndex,
        layerOrder: RenderOrderLayer.generated.rawValue,
        sourceOrder: placedSymbol.sourceOrder,
        placementSequence: placementSequence,
      )
    case let .pinned(pinnedSymbol, sourceOrder):
      RenderOrderKey(
        zIndex: pinnedSymbol.zIndex,
        layerOrder: RenderOrderLayer.pinned.rawValue,
        sourceOrder: sourceOrder,
        placementSequence: sourceOrder,
      )
    }
  }
}

func makeOrderedTesseraCanvasRenderEntries(
  placedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor],
  pinnedSymbols: [TesseraPinnedSymbol],
) -> [TesseraCanvasRenderEntry] {
  let generatedEntries = placedSymbolDescriptors.enumerated().map { placementSequence, placedSymbol in
    TesseraCanvasRenderEntry.generated(placedSymbol, placementSequence: placementSequence)
  }
  let pinnedEntries = pinnedSymbols.enumerated().map { sourceOrder, pinnedSymbol in
    TesseraCanvasRenderEntry.pinned(pinnedSymbol, sourceOrder: sourceOrder)
  }

  return ShapePlacementOrdering.ordered(generatedEntries + pinnedEntries) { _, entry in
    entry.renderOrder
  }
}

func makeTesseraCanvasRenderEntriesPreservingPlacementOrder(
  placedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor],
  pinnedSymbols: [TesseraPinnedSymbol],
) -> [TesseraCanvasRenderEntry] {
  let generatedEntries = placedSymbolDescriptors.enumerated().map { placementSequence, placedSymbol in
    TesseraCanvasRenderEntry.generated(placedSymbol, placementSequence: placementSequence)
  }
  let pinnedEntries = pinnedSymbols.enumerated().map { sourceOrder, pinnedSymbol in
    TesseraCanvasRenderEntry.pinned(pinnedSymbol, sourceOrder: sourceOrder)
  }

  // Placement snapshots preserve the caller's generated order and still keep pinned symbols above them.
  return generatedEntries + pinnedEntries
}
