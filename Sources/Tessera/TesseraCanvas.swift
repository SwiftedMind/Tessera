// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// Defines how a tessera canvas treats its edges.
public enum TesseraEdgeBehavior: Sendable {
  /// No wrapping. Symbols are clipped at the canvas bounds.
  case finite
  /// Toroidal wrapping like a tile, producing a seamlessly tileable canvas.
  case seamlessWrapping
}

/// Defines how a tessera canvas renders a region.
public enum TesseraRegionRendering: Sendable, Hashable {
  /// Clips drawing to the region.
  case clipped
  /// Draws symbols without clipping, while still constraining placement to the region.
  case unclipped
}

/// Fills a finite canvas once using a tessera configuration, respecting fixed symbols.
public struct TesseraCanvas: View {
  public var configuration: TesseraConfiguration
  public var pinnedSymbols: [TesseraPinnedSymbol]
  public var seed: UInt64
  public var edgeBehavior: TesseraEdgeBehavior
  /// Region used to clip rendering and constrain placement.
  public var region: TesseraCanvasRegion
  /// Defines how regions are rendered.
  public var regionRendering: TesseraRegionRendering
  /// Controls whether the underlying SwiftUI canvas renders asynchronously.
  public var rendersAsynchronously: Bool
  public var onComputationStateChange: ((Bool) -> Void)?

