// By Dennis Müller

import SwiftUI

/// Repeats a rendered tile symbol to fill available space.
struct SnapshotTiledCanvasView<Tile: View>: View {
  var tileSize: CGSize
  var tileView: Tile
  var rendersAsynchronously: Bool

  var body: some View {
    Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: rendersAsynchronously,
    ) { context, size in
      guard tileSize.width > 0, tileSize.height > 0 else { return }
      guard let tile = context.resolveSymbol(id: 0) else { return }

      let columns = Int(ceil(size.width / tileSize.width))
      let rows = Int(ceil(size.height / tileSize.height))

      for row in 0..<rows {
        for column in 0..<columns {
          let x = CGFloat(column) * tileSize.width + tileSize.width / 2
          let y = CGFloat(row) * tileSize.height + tileSize.height / 2
          context.draw(tile, at: CGPoint(x: x, y: y), anchor: .center)
        }
      }
    } symbols: {
      tileView.tag(0)
    }
  }
}

/// Renders one fully resolved snapshot layer stack.
struct SnapshotStaticCanvasView: View {
  var snapshot: TesseraSnapshot
  var rendersAsynchronously: Bool
  var debugOverlay: TesseraDebugOverlay

  var body: some View {
    let renderModel = snapshot.renderModel
    let shouldClipPolygon = renderModel.region.isPolygon && renderModel.regionRendering == .clipped
    let shouldClipAlphaMask = renderModel.region.isAlphaMask && renderModel.regionRendering == .clipped
    let clipPath = shouldClipPolygon ? renderModel.region.clipPath(in: snapshot.size) : nil
    let globalAlphaMaskView = shouldClipAlphaMask ? renderModel.resolvedGlobalAlphaMask?.maskView() : nil

    let baseLayer = SnapshotPlacementCanvasView(
      symbols: renderModel.baseSymbols.uniqueRenderableLeafSymbols,
      placements: renderModel.basePlacements,
      size: snapshot.size,
      edgeBehavior: renderModel.edgeBehavior,
      offset: renderModel.baseOffset,
      clipPath: clipPath,
      rendersAsynchronously: rendersAsynchronously,
    )

    let layered = baseLayer
      .background {
        SnapshotMosaicMaskDebugOverlayView(
          mosaics: renderModel.mosaics,
          size: snapshot.size,
          clipPath: clipPath,
          debugOverlay: debugOverlay,
        )
      }
      .overlay {
        if renderModel.mosaics.isEmpty == false {
          ZStack {
            ForEach(renderModel.mosaics) { mosaic in
              let mosaicLayer = SnapshotPlacementCanvasView(
                symbols: mosaic.symbols.uniqueRenderableLeafSymbols,
                placements: mosaic.placements,
                size: snapshot.size,
                edgeBehavior: renderModel.edgeBehavior,
                offset: mosaic.offset,
                clipPath: clipPath,
                rendersAsynchronously: rendersAsynchronously,
              )

              if mosaic.rendering == .clipped,
                 let maskView = mosaic.mask.maskView() {
                mosaicLayer.mask {
                  maskView
                }
              } else {
                mosaicLayer
              }
            }
          }
        }
      }
      .overlay {
        if renderModel.pinnedSymbols.isEmpty == false {
          SnapshotPinnedCanvasView(
            pinnedSymbols: renderModel.pinnedSymbols,
            size: snapshot.size,
            edgeBehavior: renderModel.edgeBehavior,
            clipPath: clipPath,
            rendersAsynchronously: rendersAsynchronously,
          )
        }
      }

    Group {
      if let globalAlphaMaskView {
        layered.mask {
          globalAlphaMaskView
        }
      } else {
        layered
      }
    }
    .frame(width: snapshot.size.width, height: snapshot.size.height)
    .clipped()
  }
}

/// Optional debug layer that visualizes effective mosaic masks.
private struct SnapshotMosaicMaskDebugOverlayView: View {
  var mosaics: [SnapshotMosaicLayer]
  var size: CGSize
  var clipPath: Path?
  var debugOverlay: TesseraDebugOverlay

