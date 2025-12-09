// By Dennis Müller

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Describes a single tessellated pattern configuration.
public struct Tessera: View {
  public var size: CGSize
  public var items: [TesseraItem]
  public var seed: UInt64
  public var minimumSpacing: CGFloat
  /// Desired fill density between 0 and 1; scales how many items are attempted.
  public var density: Double
  public var baseScaleRange: ClosedRange<CGFloat>

  /// Creates a tessera definition.
  /// - Parameters:
  ///   - size: Size of the square tile that will be repeated.
  ///   - items: Items that can be placed inside each tile.
  ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
  ///   - minimumSpacing: Minimum distance between item centers.
  ///   - density: Desired fill density between 0 and 1.
  ///   - baseScaleRange: Default scale range applied when an item does not provide its own scale range.
  public init(
    size: CGSize,
    items: [TesseraItem],
    seed: UInt64 = Tessera.randomSeed(),
    minimumSpacing: CGFloat,
    density: Double = 0.5,
    baseScaleRange: ClosedRange<CGFloat> = 0.9...1.1,
  ) {
    self.size = size
    self.items = items
    self.seed = seed
    self.minimumSpacing = minimumSpacing
    self.density = density
    self.baseScaleRange = baseScaleRange
  }

  /// Renders the tessera as a single tile view.
  public var body: some View {
    TesseraCanvasTile(tessera: self, seed: seed)
  }

  /// Generates a new random seed.
  public static func randomSeed() -> UInt64 {
    UInt64.random(in: 1...UInt64.max)
  }

  /// Renders the tessera tile to a PNG file.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.png` is appended automatically.
  ///   - options: Rendering configuration such as output pixel size and scale.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPNG(
    to directory: URL,
    fileName: String = "tessera",
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

  /// Renders the tessera tile to a PDF file, preserving vector content when possible.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.pdf` is appended automatically.
  ///   - pageSize: Optional PDF page size in points; defaults to the tessera tile size.
  ///   - options: Rendering configuration such as output pixel size and scale, applied while drawing into the PDF
  /// context.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPDF(
    to directory: URL,
    fileName: String = "tessera",
    pageSize: CGSize? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(scale: 1),
  ) throws -> URL {
    let destinationURL = resolvedOutputURL(directory: directory, fileName: fileName, fileExtension: "pdf")
    let renderSize = pageSize ?? size
    var mediaBox = CGRect(origin: .zero, size: renderSize)

    guard
      let consumer = CGDataConsumer(url: destinationURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else {
      throw TesseraRenderError.failedToCreateDestination
    }

    let renderer = makeRenderer(options: options)

    let rasterizationScale = options.resolvedScale(tileSize: size)

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

  private func makeRenderer(options: TesseraRenderOptions) -> ImageRenderer<TesseraCanvasTile> {
    let renderer = ImageRenderer(content: TesseraCanvasTile(tessera: self, seed: seed))
    renderer.proposedSize = ProposedViewSize(size)
    renderer.scale = options.resolvedScale(tileSize: size)
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

/// Configuration options for exporting tessera tiles.
public struct TesseraRenderOptions {
  /// Desired pixel dimensions for the exported image. When set, the renderer picks a scale that matches this pixel size
  /// based on the tessera's tile size.
  public var targetPixelSize: CGSize?
  /// Explicit scale override. If `targetPixelSize` is set, that takes precedence. Defaults to 2 for Retina-friendly
  /// PNGs.
  public var scale: CGFloat?
  public var isOpaque: Bool
  public var colorMode: ColorRenderingMode

  /// Creates rendering options.
  /// - Parameters:
  ///   - targetPixelSize: Desired output in pixels; if set, the renderer derives the scale from the tessera tile size.
  ///   - scale: Rasterization scale applied to the renderer; defaults to 2 for Retina-quality PNGs when
  /// `targetPixelSize` is nil.
  ///   - isOpaque: Whether the exported image should omit an alpha channel when possible.
  ///   - colorMode: Working color mode used during rendering.
  public init(
    targetPixelSize: CGSize? = nil,
    scale: CGFloat? = nil,
    isOpaque: Bool = false,
    colorMode: ColorRenderingMode = .extendedLinear,
  ) {
    self.targetPixelSize = targetPixelSize
    self.scale = scale
    self.isOpaque = isOpaque
    self.colorMode = colorMode
  }

  func resolvedScale(tileSize: CGSize) -> CGFloat {
    if let targetPixelSize {
      let widthScale = targetPixelSize.width / tileSize.width
      let heightScale = targetPixelSize.height / tileSize.height
      return max(widthScale, heightScale)
    }
    return scale ?? 2
  }
}

/// Errors that can occur while exporting tessera tiles.
public enum TesseraRenderError: Error {
  case failedToCreateImage
  case failedToCreateDestination
  case failedToFinalizeDestination
}
