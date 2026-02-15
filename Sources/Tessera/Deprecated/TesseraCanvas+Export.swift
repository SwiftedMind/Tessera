// By Dennis Müller

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

public extension TesseraCanvas {
  /// Renders the tessera canvas to a PNG file.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.png` is appended automatically.
  ///   - canvasSize: The size of the canvas to export.
  ///   - backgroundColor: Optional background fill rendered behind the canvas. Defaults to no background
  /// (transparent).
  ///   - colorScheme: Optional SwiftUI color scheme override applied while rendering. Useful when symbols use semantic
  /// colors such as `Color.primary`.
  ///   - options: Rendering configuration such as output pixel size and scale.
  /// - Returns: The resolved file URL that was written.
  @MainActor @discardableResult func renderPNG(
    to directory: URL,
    fileName: String = "tessera-canvas",
    canvasSize: CGSize,
    backgroundColor: Color? = nil,
    colorScheme: ColorScheme? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(),
  ) throws -> URL {
    var renderConfiguration = configuration
    if case var .organic(organicPlacement) = renderConfiguration.placement {
      organicPlacement.showsCollisionOverlay = options.showsCollisionOverlay
      renderConfiguration.placement = .organic(organicPlacement)
    }
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "png")
    let resolvedAlphaMask = region.resolvedAlphaMask(in: canvasSize)
    let placedSymbolDescriptors = makeSynchronousPlacedDescriptors(
      for: canvasSize,
      resolvedAlphaMask: resolvedAlphaMask,
    )
    let renderView = TesseraCanvasStaticRenderView(
      configuration: renderConfiguration,
      canvasSize: canvasSize,
      region: region,
      regionRendering: regionRendering,
      pinnedSymbols: pinnedSymbols,
      placedSymbolDescriptors: placedSymbolDescriptors,
      resolvedAlphaMask: resolvedAlphaMask,
      edgeBehavior: effectiveEdgeBehavior,
      rendersAsynchronously: rendersAsynchronously,
    )
    let exportView = TesseraCanvasExportRenderView(
      pageSize: canvasSize,
      backgroundColor: backgroundColor,
      content: renderView,
    )
    let rendererContent = if let colorScheme {
      AnyView(exportView.environment(\.colorScheme, colorScheme))
    } else {
      AnyView(exportView)
    }
    let renderer = ImageRenderer(content: rendererContent)
    renderer.proposedSize = ProposedViewSize(canvasSize)
    renderer.scale = options.resolvedScale(contentSize: canvasSize)
    renderer.isOpaque = options.isOpaque
    renderer.colorMode = options.colorMode

    guard let cgImage = renderer.cgImage else {
      throw TesseraRenderError.failedToCreateImage
    }
    guard let destination = CGImageDestinationCreateWithURL(
      destinationURL as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil,
    ) else {
      throw TesseraRenderError.failedToCreateDestination
    }

    CGImageDestinationAddImage(destination, cgImage, nil)

    guard CGImageDestinationFinalize(destination) else {
      throw TesseraRenderError.failedToFinalizeDestination
    }

