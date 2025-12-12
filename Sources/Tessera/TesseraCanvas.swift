// By Dennis Müller

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Defines how a tessera canvas treats its edges.
public enum TesseraCanvasEdgeBehavior: Sendable {
  /// No wrapping. Items are clipped at the canvas bounds.
  case finite
  /// Toroidal wrapping like a tile, producing a seamlessly tileable canvas.
  case seamlessWrapping
}

/// A fixed view placed once into a finite tessera canvas.
///
/// Fixed placements participate in collision checks so generated items fill around them.
public struct TesseraFixedPlacement: Identifiable {
  public var id: UUID
  /// Center position in canvas coordinates (origin at top-left).
  public var position: CGPoint
  /// Rotation applied to drawing and collision checks.
  public var rotation: Angle
  /// Uniform scale applied to drawing and collision checks.
  public var scale: CGFloat
  /// Collision geometry used as an obstacle for generated items.
  public var collisionShape: CollisionShape
  private let builder: () -> AnyView

  /// Creates a fixed placement.
  /// - Parameters:
  ///   - position: Center position in canvas space.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - collisionShape: Obstacle shape in local space, centered on origin.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    collisionShape: CollisionShape,
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.id = id
    self.position = position
    self.rotation = rotation
    self.scale = scale
    self.collisionShape = collisionShape
    builder = { AnyView(content()) }
  }

  /// Convenience initializer that derives a circular collision shape from an approximate size.
  /// - Parameters:
  ///   - position: Center position in canvas space.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - approximateSize: Size used to build a conservative circular collider.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    approximateSize: CGSize = CGSize(width: 30, height: 30),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    let radius = hypot(approximateSize.width, approximateSize.height) / 2
    self.init(
      id: id,
      position: position,
      rotation: rotation,
      scale: scale,
      collisionShape: .circle(radius: radius),
      content: content,
    )
  }

  @ViewBuilder
  func makeView() -> some View {
    builder()
  }
}

/// Fills a finite canvas once using a tessera configuration, respecting fixed placements.
public struct TesseraCanvas: View {
  public var configuration: TesseraConfiguration
  public var canvasSize: CGSize
  public var fixedPlacements: [TesseraFixedPlacement]
  public var seed: UInt64
  public var edgeBehavior: TesseraCanvasEdgeBehavior

  /// Creates a finite tessera canvas.
  /// - Parameters:
  ///   - configuration: Base configuration (items, spacing, density, seed).
  ///   - canvasSize: The full output size to fill (e.g. 1920×1080, 3840×2160).
  ///   - fixedPlacements: Views placed once; treated as obstacles.
  ///   - seed: Optional override for deterministic output.
  ///   - edgeBehavior: Whether to wrap edges toroidally or not.
  public init(
    _ configuration: TesseraConfiguration,
    canvasSize: CGSize,
    fixedPlacements: [TesseraFixedPlacement] = [],
    seed: UInt64? = nil,
    edgeBehavior: TesseraCanvasEdgeBehavior = .finite,
  ) {
    self.configuration = configuration
    self.canvasSize = canvasSize
    self.fixedPlacements = fixedPlacements
    self.seed = seed ?? configuration.seed
    self.edgeBehavior = edgeBehavior
  }

  public var body: some View {
    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
      let wrappedOffset = CGSize(
        width: configuration.patternOffset.width.truncatingRemainder(dividingBy: size.width),
        height: configuration.patternOffset.height.truncatingRemainder(dividingBy: size.height),
      )

      var randomGenerator = SeededGenerator(seed: seed)
      let placedItems = ShapePlacementEngine.placeItems(
        in: size,
        configuration: configuration,
        fixedPlacements: fixedPlacements,
        edgeBehavior: edgeBehavior,
        randomGenerator: &randomGenerator,
      )

      let offsets: [CGSize] = switch edgeBehavior {
      case .finite:
        [.zero]
      case .seamlessWrapping:
        [
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
      }

      for fixedPlacement in fixedPlacements {
        guard let symbol = context.resolveSymbol(id: fixedPlacement.id) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width, y: offset.height)
          symbolContext.translateBy(x: fixedPlacement.position.x, y: fixedPlacement.position.y)
          symbolContext.rotate(by: fixedPlacement.rotation)
          symbolContext.scaleBy(x: fixedPlacement.scale, y: fixedPlacement.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }

      for placedItem in placedItems {
        guard let symbol = context.resolveSymbol(id: placedItem.item.id) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width + wrappedOffset.width, y: offset.height + wrappedOffset.height)
          symbolContext.translateBy(x: placedItem.position.x, y: placedItem.position.y)
          symbolContext.rotate(by: placedItem.rotation)
          symbolContext.scaleBy(x: placedItem.scale, y: placedItem.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(configuration.items) { item in
        item.makeView().tag(item.id)
      }
      ForEach(fixedPlacements) { placement in
        placement.makeView().tag(placement.id)
      }
    }
    .frame(width: canvasSize.width, height: canvasSize.height)
    .clipped()
  }

  /// Renders the tessera canvas to a PNG file.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.png` is appended automatically.
  ///   - options: Rendering configuration such as output pixel size and scale.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPNG(
    to directory: URL,
    fileName: String = "tessera-canvas",
    options: TesseraRenderOptions = TesseraRenderOptions(),
  ) throws -> URL {
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "png")
    let renderer = makeRenderer(options: options)

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
  ///   - pageSize: Optional PDF page size in points; defaults to the canvas size.
  ///   - options: Rendering configuration such as output pixel size and scale, applied while drawing into the PDF
  /// context.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPDF(
    to directory: URL,
    fileName: String = "tessera-canvas",
    pageSize: CGSize? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(scale: 1),
  ) throws -> URL {
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "pdf")
    let renderSize = pageSize ?? canvasSize
    var mediaBox = CGRect(origin: .zero, size: renderSize)

    guard
      let consumer = CGDataConsumer(url: destinationURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else {
      throw TesseraRenderError.failedToCreateDestination
    }

    let renderer = makeRenderer(options: options)
    let rasterizationScale = options.resolvedScale(contentSize: canvasSize)

    renderer.render(rasterizationScale: rasterizationScale) { size, render in
      context.beginPDFPage(nil)
      let offsetX = (renderSize.width - size.width) / 2
      let offsetY = (renderSize.height - size.height) / 2
      context.translateBy(x: offsetX, y: offsetY)
      render(context)
      context.endPDFPage()
      context.closePDF()
    }

    return destinationURL
  }

  private func makeRenderer(options: TesseraRenderOptions) -> ImageRenderer<TesseraCanvas> {
    let renderer = ImageRenderer(content: self)
    renderer.proposedSize = ProposedViewSize(canvasSize)
    renderer.scale = options.resolvedScale(contentSize: canvasSize)
    renderer.isOpaque = options.isOpaque
    renderer.colorMode = options.colorMode
    return renderer
  }

  private func resolvedOutputURL(directory: URL, fileName: String, fileExtension: String) -> URL {
    let baseName = (fileName as NSString).deletingPathExtension
    return directory
      .appending(path: baseName)
      .appendingPathExtension(fileExtension)
  }
}
