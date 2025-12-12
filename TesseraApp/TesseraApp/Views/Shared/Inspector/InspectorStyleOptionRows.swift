// By Dennis Müller

import CompactSlider
import EmojiKit
import Foundation
import ImagePlayground
import SwiftUI

struct InspectorSizeOptionRow: View {
  var supportsTextContent: Bool
  @Binding var widthDraft: Double
  @Binding var heightDraft: Double
  var maximumWidth: Double
  var maximumHeight: Double
  var onCommit: () -> Void

  var body: some View {
    if supportsTextContent {
      OptionRow("Size") {
        EmptyView()
      } trailing: {
        Text("Auto (\(widthDraft.formatted()) × \(heightDraft.formatted()))")
      }
    } else {
      OptionRow("Size") {
        HStack(spacing: .medium) {
          VStack(alignment: .leading, spacing: .extraSmall) {
            Text("Width")
              .font(.caption)
              .foregroundStyle(.secondary)
            SystemSlider(
              value: $widthDraft,
              in: 8...maximumWidth,
              step: 1,
            )
            .compactSliderScale(visibility: .hidden)
            .onSliderCommit(onCommit)
          }
          VStack(alignment: .leading, spacing: .extraSmall) {
            Text("Height")
              .font(.caption)
              .foregroundStyle(.secondary)
            SystemSlider(
              value: $heightDraft,
              in: 8...maximumHeight,
              step: 1,
            )
            .compactSliderScale(visibility: .hidden)
            .onSliderCommit(onCommit)
          }
        }
      } trailing: {
        Text("\(widthDraft.formatted()) × \(heightDraft.formatted())")
      }
    }
  }
}

struct InspectorColorOptionRow: View {
  var label: LocalizedStringKey
  @Binding var color: Color
  var onChange: (Color) -> Void

  var body: some View {
    OptionRow(label) {
      ColorPicker("", selection: $color, supportsOpacity: true)
        .labelsHidden()
        .onChange(of: color) {
          onChange(color)
        }
    }
  }
}

struct InspectorStrokeWidthOptionRow: View {
  @Binding var strokeWidth: Double
  var onCommit: () -> Void

  var body: some View {
    OptionRow("Stroke Width") {
      SystemSlider(
        value: $strokeWidth,
        in: 0.5...16,
        step: 0.5,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(onCommit)
    } trailing: {
      Text("\(strokeWidth.formatted(.number.precision(.fractionLength(1)))) pt")
    }
  }
}

struct InspectorFontSizeOptionRow: View {
  @Binding var fontSize: Double
  var onCommit: () -> Void

  var body: some View {
    OptionRow("Font Size") {
      SystemSlider(
        value: $fontSize,
        in: 10...150,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(onCommit)
    } trailing: {
      Text(fontSize.formatted(.number.precision(.fractionLength(0))))
    }
  }
}

struct InspectorCornerRadiusOptionRow: View {
  @Binding var cornerRadius: Double
  var maximumCornerRadius: Double
  var onCommit: (Double) -> Void

  var body: some View {
    OptionRow("Corner Radius") {
      SystemSlider(
        value: $cornerRadius,
        in: 0...maximumCornerRadius,
        step: 0.5,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit {
        onCommit(cornerRadius)
      }
    } trailing: {
      Text(cornerRadius.formatted(.number.precision(.fractionLength(1))))
    }
  }
}

struct InspectorSymbolSelectionOptionRow: View {
  var availableSymbols: [String]
  @Binding var symbolName: String
  var onChange: (String) -> Void

  var body: some View {
    OptionRow("Symbol") {
      Picker("Symbol", selection: $symbolName) {
        ForEach(availableSymbols, id: \.self) { name in
          Label(name, systemImage: name).tag(name)
        }
      }
      .labelsHidden()
      .onChange(of: symbolName) {
        onChange(symbolName)
      }
    }
  }
}

struct InspectorTextContentOptionRow: View {
  @Binding var textContent: String
  var onCommit: (String) -> Void