  // swiftformat:disable privateStateVariables
  @State var cachedPlacedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor] = []
  @State var cachedAlphaMask: TesseraAlphaMask?
  @State var cachedAlphaMaskCGImage: CGImage?
  @State var cachedAlphaMaskCGImageScale: CGFloat = 1
  @State var activeComputationKey: ComputationKey?
  // swiftformat:enable privateStateVariables

  /// Creates a finite tessera canvas.
  /// - Parameters:
  ///   - configuration: Base configuration (symbols and placement).
  ///   - pinnedSymbols: Views placed once; treated as obstacles.
  ///   - seed: Optional seed override for organic placement.
  ///   - edgeBehavior: Whether to wrap edges toroidally or not.
  ///   - region: Region used to clip rendering and constrain placement. Polygon and alpha mask regions always use
  ///     finite edges.
  ///   - regionRendering: Defines whether drawing is clipped to the region.
  ///   - rendersAsynchronously: Whether the SwiftUI canvas renders asynchronously. Defaults to `false` to keep
  ///     interactive transforms in sync.
  ///
  /// The canvas fills the space provided by layout. Set an explicit `.frame(...)` on this view when you need a fixed
  /// on-screen size.
  public init(
    _ configuration: TesseraConfiguration,
    pinnedSymbols: [TesseraPinnedSymbol] = [],
    seed: UInt64? = nil,
    edgeBehavior: TesseraEdgeBehavior = .finite,
    region: TesseraCanvasRegion = .rectangle,
    regionRendering: TesseraRegionRendering = .clipped,
    rendersAsynchronously: Bool = false,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.pinnedSymbols = pinnedSymbols
    self.seed = seed ?? configuration.organicPlacement?.seed ?? TesseraConfiguration.randomSeed()
    self.edgeBehavior = edgeBehavior
    self.region = region
    self.regionRendering = regionRendering
    self.rendersAsynchronously = rendersAsynchronously
    self.onComputationStateChange = onComputationStateChange
  }

  public var body: some View {
    GeometryReader { proxy in
      canvasBody(canvasSize: proxy.size)
    }
  }

  /// Renders the canvas content while driving placement computation from the resolved layout size.
  ///
  /// This avoids relying on preference propagation for initial size resolution, which can otherwise result in a
  /// missed first placement computation during view creation and window restoration.
  private func canvasBody(canvasSize: CGSize) -> some View {
    let configuration = configuration
    let pinnedSymbols = pinnedSymbols
    let edgeBehavior = effectiveEdgeBehavior
    let region = region
    let clipPath = shouldClipPolygon ? region.clipPath(in: canvasSize) : nil
    let alphaMaskView = shouldClipAlphaMask ? cachedAlphaMaskView(in: canvasSize) : nil
    let shouldHideUntilAlphaMaskReady = shouldClipAlphaMask && cachedAlphaMask == nil
    let placedSymbolDescriptors = cachedPlacedSymbolDescriptors
    let onComputationStateChange = onComputationStateChange
    let rendersAsynchronously = rendersAsynchronously
    let isCollisionOverlayEnabled = configuration.showsCollisionOverlay
    let overlayShapesBySymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? configuration.symbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]
    let overlayShapesByPinnedSymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? pinnedSymbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]

    let computationKey = makeComputationKey(for: canvasSize)

    // Default to synchronous rendering to avoid stale-frame flashes during interactive transforms.
    let baseCanvas = Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: rendersAsynchronously
    ) { context, size in
      guard size.width > 0, size.height > 0 else { return }

      if let clipPath {
        context.clip(to: clipPath)
      }

      let wrappedOffset = CGSize(
        width: configuration.patternOffset.width.truncatingRemainder(dividingBy: size.width),
        height: configuration.patternOffset.height.truncatingRemainder(dividingBy: size.height),
      )

      let offsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: edgeBehavior)

      for placedSymbol in placedSymbolDescriptors {
        guard let symbol = context.resolveSymbol(id: placedSymbol.symbolId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.x + wrappedOffset.width, y: offset.y + wrappedOffset.height)
          symbolContext.translateBy(x: placedSymbol.position.x, y: placedSymbol.position.y)
          symbolContext.rotate(by: .radians(placedSymbol.rotationRadians))
          symbolContext.scaleBy(x: placedSymbol.scale, y: placedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)

          if isCollisionOverlayEnabled,
             let overlayShape = overlayShapesBySymbolId[placedSymbol.symbolId] {
            CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
          }
        }
      }
    } symbols: {
      ForEach(configuration.symbols) { symbol in
        symbol.makeView().tag(symbol.id)
      }
    }

    let compositeCanvas = baseCanvas
      .overlay {
        if pinnedSymbols.isEmpty == false {
          // Keep the overlay in lockstep with the base canvas during interactive transforms.
          Canvas(
            opaque: false,
            colorMode: .nonLinear,
            rendersAsynchronously: rendersAsynchronously
          ) { context, size in
            guard size.width > 0, size.height > 0 else { return }

            if let clipPath {
              context.clip(to: clipPath)
            }

            let offsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: edgeBehavior)

            for pinnedSymbol in pinnedSymbols {
              guard let symbol = context.resolveSymbol(id: pinnedSymbol.id) else { continue }

              let resolvedPosition = pinnedSymbol.resolvedPosition(in: size)

              for offset in offsets {
                var symbolContext = context
                symbolContext.translateBy(x: offset.x, y: offset.y)
                symbolContext.translateBy(x: resolvedPosition.x, y: resolvedPosition.y)
                symbolContext.rotate(by: pinnedSymbol.rotation)
                symbolContext.scaleBy(x: pinnedSymbol.scale, y: pinnedSymbol.scale)
                symbolContext.draw(symbol, at: .zero, anchor: .center)

                if isCollisionOverlayEnabled,
                   let overlayShape = overlayShapesByPinnedSymbolId[pinnedSymbol.id] {
                  CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
                }
              }
            }
          } symbols: {
            ForEach(pinnedSymbols) { pinnedSymbol in
              pinnedSymbol.makeView().tag(pinnedSymbol.id)
            }
          }
        }
      }

    let clippedCanvas = Group {
      if let alphaMaskView {
        compositeCanvas.mask {
          alphaMaskView
        }
      } else {
        compositeCanvas
      }
    }

    return clippedCanvas
      .frame(width: canvasSize.width, height: canvasSize.height)
      .clipped()
      .opacity(shouldHideUntilAlphaMaskReady ? 0 : 1)
      .task(id: computationKey) {
        await MainActor.run {
          activeComputationKey = computationKey
          onComputationStateChange?(true)
        }
        defer {
          if Task.isCancelled == false {
            Task { @MainActor in
              onComputationStateChange?(false)
            }
          }
        }

        guard canvasSize.width > 0, canvasSize.height > 0 else {
          return
        }

        let resolvedAlphaMask = await MainActor.run {
          region.resolvedAlphaMask(in: canvasSize)
        }
        let resolvedMaskCGImage = resolvedAlphaMask?.maskImage()
        let resolvedMaskScale = resolvedAlphaMask?.pixelScale ?? 1
        let snapshot = makeComputationSnapshot(
          for: canvasSize,
          resolvedAlphaMask: resolvedAlphaMask,
        )
        await MainActor.run {
          guard activeComputationKey == snapshot.key else { return }

          cachedAlphaMask = resolvedAlphaMask
          cachedAlphaMaskCGImage = resolvedMaskCGImage
          cachedAlphaMaskCGImageScale = resolvedMaskScale
        }
        await computePlacements(
          key: snapshot.key,
          symbolDescriptors: snapshot.symbolDescriptors,
          pinnedSymbolDescriptors: snapshot.pinnedSymbolDescriptors,
          resolvedRegion: snapshot.resolvedRegion,
          resolvedAlphaMask: snapshot.resolvedAlphaMask,
        )
      }
  }

  private func cachedAlphaMaskView(in canvasSize: CGSize) -> AnyView? {
    guard let image = cachedAlphaMaskCGImage else { return nil }

    let scale = max(cachedAlphaMaskCGImageScale, 0.1)
    return AnyView(
      Image(decorative: image, scale: scale, orientation: .up)
        .interpolation(.none)
        .frame(width: canvasSize.width, height: canvasSize.height),
    )
  }
}

public extension TesseraCanvas {
  /// Returns a copy that controls whether the SwiftUI canvas renders asynchronously.
  func rendersAsynchronously(_ value: Bool) -> TesseraCanvas {
    var copy = self
    copy.rendersAsynchronously = value
    return copy
  }
}
