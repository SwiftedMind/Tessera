// By Dennis Müller

import CoreText
import SwiftUI
import Tessera

extension EditableItem.PresetGroup {
  static var textual: EditableItem.PresetGroup {
    EditableItem.PresetGroup(
      id: "text",
      title: "Text",
      iconName: "textformat",
      presets: [
        .text,
        .minus,
        .equals,
      ],
    )
  }
}

extension EditableItem.Preset {
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
}
