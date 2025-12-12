// By Dennis Müller

import CompactSlider
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
  }

  private var isExpanded: Bool {
    expandedItemID == item.id
  }

  private var maximumWidth: Double {
    max(8, Double(editor.activePatternSize.width))
  }

  private var maximumHeight: Double {
    max(8, Double(editor.activePatternSize.height))
  }

  private var displayedEmoji: String {
    item.specificOptions.textContent ?? textContentDraft
  }

  var body: some View {
    InspectorExpandableCard(
      isExpanded: isExpanded,
      isDimmed: item.isVisible == false,
    ) {
      header
    } expandedContent: {
      VStack(alignment: .leading, spacing: .medium) {
        weightOption
        rotationOption
        sizeOption
        colorOption
        lineWidthOption
        fontSizeOption
        presetSpecificOption
        if item.preset.capabilities.supportsFontSize == false {
          customScaleRangeOption
        }
      }
    }
    .animation(.default, value: item.usesCustomScaleRange)
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
    .onChange(of: item.specificOptions) {
      if let radius = item.specificOptions.cornerRadius {
        cornerRadiusDraft = radius
      }
      if let symbol = item.specificOptions.systemSymbolName {
        symbolNameDraft = symbol
      }
      if let textContent = item.specificOptions.textContent {
        textContentDraft = textContent
      }
      if item.preset.capabilities.supportsTextContent {
        refreshTextSize()
      }
    }
    .onChange(of: editor.activePatternSize) {
      widthDraft = min(widthDraft, Double(editor.activePatternSize.width))
      heightDraft = min(heightDraft, Double(editor.activePatternSize.height))
      applySizeDraft()
    }
    .onAppear {
      if item.preset.capabilities.supportsTextContent {
        refreshTextSize()
      }
    }
  }

  @ViewBuilder private var header: some View {
    InspectorCardHeader(
      title: item.title,
      groupIconName: item.preset.groupIconName,
      isExpanded: isExpanded,
      onToggleExpansion: toggleExpansion,
      customName: $item.customName,
      renameDialogTitle: "Rename Item",
      renamePlaceholder: item.preset.title,
      renamePopoverWidth: 260,
      isVisible: $item.isVisible,
      onRemove: onRemove,
    )
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
    if item.preset.capabilities.supportsSizeControl {
      InspectorSizeOptionRow(
        supportsTextContent: item.preset.capabilities.supportsTextContent,
        widthDraft: $widthDraft,
        heightDraft: $heightDraft,
        maximumWidth: maximumWidth,
        maximumHeight: maximumHeight,
        onCommit: applySizeDraft,
      )
    }
  }

  @ViewBuilder private var colorOption: some View {
    if item.preset.capabilities.supportsColorControl {
      InspectorColorOptionRow(
        label: item.preset.colorLabel,
        color: $colorDraft,
        onChange: { color in
          item.style.color = color
        },
      )
    }
  }

  @ViewBuilder private var lineWidthOption: some View {
    if item.preset.capabilities.supportsLineWidth {
      InspectorStrokeWidthOptionRow(strokeWidth: $lineWidthDraft) {
        item.style.lineWidth = lineWidthDraft
      }
    }
  }

  @ViewBuilder private var fontSizeOption: some View {
    if item.preset.capabilities.supportsFontSize {
      InspectorFontSizeOptionRow(fontSize: $fontSizeDraft) {
        item.style.fontSize = fontSizeDraft
        if item.preset.capabilities.supportsTextContent {
          refreshTextSize()
        }
      }
    }
  }

  @ViewBuilder private var presetSpecificOption: some View {
    if item.preset.capabilities.supportsUploadedImage {
      InspectorUploadedImageOptionRow(options: $item.specificOptions)
    } else if item.preset.capabilities.supportsImagePlayground {
      InspectorImagePlaygroundOptionRow(options: $item.specificOptions)
    } else if item.preset.capabilities.supportsCornerRadius {
      InspectorCornerRadiusOptionRow(
        cornerRadius: $cornerRadiusDraft,
        maximumCornerRadius: min(widthDraft, heightDraft) / 2,
        onCommit: { radius in
          item.specificOptions = item.specificOptions.updatingCornerRadius(radius)
        },
      )
    } else if item.preset.capabilities.supportsSymbolSelection {
      InspectorSymbolSelectionOptionRow(
        availableSymbols: item.preset.availableSymbols,
        symbolName: $symbolNameDraft,
        onChange: { name in
          item.specificOptions = item.specificOptions.updatingSymbolName(name)
        },
      )
    } else if item.preset.capabilities.supportsEmojiPicker {
      InspectorEmojiPickerOptionRow(
        currentEmoji: displayedEmoji,
        fontSize: fontSizeDraft,
        onSelectEmojiCharacter: applyEmojiSelection,
      )
    } else if item.preset.capabilities.supportsTextContent {
      InspectorTextContentOptionRow(textContent: $textContentDraft) { text in
        item.specificOptions = item.specificOptions.updatingTextContent(text)
        refreshTextSize()
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

  private func applyEmojiSelection(_ emojiCharacter: String) {
    textContentDraft = emojiCharacter
    item.specificOptions = item.specificOptions.updatingTextContent(emojiCharacter)
    refreshTextSize()
  }

  private func toggleExpansion() {
    if isExpanded {
      expandedItemID = nil
    } else {
      expandedItemID = item.id
    }
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
