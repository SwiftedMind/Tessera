// By Dennis Müller

import CoreText
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
      EditableItem(preset: .partyPopper, weight: 1.2, minimumRotation: -40, maximumRotation: 40),
      EditableItem(preset: .minus, weight: 0.8, minimumRotation: -20, maximumRotation: 20),
      EditableItem(preset: .equals, weight: 0.8, minimumRotation: -15, maximumRotation: 15),
      EditableItem(preset: .circleOutline, weight: 0.7),
    ]
  }
}

extension EditableItem {
  enum Preset: String, CaseIterable, Identifiable {
    case squareOutline
    case roundedOutline
    case partyPopper
    case minus
    case equals
    case circleOutline
    case text

    var id: String { rawValue }

    var title: String {
      switch self {
      case .squareOutline: "Square Outline"
      case .roundedOutline: "Rounded Outline"
      case .partyPopper: "Party Popper"
      case .minus: "Minus"
      case .equals: "Equals"
      case .circleOutline: "Circle Outline"
      case .text: "Text"
      }
    }

    var iconName: String {
      switch self {
      case .squareOutline: "square.dashed"
      case .roundedOutline: "app"
      case .partyPopper: "party.popper.fill"
      case .minus: "minus"
      case .equals: "equal"
      case .circleOutline: "circle"
      case .text: "text.alignleft"
      }
    }

    var defaultStyle: ItemStyle {
      switch self {
      case .squareOutline:
        ItemStyle(size: CGSize(width: 30, height: 30), color: .gray.opacity(0.8), lineWidth: 4, fontSize: 32)
      case .roundedOutline:
        ItemStyle(size: CGSize(width: 30, height: 30), color: .primary, lineWidth: 4, fontSize: 32)
      case .partyPopper:
        ItemStyle(size: CGSize(width: 40, height: 40), color: .red.opacity(0.5), lineWidth: 2, fontSize: 34)
      case .minus:
        ItemStyle(size: CGSize(width: 36, height: 4), color: .gray, lineWidth: 1, fontSize: 34)
      case .equals:
        ItemStyle(size: CGSize(width: 36, height: 12), color: .gray, lineWidth: 1, fontSize: 34)
      case .circleOutline:
        ItemStyle(size: CGSize(width: 26, height: 26), color: .gray.opacity(0.2), lineWidth: 4, fontSize: 32)
      case .text:
        ItemStyle(size: CGSize(width: 36, height: 24), color: .primary, lineWidth: 1, fontSize: 32)
      }
    }

    var defaultSpecificOptions: PresetSpecificOptions {
      switch self {
      case .roundedOutline:
        .roundedRectangle(cornerRadius: 6)
      case .partyPopper:
        .systemSymbol(name: defaultSymbolName)
      case .text:
        .text(content: "Text")
      case .squareOutline, .minus, .equals, .circleOutline:
        .none
      }
    }

    var capabilities: PresetCapabilities {
      switch self {
      case .squareOutline:
        PresetCapabilities(
          usesStrokeStyle: true,
          usesFillStyle: false,
          supportsLineWidth: true,
          supportsFontSize: false,
          supportsCornerRadius: false,
          supportsSymbolSelection: false,
          supportsTextContent: false,
        )
      case .roundedOutline:
        PresetCapabilities(
          usesStrokeStyle: true,
          usesFillStyle: false,
          supportsLineWidth: true,
          supportsFontSize: false,
          supportsCornerRadius: true,
          supportsSymbolSelection: false,
          supportsTextContent: false,
        )
      case .circleOutline:
        PresetCapabilities(
          usesStrokeStyle: true,
          usesFillStyle: false,
          supportsLineWidth: true,
          supportsFontSize: false,
          supportsCornerRadius: false,
          supportsSymbolSelection: false,
          supportsTextContent: false,
        )
      case .partyPopper:
        PresetCapabilities(
          usesStrokeStyle: false,
          usesFillStyle: true,
          supportsLineWidth: false,
          supportsFontSize: true,
          supportsCornerRadius: false,
          supportsSymbolSelection: true,
          supportsTextContent: false,
        )
      case .minus, .equals:
        PresetCapabilities(
          usesStrokeStyle: false,
          usesFillStyle: true,
          supportsLineWidth: false,
          supportsFontSize: true,
          supportsCornerRadius: false,
          supportsSymbolSelection: false,
          supportsTextContent: false,
        )
      case .text:
        PresetCapabilities(
          usesStrokeStyle: false,
          usesFillStyle: false,
          supportsLineWidth: false,
          supportsFontSize: true,
          supportsCornerRadius: false,
          supportsSymbolSelection: false,
          supportsTextContent: true,
        )
      }
    }

    var availableSymbols: [String] {
      switch self {
      case .partyPopper:
        [
          "party.popper.fill",
          "wand.and.stars",
          "sparkles",
          "sun.max.fill",
          "moon.stars.fill",
          "heart.fill",
          "burst.fill",
        ]
      default:
        []
      }
    }

    var colorLabel: LocalizedStringKey {
      switch capabilities.usesStrokeStyle {
      case true:
        "Stroke Color"
      case false:
        "Fill Color"
      }
    }

