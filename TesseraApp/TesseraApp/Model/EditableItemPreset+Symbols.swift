// By Dennis Müller

import SwiftUI
import Tessera

extension EditableItem.PresetGroup {
  static var symbols: EditableItem.PresetGroup {
    EditableItem.PresetGroup(
      id: "symbols",
      title: "Symbols",
      presets: [
        .partyPopper,
      ],
    )
  }
}

extension EditableItem.Preset {
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
}
