// By Dennis Müller

import SwiftUI
import Tessera

struct EditableItem: Identifiable, Equatable {
  var id: UUID
  var customName: String?
  var preset: Preset
  var isVisible: Bool
  var weight: Double
  var minimumRotation: Double
  var maximumRotation: Double
  var usesCustomScaleRange: Bool
  var minimumScale: CGFloat
  var maximumScale: CGFloat
  var style: ItemStyle
  var specificOptions: PresetSpecificOptions

  init(
    id: UUID = UUID(),
    customName: String? = nil,
    preset: Preset,
    isVisible: Bool = true,
    weight: Double = 1,
    minimumRotation: Double = 0,
    maximumRotation: Double = 360,
    usesCustomScaleRange: Bool = false,
    minimumScale: CGFloat = 0.6,
    maximumScale: CGFloat = 1.2,
    style: ItemStyle? = nil,
    specificOptions: PresetSpecificOptions? = nil,
  ) {
    self.id = id
    self.customName = customName
    self.preset = preset
    self.isVisible = isVisible
    self.weight = weight
    self.minimumRotation = minimumRotation
    self.maximumRotation = maximumRotation
    self.usesCustomScaleRange = usesCustomScaleRange
    self.minimumScale = minimumScale
    self.maximumScale = maximumScale
    self.style = style ?? preset.defaultStyle
    self.specificOptions = specificOptions ?? preset.defaultSpecificOptions
  }

  var rotationRange: ClosedRange<Angle> {
    Angle.degrees(minimumRotation)...Angle.degrees(maximumRotation)
  }

  var title: LocalizedStringKey {
    let trimmedCustomName = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmedCustomName.isEmpty {
      return preset.title
    }
    return LocalizedStringKey(stringLiteral: trimmedCustomName)
  }

  var scaleRange: ClosedRange<Double>? {
    guard usesCustomScaleRange else { return nil }
    guard preset.capabilities.supportsFontSize == false else { return nil }

    return minimumScale...maximumScale
  }

  func makeTesseraItem() -> TesseraItem {
    preset.makeItem(
      id: id,
      weight: weight,
      rotationRange: rotationRange,
      scaleRange: scaleRange,
      style: style,
      options: specificOptions,
    )
  }
}

struct ItemStyle: Equatable {
  var size: CGSize
  var color: Color
  var lineWidth: CGFloat
  var fontSize: CGFloat
}

enum PresetSpecificOptions: Equatable {
  case none
  case roundedRectangle(cornerRadius: CGFloat)
  case systemSymbol(name: String)
  case text(content: String)
  case imagePlayground(assetID: UUID?, imageData: Data?, fileExtension: String?)
  case uploadedImage(assetID: UUID?, imageData: Data?, fileExtension: String?)

  var cornerRadius: CGFloat? {
    switch self {
    case let .roundedRectangle(cornerRadius):
      cornerRadius
    default:
      nil
    }
  }

  var systemSymbolName: String? {
    switch self {
    case let .systemSymbol(name):
      name
    default:
      nil
    }
  }

  var textContent: String? {
    switch self {
    case let .text(content):
      content
    default:
      nil
    }
  }

  var imagePlaygroundAssetID: UUID? {
    switch self {
    case let .imagePlayground(assetID, _, _):
      assetID
    default:
      nil
    }
  }

  var imagePlaygroundImageData: Data? {
    switch self {
    case let .imagePlayground(_, imageData, _):
      imageData
    default:
      nil
    }
  }

  var imagePlaygroundFileExtension: String? {
    switch self {
    case let .imagePlayground(_, _, fileExtension):
      fileExtension
    default:
      nil
    }
  }

  var uploadedImageAssetID: UUID? {
    switch self {
    case let .uploadedImage(assetID, _, _):
      assetID
    default:
      nil
    }
  }

  var uploadedImageData: Data? {
    switch self {
    case let .uploadedImage(_, imageData, _):
      imageData
    default:
      nil
    }
  }

  var uploadedImageFileExtension: String? {
    switch self {
    case let .uploadedImage(_, _, fileExtension):
      fileExtension
    default:
      nil
    }
  }

  enum Kind {
    case roundedRectangleCornerRadius
    case systemSymbol
    case textContent
    case imagePlayground
    case uploadedImage
  }

  var kind: Kind? {
    switch self {
    case .none:
      nil
    case .roundedRectangle:
      .roundedRectangleCornerRadius
    case .systemSymbol:
      .systemSymbol
    case .text:
      .textContent
    case .imagePlayground:
      .imagePlayground
    case .uploadedImage:
      .uploadedImage
    }
  }

  func updatingCornerRadius(_ radius: CGFloat) -> PresetSpecificOptions {
    .roundedRectangle(cornerRadius: radius)
  }

  func updatingSymbolName(_ name: String) -> PresetSpecificOptions {
    .systemSymbol(name: name)
  }

  func updatingTextContent(_ content: String) -> PresetSpecificOptions {
    .text(content: content)
  }

