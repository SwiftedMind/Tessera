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

  /// Creates rendering options for PNG/PDF export.
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
  /// A provided snapshot does not match the current renderer fingerprint.
  case snapshotFingerprintMismatch
  /// Mosaic configuration is invalid and cannot be rendered.
  case invalidMosaicConfiguration
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
  /// let url = try await Tessera(pattern)
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
  ) async throws -> URL {
    let resolvedMode: Mode
    switch mode {
    case let .canvas(size, edgeBehavior):
      guard let resolvedCanvasSize = size ?? canvasSize else {
        throw RenderError.missingCanvasSize
      }

      resolvedMode = .canvas(size: resolvedCanvasSize, edgeBehavior: edgeBehavior)
    case let .tile(size):
      resolvedMode = .tile(size: size)
    case let .tiled(tileSize):
      resolvedMode = .tiled(tileSize: tileSize)
    }

    let exportSeedMode: Seed = switch seed {
    case .automatic:
      if pattern.placementSeed != nil {
        .automatic
      } else {
        .fixed(Pattern.randomSeed())
      }
    case let .fixed(value):
      .fixed(value)
    }

    let pattern = pattern
    let region = region
    let regionRendering = regionRendering
    let pinnedSymbols = pinnedSymbols
    let renderer = TesseraRenderer(pattern)
    let snapshot = try await renderer.makeSnapshot(
      mode: resolvedMode,
      seed: exportSeedMode,
      region: region,
      regionRendering: regionRendering,
      pinnedSymbols: pinnedSymbols,
    )
    return try renderer.export(
      format,
      snapshot: snapshot,
      options: options,
    )
  }
}
