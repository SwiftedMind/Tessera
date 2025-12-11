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

  var payload: TesseraDocumentPayload

  init() {
    payload = .default
  }

  init(payload: TesseraDocumentPayload) {
    self.payload = payload
  }

  init(configuration: ReadConfiguration) throws {
    let fileWrapper = configuration.file

    if fileWrapper.isDirectory {
      guard let documentWrapper = fileWrapper.fileWrappers?["Document.json"],
            let documentData = documentWrapper.regularFileContents else {
        throw CocoaError(.fileReadCorruptFile)
      }

      payload = try JSONDecoder().decode(TesseraDocumentPayload.self, from: documentData)
      return
    }

    guard let data = fileWrapper.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }

    payload = try JSONDecoder().decode(TesseraDocumentPayload.self, from: data)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(payload)

    let documentWrapper = FileWrapper(regularFileWithContents: data)
    let packageWrapper = FileWrapper(directoryWithFileWrappers: [
      "Document.json": documentWrapper,
    ])
    return packageWrapper
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
      schemaVersion: 1,
      settings: .default,
      items: [],
    )
  }
}

/// Serializable editor-wide settings.
nonisolated struct TesseraSettingsPayload: Codable, Equatable {
  var tesseraSize: CGSizePayload
  var tesseraSeed: UInt64
  var minimumSpacing: Double
  var density: Double
  var baseScaleRange: ClosedRangePayload<Double>
  var patternOffset: CGSizePayload
  var stageBackgroundColor: ColorPayload?

  static var `default`: TesseraSettingsPayload {
    TesseraSettingsPayload(
      tesseraSize: CGSizePayload(width: 256, height: 256),
      tesseraSeed: 0,
      minimumSpacing: 10,
      density: 0.8,
      baseScaleRange: ClosedRangePayload(lowerBound: 0.5, upperBound: 1.2),
      patternOffset: .zero,
      stageBackgroundColor: nil,
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
  case imagePlayground(urlString: String?)

  private enum CodingKeys: String, CodingKey {
    case kind
    case cornerRadius
    case name
    case content
    case urlString
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
      let urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
      self = .imagePlayground(urlString: urlString)
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
    case let .imagePlayground(urlString):
      try container.encode(Kind.imagePlayground, forKey: .kind)
      try container.encodeIfPresent(urlString, forKey: .urlString)
    }
  }
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
