// By Dennis Müller

import CoreText
import SwiftUI
import Tessera

extension EditableItem {
  /// Built-in editable item preset that carries display metadata and rendering logic.
  struct Preset: Identifiable, Equatable {
    var id: String
    var title: LocalizedStringKey
    var iconName: String
    var defaultStyle: ItemStyle
    var defaultSpecificOptions: PresetSpecificOptions
    var capabilities: PresetCapabilities
    var availableSymbols: [String]
    var defaultSymbolName: String
    var render: (ItemStyle, PresetSpecificOptions) -> AnyView
    var collisionShape: (ItemStyle, PresetSpecificOptions) -> CollisionShape
    var measuredSize: (ItemStyle, PresetSpecificOptions) -> CGSize

    static func == (lhs: Preset, rhs: Preset) -> Bool {
      lhs.id == rhs.id
    }

    /// Label used for the primary color control depending on stroke or fill usage.
    var colorLabel: LocalizedStringKey {
      switch capabilities.usesStrokeStyle {
      case true:
        "Stroke Color"
      case false:
        "Fill Color"
      }
    }

    /// Builds a preview using the preset's default style and options.
    @ViewBuilder
    func preview() -> some View {
      render(defaultStyle, defaultSpecificOptions)
    }

    /// Creates a tessera item using the preset's rendering and collision configuration.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the tessera item.
    ///   - weight: Weight applied when selecting items during generation.
    ///   - rotationRange: Allowed rotation range used when rotating the item.
    ///   - scaleRange: Optional scale range applied during placement.
    ///   - style: Style values to use when rendering the item.
    ///   - options: Preset-specific options such as symbol name or text content.
    /// - Returns: A tessera item ready for use in the generator.
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
        collisionShape: collisionShape(style, options),
      ) {
        render(style, options)
      }
    }

    /// Measures the rendered size for the provided style and preset options.
    ///
    /// - Parameters:
    ///   - style: Style applied when rendering.
    ///   - options: Preset-specific options that can affect sizing.
    /// - Returns: The expected rendered size.
    func measuredSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
      measuredSize(style, options)
    }
  }
}

// MARK: - Preset Definitions

extension EditableItem.Preset {
  /// All built-in presets available in the editor.
  static let allPresets: [EditableItem.Preset] = [
    .squareOutline,
    .roundedOutline,
    .partyPopper,
    .minus,
    .equals,
    .circleOutline,
    .text,
  ]

  /// Looks up a preset by its identifier.
  ///
  /// - Parameter id: Identifier of the preset to retrieve.
  /// - Returns: The matching preset or `nil` when none exists.
  static func preset(withID id: String) -> EditableItem.Preset? {
    allPresets.first(where: { $0.id == id })
  }
}

