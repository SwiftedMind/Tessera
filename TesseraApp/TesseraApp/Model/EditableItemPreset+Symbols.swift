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
        fontSize: 40,
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
      render: { style, options in
        let symbolName = EditableItemPresetHelpers.systemSymbolName(from: options)
        return AnyView(
          Group {
            if let configuredSymbol = EditableItemPresetHelpers.configuredSystemSymbol(
              named: symbolName,
              pointSize: style.fontSize,
            ) {
              configuredSymbol.image
            } else {
              Image(systemName: symbolName)
                .font(.system(size: style.fontSize, weight: .regular))
            }
          }
          .foregroundStyle(style.color)
          .accessibilityLabel(Text(symbolName)),
        )
      },
      collisionShape: { style, options in
        let symbolName = EditableItemPresetHelpers.systemSymbolName(from: options)
        let symbolSize = EditableItemPresetHelpers.measuredSystemSymbolSize(
          named: symbolName,
          pointSize: style.fontSize,
        )
        return .rectangle(size: symbolSize)
      },
      measuredSize: { style, options in
        let symbolName = EditableItemPresetHelpers.systemSymbolName(from: options)
        return EditableItemPresetHelpers.measuredSystemSymbolSize(named: symbolName, pointSize: style.fontSize)
      },
    )
  }
}
