// By Dennis Müller

import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A Tessera project document persisted as a `.tessera` file package.
///
/// The document stores only serializable editor state. Rendering state is derived elsewhere.
nonisolated struct TesseraDocument: FileDocument, Equatable {
  static var readableContentTypes: [UTType] { [.tesseraDocument] }
  static var writableContentTypes: [UTType] { readableContentTypes }

  var payload: TesseraDocumentPayload
  var embeddedImageAssets: [UUID: EmbeddedImageAsset]

  init() {
    payload = .default
    embeddedImageAssets = [:]
  }

  init(payload: TesseraDocumentPayload, embeddedImageAssets: [UUID: EmbeddedImageAsset] = [:]) {
    self.payload = payload
    self.embeddedImageAssets = embeddedImageAssets
  }

  init(configuration: ReadConfiguration) throws {
    let fileWrapper = configuration.file
    embeddedImageAssets = [:]

    if fileWrapper.isDirectory {
      guard let documentWrapper = fileWrapper.fileWrappers?["Document.json"],
            let documentData = documentWrapper.regularFileContents else {
        throw CocoaError(.fileReadCorruptFile)
      }

      payload = try JSONDecoder().decode(TesseraDocumentPayload.self, from: documentData)

      if let assetsWrapper = fileWrapper.fileWrappers?["Assets"], assetsWrapper.isDirectory {
        embeddedImageAssets = Self.loadEmbeddedImageAssets(from: assetsWrapper)
      }
      return
    }

    guard let data = fileWrapper.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }

    payload = try JSONDecoder().decode(TesseraDocumentPayload.self, from: data)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    try makeFileWrapper()
  }

  /// Creates a file wrapper for the current payload and embedded assets.
  ///
  /// This helper is used both by SwiftUI document saving and by tests.
  func makeFileWrapper() throws -> FileWrapper {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(payload)

    let documentWrapper = FileWrapper(regularFileWithContents: data)
    var packageFileWrappers: [String: FileWrapper] = [
      "Document.json": documentWrapper,
    ]

    if embeddedImageAssets.isEmpty == false {
      var assetFileWrappers: [String: FileWrapper] = [:]
      for (assetID, asset) in embeddedImageAssets {
        let fileName = "\(assetID.uuidString).\(asset.fileExtension)"
        assetFileWrappers[fileName] = FileWrapper(regularFileWithContents: asset.data)
      }
      packageFileWrappers["Assets"] = FileWrapper(directoryWithFileWrappers: assetFileWrappers)
    }

    return FileWrapper(directoryWithFileWrappers: packageFileWrappers)
  }

  private static func loadEmbeddedImageAssets(from assetsWrapper: FileWrapper) -> [UUID: EmbeddedImageAsset] {
    guard let fileWrappers = assetsWrapper.fileWrappers else { return [:] }

    var assets: [UUID: EmbeddedImageAsset] = [:]
    for (fileName, wrapper) in fileWrappers {
      guard let data = wrapper.regularFileContents else { continue }

      let components = fileName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
      guard let idComponent = components.first else { continue }
      guard let assetID = UUID(uuidString: String(idComponent)) else { continue }

      let fileExtension = components.count > 1 ? String(components[1]) : "png"
      assets[assetID] = EmbeddedImageAsset(data: data, fileExtension: fileExtension)
    }

    return assets
  }
}

extension UTType {
  nonisolated static var tesseraDocument: UTType {
    UTType(exportedAs: "com.swiftedmind.tessera.document", conformingTo: .package)
  }
}

// MARK: - Persisted Payload

/// Root JSON payload for a Tessera project document.
nonisolated struct TesseraDocumentPayload: Codable, Equatable {
  var schemaVersion: Int
  var settings: TesseraSettingsPayload
  var items: [EditableItemPayload]

  static var `default`: TesseraDocumentPayload {
    TesseraDocumentPayload(
      schemaVersion: 4,
      settings: .default,
      items: [],
    )
  }
}

/// Serializable editor-wide settings.
nonisolated struct TesseraSettingsPayload: Codable, Equatable {
  var patternMode: PatternMode
  var tesseraSize: CGSizePayload
  var canvasSize: CGSizePayload
  var tesseraSeed: UInt64
  var minimumSpacing: Double
  var density: Double
  var baseScaleRange: ClosedRangePayload<Double>
  var patternOffset: CGSizePayload
  var maximumItemCount: Int
  var stageBackgroundColor: ColorPayload?
  var fixedItems: [EditableFixedItemPayload]

  static var `default`: TesseraSettingsPayload {
    TesseraSettingsPayload(
      patternMode: .tile,
      tesseraSize: CGSizePayload(width: 256, height: 256),
      canvasSize: CGSizePayload(width: 1024, height: 1024),
      tesseraSeed: 0,
      minimumSpacing: 10,
      density: 0.8,
      baseScaleRange: ClosedRangePayload(lowerBound: 0.5, upperBound: 1.2),
      patternOffset: .zero,
      maximumItemCount: 512,
      stageBackgroundColor: nil,
      fixedItems: [],
    )
  }
}

/// Serializable representation of an editable item.
nonisolated struct EditableItemPayload: Codable, Equatable, Identifiable {
  var id: UUID
  var customName: String?
  var presetID: String
  var isVisible: Bool
  var weight: Double
  var minimumRotation: Double
  var maximumRotation: Double
  var usesCustomScaleRange: Bool
  var minimumScale: Double
  var maximumScale: Double
  var style: ItemStylePayload
  var specificOptions: PresetSpecificOptionsPayload
}