    return destinationURL
  }

  /// Renders the tessera canvas to a PDF file, preserving vector content when possible.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.pdf` is appended automatically.
  ///   - canvasSize: The size of the canvas to export.
  ///   - backgroundColor: Optional background fill rendered behind the canvas. Defaults to no background
  /// (transparent).
  ///   - colorScheme: Optional SwiftUI color scheme override applied while rendering. Useful when symbols use semantic
  /// colors such as `Color.primary`.
  ///   - pageSize: Optional PDF page size in points; defaults to the canvas size.
  ///   - options: Rendering configuration such as output pixel size and scale, applied while drawing into the PDF
  /// context.
  /// - Returns: The resolved file URL that was written.
  @MainActor @discardableResult func renderPDF(
    to directory: URL,
    fileName: String = "tessera-canvas",
    canvasSize: CGSize,
    backgroundColor: Color? = nil,
    colorScheme: ColorScheme? = nil,
    pageSize: CGSize? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(scale: 1),
  ) throws -> URL {
    var renderConfiguration = configuration
    if case var .organic(organicPlacement) = renderConfiguration.placement {
      organicPlacement.showsCollisionOverlay = options.showsCollisionOverlay
      renderConfiguration.placement = .organic(organicPlacement)
    }
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "pdf")
    let renderSize = pageSize ?? canvasSize
    var mediaBox = CGRect(origin: .zero, size: renderSize)

    guard
      let consumer = CGDataConsumer(url: destinationURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else {
      throw TesseraRenderError.failedToCreateDestination
    }

    let resolvedAlphaMask = region.resolvedAlphaMask(in: canvasSize)
    let placedSymbolDescriptors = makeSynchronousPlacedDescriptors(
      for: canvasSize,
      resolvedAlphaMask: resolvedAlphaMask,
    )
    let renderView = TesseraCanvasStaticRenderView(
      configuration: renderConfiguration,
      canvasSize: canvasSize,
      region: region,
      regionRendering: regionRendering,
      pinnedSymbols: pinnedSymbols,
      placedSymbolDescriptors: placedSymbolDescriptors,
      resolvedAlphaMask: resolvedAlphaMask,
      edgeBehavior: effectiveEdgeBehavior,
      rendersAsynchronously: rendersAsynchronously,
    )
    let exportView = TesseraCanvasExportRenderView(
      pageSize: renderSize,
      backgroundColor: backgroundColor,
      content: renderView,
    )
    let rendererContent = if let colorScheme {
      AnyView(exportView.environment(\.colorScheme, colorScheme))
    } else {
      AnyView(exportView)
    }
    let renderer = ImageRenderer(content: rendererContent)
    renderer.proposedSize = ProposedViewSize(renderSize)
    renderer.scale = options.resolvedScale(contentSize: canvasSize)
    renderer.isOpaque = options.isOpaque
    renderer.colorMode = options.colorMode
    let rasterizationScale = options.resolvedScale(contentSize: canvasSize)

    renderer.render(rasterizationScale: rasterizationScale) { _, render in
      context.beginPDFPage(nil)
      render(context)
      context.endPDFPage()
      context.closePDF()
    }

    return destinationURL
  }

  private func resolvedOutputURL(directory: URL, fileName: String, fileExtension: String) -> URL {
    let baseName = (fileName as NSString).deletingPathExtension
    return directory
      .appending(path: baseName)
      .appendingPathExtension(fileExtension)
  }
}

private struct TesseraCanvasExportRenderView<Content: View>: View {
  var pageSize: CGSize
  var backgroundColor: Color?
  var content: Content

  var body: some View {
    ZStack {
      if let backgroundColor {
        backgroundColor
      }
      content
    }
    .frame(width: pageSize.width, height: pageSize.height)
    .clipped()
  }
}

private struct TesseraCanvasStaticRenderView: View {
  var configuration: TesseraConfiguration
  var canvasSize: CGSize
  var region: TesseraCanvasRegion
  var regionRendering: TesseraRegionRendering
  var pinnedSymbols: [TesseraPinnedSymbol]
  var placedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor]
  var resolvedAlphaMask: TesseraAlphaMask?
  var edgeBehavior: TesseraEdgeBehavior
  var rendersAsynchronously: Bool

  var body: some View {
    let isCollisionOverlayEnabled = configuration.showsCollisionOverlay
    let renderableLeafSymbols = configuration.symbols.uniqueRenderableLeafSymbols
    let clipPath = region.isPolygon && regionRendering == .clipped ? region.clipPath(in: canvasSize) : nil
    let alphaMaskView = region.isAlphaMask && regionRendering == .clipped
      ? resolvedAlphaMask?.maskView()
      : nil
    let overlayShapesBySymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? renderableLeafSymbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]
    let overlayShapesByPinnedSymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? pinnedSymbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]

    let baseCanvas = Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: rendersAsynchronously,
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
        guard let symbol = context.resolveSymbol(id: placedSymbol.renderSymbolId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.x + wrappedOffset.width, y: offset.y + wrappedOffset.height)
          symbolContext.translateBy(x: placedSymbol.position.x, y: placedSymbol.position.y)
          symbolContext.rotate(by: .radians(placedSymbol.rotationRadians))
          symbolContext.scaleBy(x: placedSymbol.scale, y: placedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)

          if isCollisionOverlayEnabled,
             let overlayShape = overlayShapesBySymbolId[placedSymbol.renderSymbolId] {
            CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
          }
        }
      }
    } symbols: {
      ForEach(renderableLeafSymbols) { symbol in
        symbol.makeView().tag(symbol.id)
      }
    }

    let compositeCanvas = baseCanvas
      .overlay {
        if pinnedSymbols.isEmpty == false {
          Canvas(
            opaque: false,
            colorMode: .nonLinear,
            rendersAsynchronously: rendersAsynchronously,
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
  }
}
