// By Dennis Müller

import CompactSlider
import SwiftUI

struct FixedItemCard: View {
  @Environment(TesseraEditorModel.self) private var editor
  @Binding var fixedItem: EditableFixedItem
  @Binding var expandedFixedItemID: EditableFixedItem.ID?
  @State private var offsetXDraft: CGFloat
  @State private var offsetYDraft: CGFloat
  @State private var rotationDegreesDraft: Double
  @State private var scaleDraft: CGFloat
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
    fixedItem: Binding<EditableFixedItem>,
    expandedFixedItemID: Binding<EditableFixedItem.ID?>,
    onRemove: @escaping () -> Void,
  ) {
    _fixedItem = fixedItem
    _expandedFixedItemID = expandedFixedItemID
    self.onRemove = onRemove

    _offsetXDraft = State(initialValue: fixedItem.wrappedValue.placementOffset.width)
    _offsetYDraft = State(initialValue: fixedItem.wrappedValue.placementOffset.height)
    _rotationDegreesDraft = State(initialValue: fixedItem.wrappedValue.rotationDegrees)
    _scaleDraft = State(initialValue: fixedItem.wrappedValue.scale)

    if fixedItem.wrappedValue.preset.capabilities.supportsTextContent {
      let measuredSize = fixedItem.wrappedValue.preset.measuredSize(
        for: fixedItem.wrappedValue.style,
        options: fixedItem.wrappedValue.specificOptions,
      )
      _widthDraft = State(initialValue: measuredSize.width)
      _heightDraft = State(initialValue: measuredSize.height)
    } else {
      _widthDraft = State(initialValue: fixedItem.wrappedValue.style.size.width)
      _heightDraft = State(initialValue: fixedItem.wrappedValue.style.size.height)
    }

    _lineWidthDraft = State(initialValue: fixedItem.wrappedValue.style.lineWidth)
    _fontSizeDraft = State(initialValue: fixedItem.wrappedValue.style.fontSize)
    _colorDraft = State(initialValue: fixedItem.wrappedValue.style.color)
    _cornerRadiusDraft = State(initialValue: fixedItem.wrappedValue.specificOptions.cornerRadius ?? 6)
    _symbolNameDraft = State(initialValue: fixedItem.wrappedValue.specificOptions.systemSymbolName ?? fixedItem
      .wrappedValue.preset.defaultSymbolName)
    _textContentDraft = State(initialValue: fixedItem.wrappedValue.specificOptions.textContent ?? "Text")
  }

  private var isExpanded: Bool {
    expandedFixedItemID == fixedItem.id
  }

  private var maximumWidth: Double {
    max(8, Double(editor.canvasSize.width))
  }

  private var maximumHeight: Double {
    max(8, Double(editor.canvasSize.height))
  }

  private var maximumOffsetX: CGFloat {
    editor.canvasSize.width
  }

  private var maximumOffsetY: CGFloat {
    editor.canvasSize.height
  }

  private var displayedEmoji: String {
    fixedItem.specificOptions.textContent ?? textContentDraft
  }

  var body: some View {
    InspectorExpandableCard(
      isExpanded: isExpanded,
      isDimmed: fixedItem.isVisible == false,
    ) {
      header
    } expandedContent: {
      VStack(alignment: .leading, spacing: .medium) {
        placementOption
        offsetOption
        fixedRotationOption
        if fixedItem.preset.capabilities.supportsFontSize == false {
          fixedScaleOption
        }
        sizeOption
        colorOption
        lineWidthOption
        fontSizeOption
        presetSpecificOption
      }
    }
    .onChange(of: fixedItem.style) {
      widthDraft = fixedItem.style.size.width
      heightDraft = fixedItem.style.size.height
      lineWidthDraft = fixedItem.style.lineWidth
      fontSizeDraft = fixedItem.style.fontSize
      colorDraft = fixedItem.style.color
    }
    .onChange(of: fixedItem.placementOffset) {
      offsetXDraft = fixedItem.placementOffset.width
      offsetYDraft = fixedItem.placementOffset.height
    }
    .onChange(of: fixedItem.rotationDegrees) {
      rotationDegreesDraft = fixedItem.rotationDegrees
    }
    .onChange(of: fixedItem.scale) {
      scaleDraft = fixedItem.scale
    }
    .onChange(of: fixedItem.specificOptions) {
      if let radius = fixedItem.specificOptions.cornerRadius {
        cornerRadiusDraft = radius
      }
      if let symbol = fixedItem.specificOptions.systemSymbolName {
        symbolNameDraft = symbol
      }
      if let textContent = fixedItem.specificOptions.textContent {
        textContentDraft = textContent
      }
      if fixedItem.preset.capabilities.supportsTextContent {
        refreshTextSize()
      }
    }
    .onChange(of: editor.canvasSize) {
      widthDraft = min(widthDraft, maximumWidth)
      heightDraft = min(heightDraft, maximumHeight)
      applySizeDraft()
    }
    .onAppear {
      if fixedItem.preset.capabilities.supportsTextContent {
        refreshTextSize()
      }
    }
  }

  @ViewBuilder private var header: some View {
    InspectorCardHeader(
      title: fixedItem.title,
      groupIconName: fixedItem.preset.groupIconName,
      isExpanded: isExpanded,
      onToggleExpansion: toggleExpansion,
      customName: $fixedItem.customName,
      renameDialogTitle: "Rename Fixed Item",
      renamePlaceholder: fixedItem.preset.title,
      renamePopoverWidth: 280,
      isVisible: $fixedItem.isVisible,
      onRemove: onRemove,
    )
  }

  @ViewBuilder private var placementOption: some View {
    OptionRow("Placement") {
      Picker("", selection: $fixedItem.placementAnchor) {
        ForEach(FixedItemPlacementAnchor.allCases) { anchor in
          Text(anchor.title)
            .tag(anchor)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
    }
  }

  private var offsetOption: some View {
    OptionRow("Offset") {
      SystemSlider(
        value: $offsetXDraft,
        in: -maximumOffsetX...maximumOffsetX,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyOffsetDraft)

      SystemSlider(
        value: $offsetYDraft,
        in: -maximumOffsetY...maximumOffsetY,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyOffsetDraft)
    } trailing: {
      Text("X: \(offsetXDraft.formatted()), Y: \(offsetYDraft.formatted())")
    }
  }

  private var fixedRotationOption: some View {
    OptionRow("Rotation") {
      SystemSlider(
        value: $rotationDegreesDraft,
        in: 0...360,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyRotationDraft)
    } trailing: {
      Text("\(rotationDegreesDraft.formatted(.number.precision(.fractionLength(0))))°")
    }
  }

  private var fixedScaleOption: some View {
    OptionRow("Scale") {
      SystemSlider(
        value: $scaleDraft,
        in: 1...5,
        step: 0.1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyScaleDraft)
    } trailing: {
      Text("\(Double(scaleDraft).formatted(.number.precision(.fractionLength(2))))×")
    }
  }

  @ViewBuilder private var sizeOption: some View {
    if fixedItem.preset.capabilities.supportsSizeControl {
      InspectorSizeOptionRow(
        supportsTextContent: fixedItem.preset.capabilities.supportsTextContent,
        widthDraft: $widthDraft,
        heightDraft: $heightDraft,
        maximumWidth: maximumWidth,
        maximumHeight: maximumHeight,
        onCommit: applySizeDraft,
      )
    }
  }

  @ViewBuilder private var colorOption: some View {
    if fixedItem.preset.capabilities.supportsColorControl {
      InspectorColorOptionRow(
        label: fixedItem.preset.colorLabel,
        color: $colorDraft,
        onChange: { color in
          fixedItem.style.color = color
        },
      )
    }
  }

  @ViewBuilder private var lineWidthOption: some View {
    if fixedItem.preset.capabilities.supportsLineWidth {
      InspectorStrokeWidthOptionRow(strokeWidth: $lineWidthDraft) {
        fixedItem.style.lineWidth = lineWidthDraft
      }
    }
  }

  @ViewBuilder private var fontSizeOption: some View {
    if fixedItem.preset.capabilities.supportsFontSize {
      InspectorFontSizeOptionRow(fontSize: $fontSizeDraft) {
        fixedItem.style.fontSize = fontSizeDraft
        if fixedItem.preset.capabilities.supportsTextContent {
          refreshTextSize()
        }
      }
    }
  }

  @ViewBuilder private var presetSpecificOption: some View {
    if fixedItem.preset.capabilities.supportsUploadedImage {
      InspectorUploadedImageOptionRow(options: $fixedItem.specificOptions)
    } else if fixedItem.preset.capabilities.supportsImagePlayground {
      InspectorImagePlaygroundOptionRow(options: $fixedItem.specificOptions)
    } else if fixedItem.preset.capabilities.supportsCornerRadius {
      InspectorCornerRadiusOptionRow(
        cornerRadius: $cornerRadiusDraft,
        maximumCornerRadius: min(widthDraft, heightDraft) / 2,
        onCommit: { radius in
          fixedItem.specificOptions = fixedItem.specificOptions.updatingCornerRadius(radius)
        },
      )
    } else if fixedItem.preset.capabilities.supportsSymbolSelection {
      InspectorSymbolSelectionOptionRow(
        availableSymbols: fixedItem.preset.availableSymbols,
        symbolName: $symbolNameDraft,
        onChange: { name in
          fixedItem.specificOptions = fixedItem.specificOptions.updatingSymbolName(name)
        },
      )
    } else if fixedItem.preset.capabilities.supportsEmojiPicker {
      InspectorEmojiPickerOptionRow(
        currentEmoji: displayedEmoji,
        fontSize: fontSizeDraft,
        onSelectEmojiCharacter: applyEmojiSelection,
      )
    } else if fixedItem.preset.capabilities.supportsTextContent {
      InspectorTextContentOptionRow(textContent: $textContentDraft) { text in
        fixedItem.specificOptions = fixedItem.specificOptions.updatingTextContent(text)
        refreshTextSize()
      }
    }
  }

  private func applySizeDraft() {
    let clampedWidth = min(widthDraft, maximumWidth)
    let clampedHeight = min(heightDraft, maximumHeight)
    widthDraft = clampedWidth
    heightDraft = clampedHeight
    fixedItem.style.size = CGSize(width: clampedWidth, height: clampedHeight)
  }

  private func applyOffsetDraft() {
    fixedItem.placementOffset = CGSize(width: offsetXDraft, height: offsetYDraft)
  }

  private func applyRotationDraft() {
    fixedItem.rotationDegrees = rotationDegreesDraft
  }

  private func applyScaleDraft() {
    fixedItem.scale = scaleDraft
  }

  private func refreshTextSize() {
    guard fixedItem.preset.capabilities.supportsTextContent else { return }

    let measuredSize = fixedItem.preset.measuredSize(for: fixedItem.style, options: fixedItem.specificOptions)
    if measuredSize != fixedItem.style.size {
      fixedItem.style.size = measuredSize
    }
    widthDraft = measuredSize.width
    heightDraft = measuredSize.height
  }

  private func applyEmojiSelection(_ emojiCharacter: String) {
    textContentDraft = emojiCharacter
    fixedItem.specificOptions = fixedItem.specificOptions.updatingTextContent(emojiCharacter)
    refreshTextSize()
  }

  private func toggleExpansion() {
    if isExpanded {
      expandedFixedItemID = nil
    } else {
      expandedFixedItemID = fixedItem.id
    }
  }
}

#Preview {
  @Previewable @Environment(TesseraEditorModel.self) var editor

  FixedItemCard(
    fixedItem: .constant(EditableFixedItem(preset: .squareOutline)),
    expandedFixedItemID: .constant(nil),
  ) {}
    .environment(editor)
    .padding(.large)
}