  var body: some View {
    OptionRow("Text") {
      OptionTextField(text: $textContent)
        .onSubmit {
          onCommit(textContent)
        }
    }
  }
}

struct InspectorEmojiPickerOptionRow: View {
  var currentEmoji: String
  var fontSize: Double
  var onSelectEmojiCharacter: (String) -> Void
  @State private var isPresented: Bool = false
  @State private var query: String = ""
  @State private var selection: Emoji.GridSelection = .init()

  var body: some View {
    OptionRow("Emoji") {
      Button {
        selection = Emoji.GridSelection(
          emoji: Emoji(currentEmoji),
          category: selection.category ?? .smileysAndPeople,
        )
        isPresented = true
      } label: {
        HStack(spacing: .small) {
          Text(currentEmoji)
            .font(.system(size: fontSize))
          Image(systemName: "chevron.down")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, .small)
        .padding(.vertical, .extraSmall)
      }
      .buttonStyle(.bordered)
      .popover(isPresented: $isPresented) {
        EmojiPickerPopover(
          isPresented: $isPresented,
          query: $query,
          selection: $selection,
          onSelect: { emoji in
            onSelectEmojiCharacter(emoji.char)
            isPresented = false
          },
        )
        .frame(width: 400, height: 440)
      }
    }
  }
}

struct InspectorImagePlaygroundOptionRow: View {
  @Environment(\.supportsImagePlayground) private var supportsImagePlayground
  @Binding var options: PresetSpecificOptions
  @State private var isPresented: Bool = false

  var body: some View {
    OptionRow(
      "Image Playground",
      subtitle: supportsImagePlayground ? "Generate a seamless image tile." : "Not available on this device.",
    ) {
      VStack(alignment: .leading, spacing: .small) {
        HStack(spacing: .medium) {
          if let previewImage {
            previewImage
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 80, height: 80)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .strokeBorder(.white.opacity(0.2))
              }
          } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(.quaternary)
              .frame(width: 80, height: 80)
              .overlay {
                Image(systemName: "photo.on.rectangle")
                  .foregroundStyle(.secondary)
              }
          }

          Spacer()

          Button("Open Playground") {
            isPresented = true
          }
          .buttonStyle(.borderedProminent)
          .disabled(supportsImagePlayground == false)
        }
      }
    }
    .imagePlaygroundSheet(
      isPresented: $isPresented,
      sourceImage: nil,
      onCompletion: handleCompletion,
      onCancellation: handleCancellation,
    )
  }

  private var previewImage: Image? {
    EditableItemPresetHelpers.playgroundImage(from: options)
  }

  private func handleCompletion(_ url: URL) {
    guard let data = try? Data(contentsOf: url) else { return }

    let fileExtension = url.pathExtension.isEmpty == false ? url.pathExtension.lowercased() : "png"
    let assetID = options.imagePlaygroundAssetID ?? UUID()

    options = options.updatingImagePlayground(
      assetID: assetID,
      imageData: data,
      fileExtension: fileExtension,
    )
  }

  private func handleCancellation() {
    isPresented = false
  }
}

private struct EmojiPickerPopover: View {
  @Binding var isPresented: Bool
  @Binding var query: String
  @Binding var selection: Emoji.GridSelection
  var onSelect: (Emoji) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: .medium) {
      HStack {
        Text("Choose Emoji")
          .font(.headline)
        Spacer()
        Button("Done") {
          isPresented = false
        }
        .buttonStyle(.borderedProminent)
      }
      TextField("Search Emoji", text: $query)
        .textFieldStyle(.roundedBorder)
      Divider()
      EmojiGridScrollView(
        axis: .vertical,
        query: query,
        selection: $selection,
        action: onSelect,
        sectionTitle: { $0.view },
        gridItem: { $0.view },
      )
      .emojiGridStyle(.medium)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.mediumRelaxed)
  }
}
