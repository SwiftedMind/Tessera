// By Dennis Müller

import Foundation
import SwiftUI
import Tessera

struct EditableFixedItem: Identifiable, Equatable {
  var id: UUID
  var customName: String?
  var preset: EditableItem.Preset
  var isVisible: Bool
  var placementAnchor: FixedItemPlacementAnchor
  var placementOffset: CGSize
  var rotationDegrees: Double
  var scale: CGFloat
  var style: ItemStyle
  var specificOptions: PresetSpecificOptions

  init(
    id: UUID = UUID(),
    customName: String? = nil,
    preset: EditableItem.Preset,
    isVisible: Bool = true,
    placementAnchor: FixedItemPlacementAnchor = .center,
    placementOffset: CGSize = .zero,
    rotationDegrees: Double = 0,
    scale: CGFloat = 1,
    style: ItemStyle? = nil,
    specificOptions: PresetSpecificOptions? = nil,
  ) {
    self.id = id
    self.customName = customName
    self.preset = preset
    self.isVisible = isVisible
    self.placementAnchor = placementAnchor
    self.placementOffset = placementOffset
    self.rotationDegrees = rotationDegrees
    self.scale = scale
    self.style = style ?? preset.defaultStyle
    self.specificOptions = specificOptions ?? preset.defaultSpecificOptions
  }

  var title: LocalizedStringKey {
    let trimmedCustomName = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmedCustomName.isEmpty {
      return preset.title
    }
    return LocalizedStringKey(stringLiteral: trimmedCustomName)
  }

  func makeTesseraFixedItem() -> TesseraFixedItem {
    let resolvedScale: CGFloat = preset.capabilities.supportsFontSize ? 1 : scale

    return TesseraFixedItem(
      id: id,
      position: .relative(placementAnchor.unitPoint, offset: placementOffset),
      rotation: .degrees(rotationDegrees),
      scale: resolvedScale,
      collisionShape: preset.collisionShape(style, specificOptions),
    ) {
      preset.render(style, specificOptions)
    }
  }
}

enum FixedItemPlacementAnchor: String, Codable, CaseIterable, Identifiable, Sendable {
  case topLeading
  case top
  case topTrailing
  case leading
  case center
  case trailing
  case bottomLeading
  case bottom
  case bottomTrailing

  var id: String { rawValue }

  var unitPoint: UnitPoint {
    switch self {
    case .topLeading: .topLeading
    case .top: .top
    case .topTrailing: .topTrailing
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    case .bottomLeading: .bottomLeading
    case .bottom: .bottom
    case .bottomTrailing: .bottomTrailing
    }
  }

  var title: LocalizedStringKey {
    switch self {
    case .topLeading: "Top Leading"
    case .top: "Top"
    case .topTrailing: "Top Trailing"
    case .leading: "Leading"
    case .center: "Center"
    case .trailing: "Trailing"
    case .bottomLeading: "Bottom Leading"
    case .bottom: "Bottom"
    case .bottomTrailing: "Bottom Trailing"
    }
  }
}

// MARK: - Document Conversion

extension EditableFixedItem {
  init(payload: EditableFixedItemPayload) {
    self.init(payload: payload, embeddedAssets: [:])
  }

  init(payload: EditableFixedItemPayload, embeddedAssets: [UUID: EmbeddedImageAsset]) {
    let preset = EditableItem.Preset.preset(withID: payload.presetID) ?? .squareOutline
    let style = ItemStyle(payload: payload.style)
    let specificOptions = PresetSpecificOptions(payload: payload.specificOptions, embeddedAssets: embeddedAssets)

    self.init(
      id: payload.id,
      customName: payload.customName,
      preset: preset,
      isVisible: payload.isVisible,
      placementAnchor: payload.placementAnchor,
      placementOffset: payload.placementOffset.coreGraphicsSize,
      rotationDegrees: payload.rotationDegrees,
      scale: CGFloat(payload.scale),
      style: style,
      specificOptions: specificOptions,
    )
  }

  var payload: EditableFixedItemPayload {
    EditableFixedItemPayload(
      id: id,
      customName: customName,
      presetID: preset.id,
      isVisible: isVisible,
      placementAnchor: placementAnchor,
      placementOffset: CGSizePayload(placementOffset),
      rotationDegrees: rotationDegrees,
      scale: Double(scale),
      style: style.payload,
      specificOptions: specificOptions.payload,
    )
  }
}
