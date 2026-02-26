// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// Rendering configuration used by PNG/PDF export.
public struct RenderOptions {
  /// Desired pixel dimensions for the exported image. When set, scale is derived from this size.
  public var targetPixelSize: CGSize?
  /// Explicit scale override. Ignored when `targetPixelSize` is set.
  public var scale: CGFloat?
  /// Whether collision overlays should be included in exports.
  public var showsCollisionOverlay: Bool
  /// Whether output should be rendered as opaque where possible.
  public var isOpaque: Bool
  /// Working color mode used for rendering.
  public var colorMode: ColorRenderingMode

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

/// Errors that can occur while exporting rendered content.
public enum RenderError: Error, Equatable {
  /// The renderer failed to create a raster image.
  case failedToCreateImage
  /// The output destination (file writer) could not be created.
  case failedToCreateDestination
  /// The output destination failed to finalize/write.
  case failedToFinalizeDestination
  /// Export requires an explicit canvas size but none was provided.
  case missingCanvasSize
  /// A placement snapshot does not match the current canvas configuration.
  case invalidPlacementSnapshot
}

/// Export file format.
public enum ExportFormat: Hashable, Sendable {
  /// PNG raster image output.
  case png
  /// PDF output.
  case pdf
}

/// Options shared by PNG and PDF exports.
public struct ExportOptions {
  /// Output directory.
  public var directory: URL
  /// Output base file name (extension is added automatically).
  public var fileName: String
  /// Optional background fill.
  public var backgroundColor: Color?
  /// Optional color scheme override for rendering semantic colors.
  public var colorScheme: ColorScheme?
  /// Optional PDF page size; ignored for PNG.
  public var pageSize: CGSize?
  /// Rendering options such as scale and color mode.
  public var render: RenderOptions

  /// Creates export options.
  public init(
    directory: URL,
    fileName: String,
    backgroundColor: Color? = nil,
    colorScheme: ColorScheme? = nil,
    pageSize: CGSize? = nil,
    render: RenderOptions = .init(),
  ) {
    self.directory = directory
    self.fileName = fileName
    self.backgroundColor = backgroundColor
    self.colorScheme = colorScheme
    self.pageSize = pageSize
    self.render = render
  }
}

public extension Tessera {
  /// Exports Tessera output in the requested format.
  ///
  /// For `.canvas` mode, `canvasSize` is required.
  /// For `.tile` and `.tiled`, the mode's tile size is used automatically.
  ///
  /// Example:
  /// ```swift
  /// let url = try Tessera(pattern)
  ///   .mode(.tile(size: .init(width: 256, height: 256)))
  ///   .export(
  ///     .png,
  ///     options: .init(directory: outputDir, fileName: "pattern")
  ///   )
  /// ```
  @MainActor
  @discardableResult
  func export(
    _ format: ExportFormat,
    options: ExportOptions,
    canvasSize: CGSize? = nil,
  ) throws -> URL {
    let exportSeed = resolvedSeed(fallbackToAutomatic: false) ?? Pattern.randomSeed()

    switch mode {
    case let .canvas(edgeBehavior):
      guard let canvasSize else {
        throw RenderError.missingCanvasSize
      }

      let canvas = TesseraCanvas(
        pattern.legacyConfiguration,
        pinnedSymbols: pinnedSymbols,
        seed: exportSeed,
        edgeBehavior: edgeBehavior,
        region: region,
        regionRendering: regionRendering,
        rendersAsynchronously: rendersAsynchronously,
      )

      return try canvas.export(
        format,
        options: options,
        canvasSize: canvasSize,
      )

    case let .tile(size), let .tiled(size):
      let canvas = TesseraCanvas(
        pattern.legacyConfiguration,
        pinnedSymbols: pinnedSymbols,
        seed: exportSeed,
        edgeBehavior: .seamlessWrapping,
        region: region,
        regionRendering: regionRendering,
        rendersAsynchronously: rendersAsynchronously,
      )

      return try canvas.export(
        format,
        options: options,
        canvasSize: size,
      )
    }
  }
}

public extension TesseraCanvas {
  /// Internal v4 bridge used by `Tessera.export(...)`.
  @MainActor
  @discardableResult
  func export(
    _ format: ExportFormat,
    options: ExportOptions,
    canvasSize: CGSize,
  ) throws -> URL {
    switch format {
    case .png:
      try renderPNG(
        to: options.directory,
        fileName: options.fileName,
        canvasSize: canvasSize,
        backgroundColor: options.backgroundColor,
        colorScheme: options.colorScheme,
        options: options.render,
      )
    case .pdf:
      try renderPDF(
        to: options.directory,
        fileName: options.fileName,
        canvasSize: canvasSize,
        backgroundColor: options.backgroundColor,
        colorScheme: options.colorScheme,
        pageSize: options.pageSize ?? canvasSize,
        options: options.render,
      )
    }
  }
}
