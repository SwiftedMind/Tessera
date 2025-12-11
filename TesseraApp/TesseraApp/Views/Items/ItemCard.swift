// By Dennis Müller

import CompactSlider
import EmojiKit
import SwiftUI

struct ItemCard: View {
  @Environment(TesseraEditorModel.self) private var editor
  @Binding var item: EditableItem
  @Binding var expandedItemID: EditableItem.ID?
  @State private var weightDraft: Double
  @State private var rotationDraft: ClosedRange<Double>
  @State private var scaleRangeDraft: ClosedRange<Double>
  @State private var widthDraft: Double
  @State private var heightDraft: Double
  @State private var lineWidthDraft: Double
  @State private var fontSizeDraft: Double
  @State private var colorDraft: Color
  @State private var cornerRadiusDraft: Double
  @State private var symbolNameDraft: String
  @State private var textContentDraft: String
  @State private var nameDraft: String
  @State private var isRenaming: Bool
  @State private var isEmojiPickerPresented: Bool
  @State private var emojiPickerQuery: String
  @State private var emojiPickerSelection: Emoji.GridSelection
  var onRemove: () -> Void

  init(
    item: Binding<EditableItem>,
    expandedItemID: Binding<EditableItem.ID?>,
    onRemove: @escaping () -> Void,
  ) {
    _item = item
    _expandedItemID = expandedItemID
    self.onRemove = onRemove
    _weightDraft = State(initialValue: item.wrappedValue.weight)
    _rotationDraft = State(initialValue: item.wrappedValue.minimumRotation...item.wrappedValue.maximumRotation)
    _scaleRangeDraft = State(initialValue: item.wrappedValue.minimumScale...item.wrappedValue.maximumScale)
    if item.wrappedValue.preset.capabilities.supportsTextContent {
      let measuredSize = item.wrappedValue.preset.measuredSize(
        for: item.wrappedValue.style,
        options: item.wrappedValue.specificOptions,
      )
      _widthDraft = State(initialValue: measuredSize.width)
      _heightDraft = State(initialValue: measuredSize.height)
    } else {
      _widthDraft = State(initialValue: item.wrappedValue.style.size.width)
      _heightDraft = State(initialValue: item.wrappedValue.style.size.height)
    }
    _lineWidthDraft = State(initialValue: item.wrappedValue.style.lineWidth)
    _fontSizeDraft = State(initialValue: item.wrappedValue.style.fontSize)
    _colorDraft = State(initialValue: item.wrappedValue.style.color)
    _cornerRadiusDraft = State(initialValue: item.wrappedValue.specificOptions.cornerRadius ?? 6)
    _symbolNameDraft = State(initialValue: item.wrappedValue.specificOptions.systemSymbolName ?? item.wrappedValue
      .preset.defaultSymbolName)
    _textContentDraft = State(initialValue: item.wrappedValue.specificOptions.textContent ?? "Text")
    _nameDraft = State(initialValue: item.wrappedValue.customName ?? "")
    _isRenaming = State(initialValue: false)
    _isEmojiPickerPresented = State(initialValue: false)
    _emojiPickerQuery = State(initialValue: "")
    _emojiPickerSelection = State(initialValue: Emoji.GridSelection())
  }

  private var isExpanded: Bool {
    expandedItemID == item.id
  }

  private var maximumWidth: Double {
    max(8, editor.tesseraSize.width)
  }

  private var maximumHeight: Double {
    max(8, editor.tesseraSize.height)
  }