/// Serializable representation of a fixed item.
nonisolated struct EditableFixedItemPayload: Codable, Equatable, Identifiable {
  var id: UUID
  var customName: String?
  var presetID: String
  var isVisible: Bool
  var placementAnchor: FixedItemPlacementAnchor
  var placementOffset: CGSizePayload
  var rotationDegrees: Double
  var scale: Double
  var style: ItemStylePayload
  var specificOptions: PresetSpecificOptionsPayload
}

nonisolated struct ItemStylePayload: Codable, Equatable {
  var size: CGSizePayload
  var color: ColorPayload
  var lineWidth: Double
  var fontSize: Double
}

nonisolated enum PresetSpecificOptionsPayload: Codable, Equatable {
  case none
  case roundedRectangle(cornerRadius: Double)
  case systemSymbol(name: String)
  case text(content: String)
  case imagePlayground(
    embeddedAssetIDString: String?,
    embeddedAssetFileExtension: String?,
  )

  private enum CodingKeys: String, CodingKey {
    case kind
    case cornerRadius
    case name
    case content
    case embeddedAssetIDString
    case embeddedAssetFileExtension
  }

  private enum Kind: String, Codable {
    case none
    case roundedRectangle
    case systemSymbol
    case text
    case imagePlayground
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .kind)

    switch kind {
    case .none:
      self = .none
    case .roundedRectangle:
      let cornerRadius = try container.decode(Double.self, forKey: .cornerRadius)
      self = .roundedRectangle(cornerRadius: cornerRadius)
    case .systemSymbol:
      let name = try container.decode(String.self, forKey: .name)
      self = .systemSymbol(name: name)
    case .text:
      let content = try container.decode(String.self, forKey: .content)
      self = .text(content: content)
    case .imagePlayground:
      let embeddedAssetIDString = try container.decodeIfPresent(String.self, forKey: .embeddedAssetIDString)
      let embeddedAssetFileExtension = try container.decodeIfPresent(String.self, forKey: .embeddedAssetFileExtension)
      self = .imagePlayground(
        embeddedAssetIDString: embeddedAssetIDString,
        embeddedAssetFileExtension: embeddedAssetFileExtension,
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .none:
      try container.encode(Kind.none, forKey: .kind)
    case let .roundedRectangle(cornerRadius):
      try container.encode(Kind.roundedRectangle, forKey: .kind)
      try container.encode(cornerRadius, forKey: .cornerRadius)
    case let .systemSymbol(name):
      try container.encode(Kind.systemSymbol, forKey: .kind)
      try container.encode(name, forKey: .name)
    case let .text(content):
      try container.encode(Kind.text, forKey: .kind)
      try container.encode(content, forKey: .content)
    case let .imagePlayground(embeddedAssetIDString, embeddedAssetFileExtension):
      try container.encode(Kind.imagePlayground, forKey: .kind)
      try container.encodeIfPresent(embeddedAssetIDString, forKey: .embeddedAssetIDString)
      try container.encodeIfPresent(embeddedAssetFileExtension, forKey: .embeddedAssetFileExtension)
    }
  }
}

// MARK: - Embedded Assets

/// Runtime-only embedded image asset stored in the `.tessera` package.
nonisolated struct EmbeddedImageAsset: Equatable {
  var data: Data
  var fileExtension: String
}

nonisolated struct CGSizePayload: Codable, Equatable {
  var width: Double
  var height: Double

  static var zero: CGSizePayload { CGSizePayload(width: 0, height: 0) }
}

nonisolated struct ClosedRangePayload<Bound: Codable & Equatable>: Codable, Equatable {
  var lowerBound: Bound
  var upperBound: Bound
}

/// Serializable sRGB color payload.
nonisolated struct ColorPayload: Codable, Equatable {
  var red: Double
  var green: Double
  var blue: Double
  var alpha: Double
}

// MARK: - Color Conversion

extension ColorPayload {
  @MainActor init(_ color: Color) {
    #if os(macOS)
    let nsColor = NSColor(color)
    let resolved = nsColor.usingColorSpace(.sRGB) ?? nsColor
    red = Double(resolved.redComponent)
    green = Double(resolved.greenComponent)
    blue = Double(resolved.blueComponent)
    alpha = Double(resolved.alphaComponent)
    #else
    let uiColor = UIColor(color)
    var redValue: CGFloat = 0
    var greenValue: CGFloat = 0
    var blueValue: CGFloat = 0
    var alphaValue: CGFloat = 0
    uiColor.getRed(&redValue, green: &greenValue, blue: &blueValue, alpha: &alphaValue)
    red = Double(redValue)
    green = Double(greenValue)
    blue = Double(blueValue)
    alpha = Double(alphaValue)
    #endif
  }

  var color: Color {
    Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }
}

// MARK: - Geometry Conversion

extension CGSizePayload {
  init(_ size: CGSize) {
    width = Double(size.width)
    height = Double(size.height)
  }

  var coreGraphicsSize: CGSize {
    CGSize(width: width, height: height)
  }
}

extension ClosedRangePayload where Bound == Double {
  init(_ range: ClosedRange<Double>) {
    lowerBound = range.lowerBound
    upperBound = range.upperBound
  }

  var range: ClosedRange<Double> {
    lowerBound...upperBound
  }
}