extension EditableItem.Preset {
  static var squareOutline: EditableItem.Preset {
    EditableItem.Preset(
      id: "squareOutline",
      title: "Square Outline",
      iconName: "square.dashed",
      defaultStyle: ItemStyle(
        size: CGSize(width: 30, height: 30),
        color: .gray.opacity(0.8),
        lineWidth: 4,
        fontSize: 32,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      availableSymbols: [],
      defaultSymbolName: "questionmark",
      render: { style, _ in
        AnyView(
          Rectangle()
            .stroke(lineWidth: style.lineWidth)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var roundedOutline: EditableItem.Preset {
    EditableItem.Preset(
      id: "roundedOutline",
      title: "Rounded Outline",
      iconName: "app",
      defaultStyle: ItemStyle(
        size: CGSize(width: 30, height: 30),
        color: .primary,
        lineWidth: 4,
        fontSize: 32,
      ),
      defaultSpecificOptions: .roundedRectangle(cornerRadius: 6),
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: true,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      availableSymbols: [],
      defaultSymbolName: "questionmark",
      render: { style, options in
        AnyView(
          RoundedRectangle(cornerRadius: EditableItemPresetHelpers.cornerRadius(from: options, fallback: 6))
            .stroke(lineWidth: style.lineWidth)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var partyPopper: EditableItem.Preset {
    EditableItem.Preset(
      id: "partyPopper",
      title: "Party Popper",
      iconName: "party.popper.fill",
      defaultStyle: ItemStyle(
        size: CGSize(width: 40, height: 40),
        color: .red.opacity(0.5),
        lineWidth: 2,
        fontSize: 34,
      ),
      defaultSpecificOptions: .systemSymbol(name: "party.popper.fill"),
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: true,
        supportsCornerRadius: false,
        supportsSymbolSelection: true,
        supportsTextContent: false,
      ),
      availableSymbols: [
        "party.popper.fill",
        "wand.and.stars",
        "sparkles",
        "sun.max.fill",
        "moon.stars.fill",
        "heart.fill",
        "burst.fill",
      ],
      defaultSymbolName: "party.popper.fill",
      render: { style, options in
        AnyView(
          Image(systemName: EditableItemPresetHelpers.symbolName(from: options, defaultSymbolName: "party.popper.fill"))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(style.color)
            .font(.system(size: style.fontSize, weight: .regular))
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .circle(radius: max(style.size.width, style.size.height) / 2)
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var minus: EditableItem.Preset {
    EditableItem.Preset(
      id: "minus",
      title: "Minus",
      iconName: "minus",
      defaultStyle: ItemStyle(
        size: CGSize(width: 36, height: 4),
        color: .gray,
        lineWidth: 1,
        fontSize: 34,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: true,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      availableSymbols: [],
      defaultSymbolName: "questionmark",
      render: { style, _ in
        AnyView(
          Text("-")
            .foregroundStyle(style.color)
            .font(.system(size: style.fontSize, weight: .bold))
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: style.size)
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var equals: EditableItem.Preset {
    EditableItem.Preset(
      id: "equals",
      title: "Equals",
      iconName: "equal",
      defaultStyle: ItemStyle(
        size: CGSize(width: 36, height: 12),
        color: .gray,
        lineWidth: 1,
        fontSize: 34,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: true,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      availableSymbols: [],
      defaultSymbolName: "questionmark",
      render: { style, _ in
        AnyView(
          Text("=")
            .foregroundStyle(style.color)
            .font(.system(size: style.fontSize, weight: .bold))
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: style.size)
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var circleOutline: EditableItem.Preset {
    EditableItem.Preset(
      id: "circleOutline",
      title: "Circle Outline",
      iconName: "circle",
      defaultStyle: ItemStyle(
        size: CGSize(width: 26, height: 26),
        color: .gray.opacity(0.2),
        lineWidth: 4,
        fontSize: 32,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      availableSymbols: [],
      defaultSymbolName: "questionmark",
      render: { style, _ in
        AnyView(
          Circle()
            .stroke(lineWidth: style.lineWidth)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .circle(radius: EditableItemPresetHelpers.circleRadius(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var text: EditableItem.Preset {
    EditableItem.Preset(
      id: "text",
      title: "Text",
      iconName: "text.alignleft",
      defaultStyle: ItemStyle(
        size: CGSize(width: 36, height: 24),
        color: .primary,
        lineWidth: 1,
        fontSize: 32,
      ),
      defaultSpecificOptions: .text(content: "Text"),
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: false,
        supportsLineWidth: false,
        supportsFontSize: true,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: true,
      ),
      availableSymbols: [],
      defaultSymbolName: "questionmark",
      render: { style, options in
        AnyView(
          Text(EditableItemPresetHelpers.textContent(from: options))
            .foregroundStyle(style.color)
            .font(.system(size: style.fontSize, weight: .semibold))
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: style.size)
      },
      measuredSize: { style, options in
        EditableItemPresetHelpers.measuredTextSize(for: style, options: options)
      },
    )
  }
}

private enum EditableItemPresetHelpers {
  /// Expands a rectangle's collision shape to account for stroke width.
  ///
  /// - Parameter style: Style providing the base size and stroke width.
  /// - Returns: A size adjusted for the stroke radius.
  static func rectangleCollisionSize(for style: ItemStyle) -> CGSize {
    CGSize(
      width: style.size.width + style.lineWidth,
      height: style.size.height + style.lineWidth,
    )
  }

  /// Calculates a circular collision radius that includes stroke width.
  ///
  /// - Parameter style: Style providing the base diameter and stroke width.
  /// - Returns: The radius used for collision detection.
  static func circleRadius(for style: ItemStyle) -> CGFloat {
    max(style.size.width, style.size.height) / 2 + style.lineWidth / 2
  }

  /// Extracts a corner radius from preset options, falling back when missing.
  ///
  /// - Parameters:
  ///   - options: Preset options that may include a corner radius.
  ///   - fallback: Default radius to use when no value is provided.
  /// - Returns: The corner radius applied to rounded shapes.
  static func cornerRadius(from options: PresetSpecificOptions, fallback: CGFloat) -> CGFloat {
    options.cornerRadius ?? fallback
  }

  /// Selects the system symbol name from preset options or a default.
  ///
  /// - Parameters:
  ///   - options: Preset options that may include a system symbol name.
  ///   - defaultSymbolName: Fallback symbol when none is provided.
  /// - Returns: The symbol name to render.
  static func symbolName(from options: PresetSpecificOptions, defaultSymbolName: String) -> String {
    options.systemSymbolName ?? defaultSymbolName
  }

  /// Selects the text content from preset options or a default placeholder.
  ///
  /// - Parameter options: Preset options that may include custom text content.
  /// - Returns: The text string to render.
  static func textContent(from options: PresetSpecificOptions) -> String {
    options.textContent ?? "Text"
  }

  /// Measures the rendered size of text content for a preset.
  ///
  /// - Parameters:
  ///   - style: Style providing font size and weight.
  ///   - options: Preset options that may include custom text content.
  /// - Returns: The measured size including a small padding buffer.
  static func measuredTextSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
    let content = textContent(from: options)
    let font = NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)

    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let attributedString = NSAttributedString(string: content, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributedString)

    let width = ceil(CTLineGetTypographicBounds(line, nil, nil, nil))

    let coreTextFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
    let ascent = CTFontGetAscent(coreTextFont)
    let descent = CTFontGetDescent(coreTextFont)
    let leading = CTFontGetLeading(coreTextFont)

    let height = ceil(ascent + descent + leading)
    let padding: CGFloat = 2

    return CGSize(width: width + padding, height: height + padding)
  }
}

extension EditableItem {
  /// Flags indicating which styling controls a preset supports.
  struct PresetCapabilities: Equatable {
    var usesStrokeStyle: Bool
    var usesFillStyle: Bool
    var supportsLineWidth: Bool
    var supportsFontSize: Bool
    var supportsCornerRadius: Bool
    var supportsSymbolSelection: Bool
    var supportsTextContent: Bool
  }
}