  private var displayedEmoji: String {
    item.specificOptions.textContent ?? textContentDraft
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if isExpanded {
        VStack(alignment: .leading, spacing: .medium) {
          weightOption
          rotationOption
          sizeOption
          colorOption
          lineWidthOption
          fontSizeOption
          presetSpecificOption
          customScaleRangeOption
        }
        .padding([.horizontal, .bottom], .mediumRelaxed)
        .transition(.opacity)
      }
    }
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.white.opacity(0.2)),
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .animation(.default, value: expandedItemID)
    .animation(.default, value: item.usesCustomScaleRange)
    .geometryGroup()
    .opacity(item.isVisible ? 1 : 0.5)
    .onChange(of: item.weight) {
      if weightDraft != item.weight {
        weightDraft = item.weight
      }
    }
    .onChange(of: item.minimumRotation) {
      rotationDraft = item.minimumRotation...item.maximumRotation
    }
    .onChange(of: item.maximumRotation) {
      rotationDraft = item.minimumRotation...item.maximumRotation
    }
    .onChange(of: item.minimumScale) {
      scaleRangeDraft = item.minimumScale...item.maximumScale
    }
    .onChange(of: item.maximumScale) {
      scaleRangeDraft = item.minimumScale...item.maximumScale
    }
    .onChange(of: item.style) {
      widthDraft = item.style.size.width
      heightDraft = item.style.size.height
      lineWidthDraft = item.style.lineWidth
      fontSizeDraft = item.style.fontSize
      colorDraft = item.style.color
    }
    .onChange(of: item.customName) {
      nameDraft = item.customName ?? ""
    }
    .onChange(of: item.specificOptions) {
      if let radius = item.specificOptions.cornerRadius {
        cornerRadiusDraft = radius
      }
      if let symbol = item.specificOptions.systemSymbolName {
        symbolNameDraft = symbol
      }
      if let textContent = item.specificOptions.textContent {
        textContentDraft = textContent
        if item.preset.capabilities.supportsEmojiPicker {
          emojiPickerSelection = Emoji.GridSelection(
            emoji: Emoji(textContent),
            category: emojiPickerSelection.category ?? .smileysAndPeople,
          )
        }
      }
      if item.preset.capabilities.supportsTextContent {
        refreshTextSize()
      }
    }
    .onChange(of: editor.tesseraSize) {
      widthDraft = min(widthDraft, editor.tesseraSize.width)
      heightDraft = min(heightDraft, editor.tesseraSize.height)
      applySizeDraft()
    }
    .onAppear {
      if item.preset.capabilities.supportsTextContent {
        refreshTextSize()
      }
    }
  }

  @ViewBuilder private var header: some View {
    Button {
      toggleExpansion()
    } label: {
      HStack(alignment: .center, spacing: .medium) {
        Image(systemName: "chevron.right")
          .rotationEffect(.degrees(isExpanded ? 90 : 0))
          .foregroundStyle(.secondary)
          .animation(.default, value: isExpanded)
        if let groupIconName = item.preset.groupIconName {
          Image(systemName: groupIconName)
            .foregroundStyle(.secondary)
        }
        Text(item.title)
          .font(.headline)
        renameButton
        Spacer()
        Button {
          item.isVisible.toggle()
        } label: {
          Image(systemName: item.isVisible ? "eye" : "eye.slash")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        Button(role: .destructive, action: onRemove) {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
      }
      .padding(.mediumRelaxed)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private var renameButton: some View {
    Button {
      beginRenaming()
    } label: {
      Image(systemName: "pencil")
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $isRenaming) {
      VStack(alignment: .leading, spacing: .medium) {
        Text("Rename Item")
          .font(.headline)
        OptionTextField(text: $nameDraft, placeholder: item.preset.title)
          .onSubmit(commitNameChange)
        HStack {
          Spacer()
          Button("Cancel") {
            isRenaming = false
          }
          Button("Save") {
            commitNameChange()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.return)
        }
      }
      .padding(.mediumRelaxed)
      .frame(width: 260)
    }
  }

  @ViewBuilder private var weightOption: some View {
    OptionRow("Weight") {
      VStack(alignment: .leading, spacing: .tight) {
        SystemSlider(
          value: $weightDraft,
          in: 0.2...6,
          step: 0.1,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          item.weight = weightDraft
        }
        HStack {
          Text("Low")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Text("High")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  @ViewBuilder private var rotationOption: some View {
    OptionRow("Rotation") {
      RangeSliderView(
        range: $rotationDraft,
        bounds: -180...180,
        step: 1,
      )
    } trailing: {
      let lower = rotationDraft.lowerBound.formatted(.number.precision(.fractionLength(0)))
      let upper = rotationDraft.upperBound.formatted(.number.precision(.fractionLength(0)))
      Text("\(lower)° – \(upper)°")
    }
    .onSliderCommit {
      item.minimumRotation = rotationDraft.lowerBound
      item.maximumRotation = rotationDraft.upperBound
    }
  }

  @ViewBuilder private var sizeOption: some View {
    if item.preset.capabilities.supportsTextContent {
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
            .onSliderCommit(applySizeDraft)
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
            .onSliderCommit(applySizeDraft)
          }
        }
      } trailing: {
        Text("\(widthDraft.formatted()) × \(heightDraft.formatted())")
      }
    }
  }

  @ViewBuilder private var colorOption: some View {
    if item.preset.capabilities.supportsColorControl {
      OptionRow(item.preset.colorLabel) {
        ColorPicker("", selection: $colorDraft, supportsOpacity: true)
          .labelsHidden()
          .onChange(of: colorDraft) {
            item.style.color = colorDraft
          }
      }
    }
  }

  @ViewBuilder private var lineWidthOption: some View {
    if item.preset.capabilities.supportsLineWidth {
      OptionRow("Stroke Width") {
        SystemSlider(
          value: $lineWidthDraft,
          in: 0.5...16,
          step: 0.5,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          item.style.lineWidth = lineWidthDraft
        }
      } trailing: {
        Text("\(lineWidthDraft.formatted(.number.precision(.fractionLength(1)))) pt")
      }
    }
  }

  @ViewBuilder private var fontSizeOption: some View {
    if item.preset.capabilities.supportsFontSize {
      OptionRow("Font Size") {
        SystemSlider(
          value: $fontSizeDraft,
          in: 10...150,
          step: 1,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          item.style.fontSize = fontSizeDraft
          if item.preset.capabilities.supportsTextContent {
            refreshTextSize()
          }
        }
      } trailing: {
        Text(fontSizeDraft.formatted(.number.precision(.fractionLength(0))))
      }
    }
  }

  @ViewBuilder private var presetSpecificOption: some View {
    if item.preset.capabilities.supportsCornerRadius {
      OptionRow("Corner Radius") {
        SystemSlider(
          value: $cornerRadiusDraft,
          in: 0...min(widthDraft, heightDraft) / 2,
          step: 0.5,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          item.specificOptions = item.specificOptions.updatingCornerRadius(cornerRadiusDraft)
        }
      } trailing: {
        Text(cornerRadiusDraft.formatted(.number.precision(.fractionLength(1))))
      }
    } else if item.preset.capabilities.supportsSymbolSelection {
      OptionRow("Symbol") {
        Picker("Symbol", selection: $symbolNameDraft) {
          ForEach(item.preset.availableSymbols, id: \.self) { name in
            Label(name, systemImage: name).tag(name)
          }
        }
        .labelsHidden()
        .onChange(of: symbolNameDraft) {
          item.specificOptions = item.specificOptions.updatingSymbolName(symbolNameDraft)
        }
      }
    } else if item.preset.capabilities.supportsEmojiPicker {
      emojiPickerOption
    } else if item.preset.capabilities.supportsTextContent {
      OptionRow("Text") {
        OptionTextField(text: $textContentDraft)
          .onSubmit {
            item.specificOptions = item.specificOptions.updatingTextContent(textContentDraft)
            refreshTextSize()
          }
      }
    }
  }

  @ViewBuilder private var emojiPickerOption: some View {
    OptionRow("Emoji") {
      Button {
        emojiPickerSelection = Emoji.GridSelection(
          emoji: Emoji(displayedEmoji),
          category: .smileysAndPeople,
        )
        isEmojiPickerPresented = true
      } label: {
        HStack(spacing: .small) {
          Text(displayedEmoji)
            .font(.system(size: fontSizeDraft))
          Image(systemName: "chevron.down")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, .small)
        .padding(.vertical, .extraSmall)
      }
      .buttonStyle(.bordered)
      .popover(isPresented: $isEmojiPickerPresented) {
        EmojiPickerPopover(
          isPresented: $isEmojiPickerPresented,
          query: $emojiPickerQuery,
          selection: $emojiPickerSelection,
          onSelect: applyEmojiSelection,
        )
        .frame(width: 400, height: 440)
      }
    }
  }

  @ViewBuilder private var customScaleRangeOption: some View {
    OptionRow("Global Overrides") {
      EmptyView()
    } trailing: {
      Toggle(isOn: $item.usesCustomScaleRange) {
        Text("Enabled")
      }
    }
    if item.usesCustomScaleRange {
      OptionRow("Size Variability") {
        RangeSliderView(
          range: $scaleRangeDraft,
          bounds: 0.3...2.0,
          step: 0.05,
        )
      } trailing: {
        let lower = scaleRangeDraft.lowerBound.formatted(.number.precision(.fractionLength(2)))
        let upper = scaleRangeDraft.upperBound.formatted(.number.precision(.fractionLength(2)))
        Text("\(lower)x – \(upper)x")
      }
      .onSliderCommit {
        item.minimumScale = scaleRangeDraft.lowerBound
        item.maximumScale = scaleRangeDraft.upperBound
      }
      .transition(.opacity)
    }
  }

  private func applySizeDraft() {
    let clampedWidth = min(widthDraft, maximumWidth)
    let clampedHeight = min(heightDraft, maximumHeight)
    widthDraft = clampedWidth
    heightDraft = clampedHeight
    item.style.size = CGSize(width: clampedWidth, height: clampedHeight)
  }

  private func refreshTextSize() {
    guard item.preset.capabilities.supportsTextContent else { return }

    let measuredSize = item.preset.measuredSize(for: item.style, options: item.specificOptions)
    if measuredSize != item.style.size {
      item.style.size = measuredSize
    }
    widthDraft = measuredSize.width
    heightDraft = measuredSize.height
  }

  private func applyEmojiSelection(_ emoji: Emoji) {
    textContentDraft = emoji.char
    item.specificOptions = item.specificOptions.updatingTextContent(emoji.char)
    refreshTextSize()
    isEmojiPickerPresented = false
  }

  private func beginRenaming() {
    nameDraft = item.customName ?? ""
    isRenaming = true
  }

  private func commitNameChange() {
    let trimmedName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    item.customName = trimmedName.isEmpty ? nil : trimmedName
    isRenaming = false
  }

  private func toggleExpansion() {
    if isExpanded {
      expandedItemID = nil
    } else {
      expandedItemID = item.id
    }
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

#Preview {
  @Previewable @Environment(TesseraEditorModel.self) var editor
  @Previewable @State var item: EditableItem = .demoItems[0]
  @Previewable @State var expandedItemID: EditableItem.ID?

  ItemCard(item: $item, expandedItemID: $expandedItemID) {}
    .padding(.large)
    .frame(height: 600)
    .environment(editor)
}
