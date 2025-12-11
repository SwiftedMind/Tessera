// By Dennis Müller

import SwiftUI
import Tessera

struct EditableItem: Identifiable, Equatable {
  var id: UUID
  var preset: Preset
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
    preset: Preset,
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
    self.preset = preset
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

  var scaleRange: ClosedRange<Double>? {
    guard usesCustomScaleRange else { return nil }

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

  enum Kind {
    case roundedRectangleCornerRadius
    case systemSymbol
    case textContent
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
}

extension EditableItem {
  static var demoItems: [EditableItem] {
    [
      EditableItem(preset: .squareOutline),
      EditableItem(preset: .roundedOutline, weight: 0.9),
      EditableItem(preset: .symbol, weight: 1.2, minimumRotation: -40, maximumRotation: 40),
      EditableItem(preset: .minus, weight: 0.8, minimumRotation: -20, maximumRotation: 20),
      EditableItem(preset: .equals, weight: 0.8, minimumRotation: -15, maximumRotation: 15),
      EditableItem(preset: .circleOutline, weight: 0.7),
    ]
  }
}