    var defaultSymbolName: String {
      switch self {
      case .partyPopper:
        "party.popper.fill"
      default:
        "questionmark"
      }
    }

    @ViewBuilder var preview: some View {
      render(style: defaultStyle, options: defaultSpecificOptions)
    }

    func makeItem(
      id: UUID,
      weight: Double,
      rotationRange: ClosedRange<Angle>,
      scaleRange: ClosedRange<Double>?,
      style: ItemStyle,
      options: PresetSpecificOptions,
    ) -> TesseraItem {
      TesseraItem(
        id: id,
        weight: weight,
        allowedRotationRange: rotationRange,
        scaleRange: scaleRange,
        collisionShape: collisionShape(for: style, options: options),
      ) {
        render(style: style, options: options)
      }
    }

    @ViewBuilder
    private func render(style: ItemStyle, options: PresetSpecificOptions) -> some View {
      switch self {
      case .squareOutline:
        Rectangle()
          .stroke(lineWidth: style.lineWidth)
          .foregroundStyle(style.color)
          .frame(width: style.size.width, height: style.size.height)
      case .roundedOutline:
        RoundedRectangle(cornerRadius: cornerRadius(from: options, fallback: 6))
          .stroke(lineWidth: style.lineWidth)
          .foregroundStyle(style.color)
          .frame(width: style.size.width, height: style.size.height)
      case .circleOutline:
        Circle()
          .stroke(lineWidth: style.lineWidth)
          .foregroundStyle(style.color)
          .frame(width: style.size.width, height: style.size.height)
      case .partyPopper:
        Image(systemName: symbolName(from: options))
          .resizable()
          .aspectRatio(contentMode: .fit)
          .foregroundStyle(style.color)
          .font(.system(size: style.fontSize, weight: .regular))
          .frame(width: style.size.width, height: style.size.height)
      case .minus:
        Text("-")
          .foregroundStyle(style.color)
          .font(.system(size: style.fontSize, weight: .bold))
          .frame(width: style.size.width, height: style.size.height)
      case .equals:
        Text("=")
          .foregroundStyle(style.color)
          .font(.system(size: style.fontSize, weight: .bold))
          .frame(width: style.size.width, height: style.size.height)
      case .text:
        Text(textContent(from: options))
          .foregroundStyle(style.color)
          .font(.system(size: style.fontSize, weight: .semibold))
          .frame(width: style.size.width, height: style.size.height)
      }
    }

    private func collisionShape(for style: ItemStyle, options: PresetSpecificOptions) -> CollisionShape {
      switch self {
      case .squareOutline, .roundedOutline:
        .rectangle(size: rectangleCollisionSize(for: style))
      case .circleOutline:
        .circle(radius: circleRadius(for: style))
      case .minus:
        .rectangle(size: style.size)
      case .equals:
        .rectangle(size: style.size)
      case .partyPopper:
        .circle(radius: max(style.size.width, style.size.height) / 2)
      case .text:
        .rectangle(size: style.size)
      }
    }

    private func rectangleCollisionSize(for style: ItemStyle) -> CGSize {
      CGSize(
        width: style.size.width + style.lineWidth,
        height: style.size.height + style.lineWidth,
      )
    }

    private func circleRadius(for style: ItemStyle) -> CGFloat {
      max(style.size.width, style.size.height) / 2 + style.lineWidth / 2
    }

    private func cornerRadius(from options: PresetSpecificOptions, fallback: CGFloat) -> CGFloat {
      options.cornerRadius ?? fallback
    }

    private func symbolName(from options: PresetSpecificOptions) -> String {
      options.systemSymbolName ?? defaultSymbolName
    }

    private func textContent(from options: PresetSpecificOptions) -> String {
      options.textContent ?? "Text"
    }

    func measuredSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
      switch self {
      case .text:
        measuredTextSize(for: style, options: options)
      default:
        style.size
      }
    }

    private func measuredTextSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
      let content = textContent(from: options)
      let uiFont = NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)

      let attributes: [NSAttributedString.Key: Any] = [.font: uiFont]

      let attributed = NSAttributedString(string: content, attributes: attributes)
      let line = CTLineCreateWithAttributedString(attributed)

      let width = ceil(CTLineGetTypographicBounds(line, nil, nil, nil))

      let ctFont = CTFontCreateWithName(uiFont.fontName as CFString, uiFont.pointSize, nil)
      let ascent = CTFontGetAscent(ctFont)
      let descent = CTFontGetDescent(ctFont)
      let leading = CTFontGetLeading(ctFont)

      let height = ceil(ascent + descent + leading)
      let padding: CGFloat = 2

      return CGSize(width: width + padding, height: height + padding)
    }
  }
}

extension EditableItem.Preset {
  struct PresetCapabilities {
    var usesStrokeStyle: Bool
    var usesFillStyle: Bool
    var supportsLineWidth: Bool
    var supportsFontSize: Bool
    var supportsCornerRadius: Bool
    var supportsSymbolSelection: Bool
    var supportsTextContent: Bool
  }
}
