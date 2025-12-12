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
        .emoji,
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

  static var emoji: EditableItem.Preset {
    EditableItem.Preset(
      id: "emoji",
      title: "Emoji",
      iconName: "face.smiling",
      defaultStyle: ItemStyle(
        size: CGSize(width: 44, height: 44),
        color: .primary,
        lineWidth: 0,
        fontSize: 42,
      ),
      defaultSpecificOptions: .text(content: "😀"),
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: false,
        supportsLineWidth: false,
        supportsFontSize: true,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: true,
        supportsColorControl: false,
        supportsEmojiPicker: true,
      ),
      render: { style, options in
        AnyView(
          Text(EditableItemPresetHelpers.textContent(from: options))
            .foregroundStyle(style.color)
            .font(.system(size: style.fontSize))
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
