// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// Describes a single tessellated pattern configuration.
public struct TesseraTile: View {
  public var configuration: TesseraConfiguration
  public var tileSize: CGSize
  public var seed: UInt64
  public var onComputationStateChange: ((Bool) -> Void)?

  /// Creates a tessera tile view.
  /// - Parameters:
  ///   - configuration: The tessera configuration to render.
  ///   - tileSize: Size of the tile.
  ///   - seed: Optional seed overriding the configuration's seed for this view instance.
  public init(
    _ configuration: TesseraConfiguration,
    tileSize: CGSize,
    seed: UInt64? = nil,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.tileSize = tileSize
    self.seed = seed ?? configuration.seed
    self.onComputationStateChange = onComputationStateChange
  }

  /// Renders the configuration as a single tile view.
  public var body: some View {
    TesseraCanvasTile(
      configuration: configuration,
      tileSize: tileSize,
      seed: seed,
      onComputationStateChange: onComputationStateChange,
    )
  }

  /// Renders the tessera tile to a PNG file.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.png` is appended automatically.
  ///   - backgroundColor: Optional background fill rendered behind the tile. Defaults to no background (transparent).
  ///   - colorScheme: Optional SwiftUI color scheme override applied while rendering. Useful when symbols use semantic
  /// colors such as `Color.primary`.
  ///   - options: Rendering configuration such as output pixel size and scale.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPNG(
    to directory: URL,
    fileName: String = "tessera-tile",
    backgroundColor: Color? = nil,
    colorScheme: ColorScheme? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(),
  ) throws -> URL {
    let exportCanvas = TesseraCanvas(
      configuration,
      pinnedSymbols: [],
      seed: seed,
      edgeBehavior: .seamlessWrapping,
    )

    return try exportCanvas.renderPNG(
      to: directory,
      fileName: fileName,
      canvasSize: tileSize,
      backgroundColor: backgroundColor,
      colorScheme: colorScheme,
      options: options,
    )
  }

  /// Renders the tessera tile to a PDF file, preserving vector content when possible.
  /// - Parameters:
  ///   - directory: Target directory where the file will be created.
  ///   - fileName: Base file name without extension; `.pdf` is appended automatically.
  ///   - backgroundColor: Optional background fill rendered behind the tile. Defaults to no background (transparent).
  ///   - colorScheme: Optional SwiftUI color scheme override applied while rendering. Useful when symbols use semantic
  /// colors such as `Color.primary`.
  ///   - pageSize: Optional PDF page size in points; defaults to the tile size.
  ///   - options: Rendering configuration such as output pixel size and scale, applied while drawing into the PDF
  /// context.
  /// - Returns: The resolved file URL that was written.
  @discardableResult public func renderPDF(
    to directory: URL,
    fileName: String = "tessera-tile",
    backgroundColor: Color? = nil,
    colorScheme: ColorScheme? = nil,
    pageSize: CGSize? = nil,
    options: TesseraRenderOptions = TesseraRenderOptions(scale: 1),
  ) throws -> URL {
    let exportCanvas = TesseraCanvas(
      configuration,
      pinnedSymbols: [],
      seed: seed,
      edgeBehavior: .seamlessWrapping,
    )

    return try exportCanvas.renderPDF(
      to: directory,
      fileName: fileName,
      canvasSize: tileSize,
      backgroundColor: backgroundColor,
      colorScheme: colorScheme,
      pageSize: pageSize ?? tileSize,
      options: options,
    )
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
  /// Whether to draw collision overlays while exporting.
  ///
  /// When set, this overrides `TesseraConfiguration.showsCollisionOverlay` for the export pipeline.
  public var showsCollisionOverlay: Bool
  public var isOpaque: Bool
  public var colorMode: ColorRenderingMode

  /// Creates rendering options.
  /// - Parameters:
  ///   - targetPixelSize: Desired output in pixels; if set, the renderer derives the scale from the tessera tile size.
  ///   - scale: Rasterization scale applied to the renderer; defaults to 2 for Retina-quality PNGs when
  /// `targetPixelSize` is nil.
  ///   - showsCollisionOverlay: Whether to draw collision overlays while exporting. This overrides
  ///     `TesseraConfiguration.showsCollisionOverlay` for the export pipeline.
  ///   - isOpaque: Whether the exported image should omit an alpha channel when possible.
  ///   - colorMode: Working color mode used during rendering.
  public init(
    targetPixelSize: CGSize? = nil,
    scale: CGFloat? = nil,
    showsCollisionOverlay: Bool = false,
    isOpaque: Bool = false,
    colorMode: ColorRenderingMode = .extendedLinear,
  ) {
    self.targetPixelSize = targetPixelSize
    self.scale = scale
    self.showsCollisionOverlay = showsCollisionOverlay
    self.isOpaque = isOpaque
    self.colorMode = colorMode
  }

  func resolvedScale(contentSize: CGSize) -> CGFloat {
    if let targetPixelSize {
      let widthScale = targetPixelSize.width / contentSize.width
      let heightScale = targetPixelSize.height / contentSize.height
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
