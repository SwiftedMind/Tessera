// By Dennis Müller

import SwiftUI

/// Renders a single tessera tile into a cached symbol.
struct TesseraCanvasTile: View {
  var tessera: Tessera
  var seed: UInt64

  var body: some View {
    Canvas { context, size in
      var randomGenerator = SeededGenerator(seed: seed)
      let placedItems = ShapePlacementEngine.placeItems(
        in: size,
        tessera: tessera,
        randomGenerator: &randomGenerator,
      )

      let offsets: [CGSize] = [
        .zero,
        CGSize(width: size.width, height: 0),
        CGSize(width: -size.width, height: 0),
        CGSize(width: 0, height: size.height),
        CGSize(width: 0, height: -size.height),
        CGSize(width: size.width, height: size.height),
        CGSize(width: size.width, height: -size.height),
        CGSize(width: -size.width, height: size.height),
        CGSize(width: -size.width, height: -size.height),
      ]

      for placedItem in placedItems {
        guard let symbol = context.resolveSymbol(id: placedItem.item.id) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width, y: offset.height)
          symbolContext.translateBy(x: placedItem.position.x, y: placedItem.position.y)
          symbolContext.rotate(by: placedItem.rotation)
          symbolContext.scaleBy(x: placedItem.scale, y: placedItem.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(tessera.items) { item in
        item.makeView().tag(item.id)
      }
    }
    .frame(width: tessera.size.width, height: tessera.size.height)
  }
}
