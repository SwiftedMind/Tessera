// By Dennis Müller

import CompactSlider
import SwiftUI

struct FixedItemCard: View {
  @Environment(TesseraEditorModel.self) private var editor
  @Binding var fixedItem: EditableFixedItem
  @Binding var expandedFixedItemID: EditableFixedItem.ID?
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
  var onRemove: () -> Void

  init(
    fixedItem: Binding<EditableFixedItem>,
    expandedFixedItemID: Binding<EditableFixedItem.ID?>,
    onRemove: @escaping () -> Void,
  ) {
    _fixedItem = fixedItem
    _expandedFixedItemID = expandedFixedItemID
    self.onRemove = onRemove

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
    _nameDraft = State(initialValue: fixedItem.wrappedValue.customName ?? "")
    _isRenaming = State(initialValue: false)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if isExpanded {
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
    .animation(.default, value: expandedFixedItemID)
    .geometryGroup()
    .opacity(fixedItem.isVisible ? 1 : 0.5)
    .onChange(of: fixedItem.style) {
      widthDraft = fixedItem.style.size.width
      heightDraft = fixedItem.style.size.height
      lineWidthDraft = fixedItem.style.lineWidth
      fontSizeDraft = fixedItem.style.fontSize
      colorDraft = fixedItem.style.color
    }
    .onChange(of: fixedItem.customName) {
      nameDraft = fixedItem.customName ?? ""
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
        if fixedItem.preset.capabilities.supportsTextContent {
          refreshTextSize()
        }
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
    Button {
      toggleExpansion()
    } label: {
      HStack(alignment: .center, spacing: .medium) {
        Image(systemName: "chevron.right")
          .rotationEffect(.degrees(isExpanded ? 90 : 0))
          .foregroundStyle(.secondary)
          .animation(.default, value: isExpanded)
        if let groupIconName = fixedItem.preset.groupIconName {
          Image(systemName: groupIconName)
            .foregroundStyle(.secondary)
        }
        Text(fixedItem.title)
          .font(.headline)
        renameButton
        Spacer()
        Button {
          fixedItem.isVisible.toggle()
        } label: {
          Image(systemName: fixedItem.isVisible ? "eye" : "eye.slash")
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
        Text("Rename Fixed Item")
          .font(.headline)
        OptionTextField(text: $nameDraft, placeholder: fixedItem.preset.title)
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
      .frame(width: 280)
    }
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
        value: Binding(
          get: { fixedItem.placementOffset.width },
          set: { newValue in
            fixedItem.placementOffset.width = newValue
          },
        ),
        in: -maximumOffsetX...maximumOffsetX,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)

      SystemSlider(
        value: Binding(
          get: { fixedItem.placementOffset.height },
          set: { newValue in
            fixedItem.placementOffset.height = newValue
          },
        ),
        in: -maximumOffsetY...maximumOffsetY,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
    } trailing: {
      Text("X: \(fixedItem.placementOffset.width.formatted()), Y: \(fixedItem.placementOffset.height.formatted())")
    }
  }

  private var fixedRotationOption: some View {
    OptionRow("Rotation") {
      SystemSlider(
        value: $fixedItem.rotationDegrees,
        in: 0...360,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
    } trailing: {
      Text("\(fixedItem.rotationDegrees.formatted(.number.precision(.fractionLength(0))))°")
    }
  }

  private var fixedScaleOption: some View {
    OptionRow("Scale") {
      SystemSlider(
        value: $fixedItem.scale,
        in: 0.2...3,
        step: 0.05,
      )
      .compactSliderScale(visibility: .hidden)
    } trailing: {
      Text("\(Double(fixedItem.scale).formatted(.number.precision(.fractionLength(2))))×")
    }
  }

  @ViewBuilder private var sizeOption: some View {
    if fixedItem.preset.capabilities.supportsTextContent {
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
    if fixedItem.preset.capabilities.supportsColorControl {
      OptionRow(fixedItem.preset.colorLabel) {
        ColorPicker("", selection: $colorDraft, supportsOpacity: true)
          .labelsHidden()
          .onChange(of: colorDraft) {
            fixedItem.style.color = colorDraft
          }
      }
    }
  }

  @ViewBuilder private var lineWidthOption: some View {
    if fixedItem.preset.capabilities.supportsLineWidth {
      OptionRow("Stroke Width") {
        SystemSlider(
          value: $lineWidthDraft,
          in: 0.5...16,
          step: 0.5,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          fixedItem.style.lineWidth = lineWidthDraft
        }
      } trailing: {
        Text("\(lineWidthDraft.formatted(.number.precision(.fractionLength(1)))) pt")
      }
    }
  }

  @ViewBuilder private var fontSizeOption: some View {
    if fixedItem.preset.capabilities.supportsFontSize {
      OptionRow("Font Size") {
        SystemSlider(
          value: $fontSizeDraft,
          in: 10...150,
          step: 1,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          fixedItem.style.fontSize = fontSizeDraft
          if fixedItem.preset.capabilities.supportsTextContent {
            refreshTextSize()
          }
        }
      } trailing: {
        Text(fontSizeDraft.formatted(.number.precision(.fractionLength(0))))
      }
    }
  }

  @ViewBuilder private var presetSpecificOption: some View {
    if fixedItem.preset.capabilities.supportsCornerRadius {
      OptionRow("Corner Radius") {
        SystemSlider(
          value: $cornerRadiusDraft,
          in: 0...min(widthDraft, heightDraft) / 2,
          step: 0.5,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          fixedItem.specificOptions = fixedItem.specificOptions.updatingCornerRadius(cornerRadiusDraft)
        }
      } trailing: {
        Text(cornerRadiusDraft.formatted(.number.precision(.fractionLength(1))))
      }
    } else if fixedItem.preset.capabilities.supportsSymbolSelection {
      OptionRow("Symbol") {
        Picker("Symbol", selection: $symbolNameDraft) {
          ForEach(fixedItem.preset.availableSymbols, id: \.self) { name in
            Label(name, systemImage: name).tag(name)
          }
        }
        .labelsHidden()
        .onChange(of: symbolNameDraft) {
          fixedItem.specificOptions = fixedItem.specificOptions.updatingSymbolName(symbolNameDraft)
        }
      }
    } else if fixedItem.preset.capabilities.supportsTextContent {
      OptionRow("Text") {
        OptionTextField(text: $textContentDraft)
          .onSubmit {
            fixedItem.specificOptions = fixedItem.specificOptions.updatingTextContent(textContentDraft)
            refreshTextSize()
          }
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

  private func refreshTextSize() {
    guard fixedItem.preset.capabilities.supportsTextContent else { return }

    let measuredSize = fixedItem.preset.measuredSize(for: fixedItem.style, options: fixedItem.specificOptions)
    if measuredSize != fixedItem.style.size {
      fixedItem.style.size = measuredSize
    }
    widthDraft = measuredSize.width
    heightDraft = measuredSize.height
  }

  private func beginRenaming() {
    nameDraft = fixedItem.customName ?? ""
    isRenaming = true
  }

  private func commitNameChange() {
    let trimmedName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    fixedItem.customName = trimmedName.isEmpty ? nil : trimmedName
    isRenaming = false
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