  func updatingImagePlayground(
    assetID: UUID?,
    imageData: Data?,
    fileExtension: String?,
  ) -> PresetSpecificOptions {
    .imagePlayground(assetID: assetID, imageData: imageData, fileExtension: fileExtension)
  }

  func updatingUploadedImage(
    assetID: UUID?,
    imageData: Data?,
    fileExtension: String?,
  ) -> PresetSpecificOptions {
    .uploadedImage(assetID: assetID, imageData: imageData, fileExtension: fileExtension)
  }
}

extension EditableItem {
  static var demoItems: [EditableItem] {
    [
      EditableItem(preset: .squareOutline),
      EditableItem(preset: .roundedOutline, weight: 0.9),
      EditableItem(preset: .symbol, weight: 1.2, minimumRotation: -40, maximumRotation: 40),
      EditableItem(preset: .circleOutline, weight: 0.7),
    ]
  }
}

// MARK: - Document Conversion

extension EditableItem {
  init(payload: EditableItemPayload) {
    self.init(payload: payload, embeddedAssets: [:])
  }

  init(payload: EditableItemPayload, embeddedAssets: [UUID: EmbeddedImageAsset]) {
    let preset = EditableItem.Preset.preset(withID: payload.presetID) ?? .squareOutline
    let style = ItemStyle(payload: payload.style)
    let specificOptions = PresetSpecificOptions(payload: payload.specificOptions, embeddedAssets: embeddedAssets)

    self.init(
      id: payload.id,
      customName: payload.customName,
      preset: preset,
      isVisible: payload.isVisible,
      weight: payload.weight,
      minimumRotation: payload.minimumRotation,
      maximumRotation: payload.maximumRotation,
      usesCustomScaleRange: payload.usesCustomScaleRange,
      minimumScale: payload.minimumScale,
      maximumScale: payload.maximumScale,
      style: style,
      specificOptions: specificOptions,
    )
  }

  var payload: EditableItemPayload {
    EditableItemPayload(
      id: id,
      customName: customName,
      presetID: preset.id,
      isVisible: isVisible,
      weight: weight,
      minimumRotation: minimumRotation,
      maximumRotation: maximumRotation,
      usesCustomScaleRange: usesCustomScaleRange,
      minimumScale: Double(minimumScale),
      maximumScale: Double(maximumScale),
      style: style.payload,
      specificOptions: specificOptions.payload,
    )
  }
}

extension ItemStyle {
  init(payload: ItemStylePayload) {
    size = payload.size.coreGraphicsSize
    color = payload.color.color
    lineWidth = payload.lineWidth
    fontSize = payload.fontSize
  }

  var payload: ItemStylePayload {
    ItemStylePayload(
      size: CGSizePayload(size),
      color: ColorPayload(color),
      lineWidth: Double(lineWidth),
      fontSize: Double(fontSize),
    )
  }
}

extension PresetSpecificOptions {
  init(payload: PresetSpecificOptionsPayload, embeddedAssets: [UUID: EmbeddedImageAsset]) {
    switch payload {
    case .none:
      self = .none
    case let .roundedRectangle(cornerRadius):
      self = .roundedRectangle(cornerRadius: CGFloat(cornerRadius))
    case let .systemSymbol(name):
      self = .systemSymbol(name: name)
    case let .text(content):
      self = .text(content: content)
    case let .imagePlayground(embeddedAssetIDString, embeddedAssetFileExtension):
      let embeddedAssetID = embeddedAssetIDString.flatMap(UUID.init(uuidString:))
      let embeddedAsset = embeddedAssetID.flatMap { embeddedAssets[$0] }
      self = .imagePlayground(
        assetID: embeddedAssetID,
        imageData: embeddedAsset?.data,
        fileExtension: embeddedAssetFileExtension ?? embeddedAsset?.fileExtension,
      )
    case let .uploadedImage(embeddedAssetIDString, embeddedAssetFileExtension):
      let embeddedAssetID = embeddedAssetIDString.flatMap(UUID.init(uuidString:))
      let embeddedAsset = embeddedAssetID.flatMap { embeddedAssets[$0] }
      self = .uploadedImage(
        assetID: embeddedAssetID,
        imageData: embeddedAsset?.data,
        fileExtension: embeddedAssetFileExtension ?? embeddedAsset?.fileExtension,
      )
    }
  }

  var payload: PresetSpecificOptionsPayload {
    switch self {
    case .none:
      .none
    case let .roundedRectangle(cornerRadius):
      .roundedRectangle(cornerRadius: Double(cornerRadius))
    case let .systemSymbol(name):
      .systemSymbol(name: name)
    case let .text(content):
      .text(content: content)
    case let .imagePlayground(assetID, _, fileExtension):
      .imagePlayground(
        embeddedAssetIDString: assetID?.uuidString,
        embeddedAssetFileExtension: fileExtension,
      )
    case let .uploadedImage(assetID, _, fileExtension):
      .uploadedImage(
        embeddedAssetIDString: assetID?.uuidString,
        embeddedAssetFileExtension: fileExtension,
      )
    }
  }
}