  @ViewBuilder
  var body: some View {
    if let opacity = debugOverlay.resolvedMosaicMaskOpacity, mosaics.isEmpty == false {
      let overlay = ZStack {
        ForEach(Array(mosaics.enumerated()), id: \.element.id) { index, mosaic in
          if let maskView = mosaic.mask.maskView() {
            Rectangle()
              .fill(debugColor(for: index).opacity(opacity))
              .mask {
                maskView
              }
          }
        }
      }
      .frame(width: size.width, height: size.height)

      if let clipPath {
        overlay.mask {
          clipPath.fill(Color.white)
        }
      } else {
        overlay
      }
    }
  }

  private func debugColor(for index: Int) -> Color {
    let palette: [Color] = [
      .cyan,
      .orange,
      .pink,
      .green,
      .yellow,
      .mint,
    ]
    return palette[index % palette.count]
  }
}

/// Draws generated symbol placements for one render layer.
private struct SnapshotPlacementCanvasView: View {
  var symbols: [Symbol]
  var placements: [SnapshotPlacementDescriptor]
  var size: CGSize
  var edgeBehavior: TesseraEdgeBehavior
  var offset: CGSize
  var clipPath: Path?
  var rendersAsynchronously: Bool

  var body: some View {
    Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: rendersAsynchronously,
    ) { context, drawSize in
      guard drawSize.width > 0, drawSize.height > 0 else { return }

      if let clipPath {
        context.clip(to: clipPath)
      }

      let wrappedOffset = CGSize(
        width: offset.width.truncatingRemainder(dividingBy: drawSize.width),
        height: offset.height.truncatingRemainder(dividingBy: drawSize.height),
      )
      let offsets = ShapePlacementWrapping.wrapOffsets(for: drawSize, edgeBehavior: edgeBehavior)

      for placedSymbol in placements {
        guard let symbol = context.resolveSymbol(id: placedSymbol.renderSymbolId) else { continue }

        for wrapOffset in offsets {
          var symbolContext = context
          symbolContext.translateBy(
            x: wrapOffset.x + wrappedOffset.width,
            y: wrapOffset.y + wrappedOffset.height,
          )
          symbolContext.translateBy(x: placedSymbol.position.x, y: placedSymbol.position.y)
          symbolContext.rotate(by: .radians(placedSymbol.rotationRadians))
          symbolContext.scaleBy(x: placedSymbol.scale, y: placedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(symbols) { symbol in
        symbol.makeView().tag(symbol.id)
      }
    }
    .frame(width: size.width, height: size.height)
    .clipped()
  }
}

/// Draws pinned symbols as the top-most layer.
private struct SnapshotPinnedCanvasView: View {
  var pinnedSymbols: [PinnedSymbol]
  var size: CGSize
  var edgeBehavior: TesseraEdgeBehavior
  var clipPath: Path?
  var rendersAsynchronously: Bool

  var body: some View {
    Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: rendersAsynchronously,
    ) { context, drawSize in
      guard drawSize.width > 0, drawSize.height > 0 else { return }

      if let clipPath {
        context.clip(to: clipPath)
      }

      let offsets = ShapePlacementWrapping.wrapOffsets(for: drawSize, edgeBehavior: edgeBehavior)
      for pinnedSymbol in pinnedSymbols {
        guard let symbol = context.resolveSymbol(id: pinnedSymbol.id) else { continue }

        let resolvedPosition = pinnedSymbol.resolvedPosition(in: drawSize)

        for wrapOffset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: wrapOffset.x, y: wrapOffset.y)
          symbolContext.translateBy(x: resolvedPosition.x, y: resolvedPosition.y)
          symbolContext.rotate(by: pinnedSymbol.rotation)
          symbolContext.scaleBy(x: pinnedSymbol.scale, y: pinnedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(pinnedSymbols) { pinnedSymbol in
        pinnedSymbol.makeView().tag(pinnedSymbol.id)
      }
    }
    .frame(width: size.width, height: size.height)
    .clipped()
  }
}
