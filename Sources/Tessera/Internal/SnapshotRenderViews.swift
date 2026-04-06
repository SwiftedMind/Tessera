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
    let snapshotFingerprint = snapshot.fingerprint.rawValue
    let showsCollisionShapes = debugOverlay.showsCollisionShapes
    let highlightedSymbolIDs = debugOverlay.highlightedSymbolIDs
    let shouldClipPolygon = renderModel.region.isPolygon && renderModel.regionRendering == .clipped
    let shouldClipAlphaMask = renderModel.region.isAlphaMask && renderModel.regionRendering == .clipped
    let clipPath = shouldClipPolygon ? renderModel.region.clipPath(in: snapshot.size) : nil
    let globalAlphaMaskView: AnyView? = if shouldClipAlphaMask,
                                           let globalMask = renderModel.resolvedGlobalAlphaMask {
      SnapshotMaskImageCache.maskView(
        for: globalMask,
        snapshotFingerprint: snapshotFingerprint,
        role: .globalRegionMask,
      )
    } else {
      nil
    }

    let shouldRenderPinnedInBaseLayer = renderModel.mosaics.isEmpty

    let baseLayer = SnapshotPlacementCanvasView(
      symbols: renderModel.baseSymbols.uniqueRenderableLeafSymbols,
      placements: renderModel.basePlacements,
      pinnedSymbols: shouldRenderPinnedInBaseLayer ? renderModel.pinnedSymbols : [],
      size: snapshot.size,
      edgeBehavior: renderModel.edgeBehavior,
      offset: renderModel.baseOffset,
      clipPath: clipPath,
      rendersAsynchronously: rendersAsynchronously,
      showsCollisionShapes: showsCollisionShapes,
      highlightedSymbolIDs: highlightedSymbolIDs,
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
                showsCollisionShapes: showsCollisionShapes,
                highlightedSymbolIDs: highlightedSymbolIDs,
              )

              if mosaic.rendering.clipsToMask {
                mosaicLayer.mask {
                  SnapshotMosaicMaskSymbolView(
                    mask: mosaic.maskDefinition,
                    size: snapshot.size,
                  )
                }
              } else {
                mosaicLayer
              }
            }
          }
        }
      }
      .overlay {
        if renderModel.mosaics.isEmpty == false, renderModel.pinnedSymbols.isEmpty == false {
          SnapshotPinnedCanvasView(
            pinnedSymbols: renderModel.pinnedSymbols,
            size: snapshot.size,
            edgeBehavior: renderModel.edgeBehavior,
            clipPath: clipPath,
            rendersAsynchronously: rendersAsynchronously,
            showsCollisionShapes: showsCollisionShapes,
            highlightedSymbolIDs: highlightedSymbolIDs,
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

/// Draws pinned symbols as a dedicated top-most layer.
private struct SnapshotPinnedCanvasView: View {
  var pinnedSymbols: [PinnedSymbol]
  var size: CGSize
  var edgeBehavior: TesseraEdgeBehavior
  var clipPath: Path?
  var rendersAsynchronously: Bool
  var showsCollisionShapes: Bool
  var highlightedSymbolIDs: Set<UUID>

  var body: some View {
    SnapshotPlacementCanvasView(
      symbols: [],
      placements: [],
      pinnedSymbols: pinnedSymbols,
      size: size,
      edgeBehavior: edgeBehavior,
      offset: .zero,
      clipPath: clipPath,
      rendersAsynchronously: rendersAsynchronously,
      showsCollisionShapes: showsCollisionShapes,
      highlightedSymbolIDs: highlightedSymbolIDs,
    )
  }
}

/// Optional debug layer that visualizes effective mosaic masks.
private struct SnapshotMosaicMaskDebugOverlayView: View {
  var mosaics: [SnapshotMosaicLayer]
  var size: CGSize
  var clipPath: Path?
  var debugOverlay: TesseraDebugOverlay

  var body: some View {
    if let opacity = debugOverlay.resolvedMosaicMaskOpacity, mosaics.isEmpty == false {
      let overlay = ZStack {
        ForEach(Array(mosaics.enumerated()), id: \.element.id) { index, mosaic in
          let symbolMask = SnapshotMosaicMaskSymbolView(
            mask: mosaic.maskDefinition,
            size: size,
          )
          let tinted = Rectangle().fill(debugColor(for: index).opacity(opacity))
          tinted.mask { symbolMask }
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

private struct SnapshotMosaicMaskSymbolView: View {
  var mask: MosaicMask
  var size: CGSize

  var body: some View {
    mask.symbol.makeView()
      .rotationEffect(mask.rotation)
      .scaleEffect(mask.scale)
      .position(mask.position.resolvedPoint(in: size))
      .frame(width: size.width, height: size.height, alignment: .topLeading)
  }
}

@MainActor
enum SnapshotMaskImageCache {
  enum Role: Hashable {
    case globalRegionMask
    case mosaic(UUID)
  }

  static let maximumSnapshotCount = 4
  static var imagesBySnapshotFingerprint: [UInt64: [Role: CGImage]] = [:]
  static var recentSnapshotFingerprints: [UInt64] = []

  #if DEBUG
  static var generatedImageCount = 0
  #endif

  static func maskView(
    for mask: TesseraAlphaMask,
    snapshotFingerprint: UInt64,
    role: Role,
  ) -> AnyView? {
    guard let image = image(
      for: mask,
      snapshotFingerprint: snapshotFingerprint,
      role: role,
    ) else {
      return nil
    }

    let scale = max(mask.pixelScale, 0.1)
    return AnyView(
      Image(decorative: image, scale: scale, orientation: .up)
        .interpolation(.none)
        .frame(width: mask.size.width, height: mask.size.height),
    )
  }

  static func maskView(
    for mask: SliceAlphaMask,
    snapshotFingerprint: UInt64,
    role: Role,
  ) -> AnyView? {
    guard let image = image(
      for: mask,
      snapshotFingerprint: snapshotFingerprint,
      role: role,
    ) else {
      return nil
    }

    let scale = max(mask.pixelScale, 0.1)
    let sliceFrame = mask.sliceFrameInCanvas
    return AnyView(
      Image(decorative: image, scale: scale, orientation: .up)
        .interpolation(.none)
        .frame(width: sliceFrame.width, height: sliceFrame.height)
        .position(x: sliceFrame.midX, y: sliceFrame.midY)
        .frame(width: mask.rasterSize.width, height: mask.rasterSize.height, alignment: .topLeading),
    )
  }

  private static func image(
    for mask: TesseraAlphaMask,
    snapshotFingerprint: UInt64,
    role: Role,
  ) -> CGImage? {
    if let cachedImage = imagesBySnapshotFingerprint[snapshotFingerprint]?[role] {
      markSnapshotAsRecentlyUsed(snapshotFingerprint)
      return cachedImage
    }

    guard let generatedImage = mask.maskImage() else { return nil }

    #if DEBUG
    generatedImageCount += 1
    #endif

    var snapshotImages = imagesBySnapshotFingerprint[snapshotFingerprint] ?? [:]
    snapshotImages[role] = generatedImage
    imagesBySnapshotFingerprint[snapshotFingerprint] = snapshotImages
    markSnapshotAsRecentlyUsed(snapshotFingerprint)
    pruneIfNeeded()
    return generatedImage
  }

  private static func image(
    for mask: SliceAlphaMask,
    snapshotFingerprint: UInt64,
    role: Role,
  ) -> CGImage? {
    if let cachedImage = imagesBySnapshotFingerprint[snapshotFingerprint]?[role] {
      markSnapshotAsRecentlyUsed(snapshotFingerprint)
      return cachedImage
    }

    guard let generatedImage = mask.sliceImage() else { return nil }

    #if DEBUG
    generatedImageCount += 1
    #endif

    var snapshotImages = imagesBySnapshotFingerprint[snapshotFingerprint] ?? [:]
    snapshotImages[role] = generatedImage
    imagesBySnapshotFingerprint[snapshotFingerprint] = snapshotImages
    markSnapshotAsRecentlyUsed(snapshotFingerprint)
    pruneIfNeeded()
    return generatedImage
  }

  private static func markSnapshotAsRecentlyUsed(_ snapshotFingerprint: UInt64) {
    if let existingIndex = recentSnapshotFingerprints.firstIndex(of: snapshotFingerprint) {
      recentSnapshotFingerprints.remove(at: existingIndex)
    }
    recentSnapshotFingerprints.append(snapshotFingerprint)
  }

  static func pruneIfNeeded() {
    guard imagesBySnapshotFingerprint.count > maximumSnapshotCount else { return }

    while imagesBySnapshotFingerprint.count > maximumSnapshotCount, recentSnapshotFingerprints.isEmpty == false {
      let oldestSnapshotFingerprint = recentSnapshotFingerprints.removeFirst()
      imagesBySnapshotFingerprint.removeValue(forKey: oldestSnapshotFingerprint)
    }
  }

  #if DEBUG
  static func testingReset() {
    imagesBySnapshotFingerprint.removeAll()
    recentSnapshotFingerprints.removeAll()
    generatedImageCount = 0
  }

  static func testingGeneratedImageCount() -> Int {
    generatedImageCount
  }
  #endif
}

/// Draws generated symbol placements for one render layer.
private struct SnapshotPlacementCanvasView: View {
  var symbols: [Symbol]
  var placements: [SnapshotPlacementDescriptor]
  var pinnedSymbols: [PinnedSymbol] = []
  var size: CGSize
  var edgeBehavior: TesseraEdgeBehavior
  var offset: CGSize
  var clipPath: Path?
  var rendersAsynchronously: Bool
  var showsCollisionShapes: Bool
  var highlightedSymbolIDs: Set<UUID>

  var body: some View {
    let orderedRenderEntries = makeOrderedSnapshotRenderEntries(
      placements: placements,
      pinnedSymbols: pinnedSymbols,
    )
    let overlayShapesBySymbolID: [UUID: CollisionOverlayShape] = showsCollisionShapes
      ? symbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]
    let overlayShapesByPinnedSymbolID: [UUID: CollisionOverlayShape] = showsCollisionShapes
      ? pinnedSymbols.reduce(into: [:]) { cache, pinnedSymbol in
        cache[pinnedSymbol.id] = CollisionOverlayShape(collisionShape: pinnedSymbol.collisionShape)
      }
      : [:]
    let highlightedRenderSymbolIDs: Set<UUID> = highlightedSymbolIDs.isEmpty
      ? Set()
      : Set(
        placements.compactMap { placement in
          guard highlightedSymbolIDs.contains(placement.symbolId) || highlightedSymbolIDs
            .contains(placement.renderSymbolId)
          else {
            return nil
          }

          return placement.renderSymbolId
        },
      )

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

      for entry in orderedRenderEntries {
        switch entry {
        case let .generated(placedSymbol, _):
          guard let symbol = context.resolveSymbol(id: entry.symbolKey) else { continue }

          for wrapOffset in offsets {
            var symbolContext = context
            symbolContext.translateBy(
              x: wrapOffset.x + wrappedOffset.width,
              y: wrapOffset.y + wrappedOffset.height,
            )

            if let clipRect = placedSymbol.clipRect {
              symbolContext.clip(to: Path(clipRect))
            }
            symbolContext.translateBy(x: placedSymbol.position.x, y: placedSymbol.position.y)
            symbolContext.rotate(by: .radians(placedSymbol.rotationRadians))
            symbolContext.scaleBy(x: placedSymbol.scale, y: placedSymbol.scale)
            symbolContext.draw(symbol, at: .zero, anchor: .center)

            if showsCollisionShapes,
               let overlayShape = overlayShapesBySymbolID[placedSymbol.renderSymbolId] {
              CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
            }
          }
        case let .pinned(pinnedSymbol, _):
          guard let symbol = context.resolveSymbol(id: entry.symbolKey) else { continue }

          let resolvedPosition = pinnedSymbol.resolvedPosition(in: drawSize)

          for wrapOffset in offsets {
            var symbolContext = context
            symbolContext.translateBy(x: wrapOffset.x, y: wrapOffset.y)
            symbolContext.translateBy(x: resolvedPosition.x, y: resolvedPosition.y)
            symbolContext.rotate(by: pinnedSymbol.rotation)
            symbolContext.scaleBy(x: pinnedSymbol.scale, y: pinnedSymbol.scale)
            symbolContext.draw(symbol, at: .zero, anchor: .center)

            if showsCollisionShapes,
               let overlayShape = overlayShapesByPinnedSymbolID[pinnedSymbol.id] {
              CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
            }
          }
        }
      }
    } symbols: {
      ForEach(symbols) { symbol in
        renderableSymbolView(
          for: symbol,
          isHighlighted: highlightedRenderSymbolIDs.contains(symbol.id),
        )
        .tag(SnapshotRenderSymbolKey.generated(symbol.id))
      }
      ForEach(pinnedSymbols) { pinnedSymbol in
        renderablePinnedSymbolView(
          for: pinnedSymbol,
          isHighlighted: highlightedSymbolIDs.contains(pinnedSymbol.id),
        )
        .tag(SnapshotRenderSymbolKey.pinned(pinnedSymbol.id))
      }
    }
    .frame(width: size.width, height: size.height)
    .clipped()
  }

  @ViewBuilder
  private func renderableSymbolView(for symbol: Symbol, isHighlighted: Bool) -> some View {
    if isHighlighted {
      symbol.makeView()
        .overlay {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.accentColor.opacity(0.9), lineWidth: 2)
            .padding(1)
        }
    } else {
      symbol.makeView()
    }
  }

  @ViewBuilder
  private func renderablePinnedSymbolView(
    for pinnedSymbol: PinnedSymbol,
    isHighlighted: Bool,
  ) -> some View {
    if isHighlighted {
      pinnedSymbol.makeView()
        .overlay {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.accentColor.opacity(0.9), lineWidth: 2)
            .padding(1)
        }
    } else {
      pinnedSymbol.makeView()
    }
  }
}

private enum SnapshotRenderSymbolKey: Hashable {
  case generated(UUID)
  case pinned(UUID)
}

private enum SnapshotRenderEntry {
  case generated(SnapshotPlacementDescriptor, placementSequence: Int)
  case pinned(PinnedSymbol, sourceOrder: Int)

  var symbolKey: SnapshotRenderSymbolKey {
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

private func makeOrderedSnapshotRenderEntries(
  placements: [SnapshotPlacementDescriptor],
  pinnedSymbols: [PinnedSymbol],
) -> [SnapshotRenderEntry] {
  let generatedEntries = placements.enumerated().map { placementSequence, placedSymbol in
    SnapshotRenderEntry.generated(placedSymbol, placementSequence: placementSequence)
  }
  let pinnedEntries = pinnedSymbols.enumerated().map { sourceOrder, pinnedSymbol in
    SnapshotRenderEntry.pinned(pinnedSymbol, sourceOrder: sourceOrder)
  }

  return ShapePlacementOrdering.ordered(generatedEntries + pinnedEntries) { _, entry in
    entry.renderOrder
  }
}
