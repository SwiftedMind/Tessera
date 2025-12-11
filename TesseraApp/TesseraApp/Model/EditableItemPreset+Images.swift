// By Dennis Müller

import SwiftUI
import Tessera

extension EditableItem.PresetGroup {
  static var images: EditableItem.PresetGroup {
    EditableItem.PresetGroup(
      id: "images",
      title: "Images",
      iconName: "photo.on.rectangle",
      presets: [
        .playground,
      ],
    )
  }
}

extension EditableItem.Preset {
  static var playground: EditableItem.Preset {
    EditableItem.Preset(
      id: "imagePlayground",
      title: "Playground",
      iconName: "sparkles.rectangle.stack",
      defaultStyle: ItemStyle(
        size: CGSize(width: 96, height: 96),
        color: .primary,
        lineWidth: 1,
        fontSize: 14,
      ),
      defaultSpecificOptions: .imagePlayground(assetID: nil, imageData: nil, fileExtension: nil),
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
        supportsColorControl: false,
        supportsEmojiPicker: false,
        supportsImagePlayground: true,
      ),
      availableSymbols: [],
      defaultSymbolName: "photo.on.rectangle",
      render: { style, options in
        let image = EditableItemPresetHelpers.playgroundImage(from: options)
        return AnyView(
          ZStack {
            if let image {
              image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: style.size.width, height: style.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary)
                .overlay {
                  VStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack")
                      .font(.title2)
                      .foregroundStyle(.secondary)
                    Text("Generate Image")
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                  }
                }
                .frame(width: style.size.width, height: style.size.height)
            }
          },
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
