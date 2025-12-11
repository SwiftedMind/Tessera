// By Dennis Müller

import SwiftUI
import Tessera

extension EditableItem.PresetGroup {
  static var symbols: EditableItem.PresetGroup {
    EditableItem.PresetGroup(
      id: "symbols",
      title: "Symbols",
      iconName: "sparkles",
      presets: [
        .symbol,
      ],
    )
  }
}

extension EditableItem.Preset {
  static var symbol: EditableItem.Preset {
    let defaultSymbolName = "sparkles"

    return EditableItem.Preset(
      id: "symbol",
      title: "Symbol",
      iconName: "sparkles",
      defaultStyle: ItemStyle(
        size: CGSize(width: 40, height: 40),
        color: .primary,
        lineWidth: 2,
        fontSize: 34,
      ),
      defaultSpecificOptions: .systemSymbol(name: defaultSymbolName),
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: true,
        supportsTextContent: false,
      ),
      availableSymbols: [
        defaultSymbolName,
        "party.popper.fill",
        "wand.and.stars",
        "sun.max.fill",
        "moon.stars.fill",
        "heart.fill",
        "burst.fill",
      ],
      defaultSymbolName: defaultSymbolName,
      render: { style, options in
        AnyView(
          Image(systemName: EditableItemPresetHelpers.symbolName(from: options, defaultSymbolName: defaultSymbolName))
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
}
