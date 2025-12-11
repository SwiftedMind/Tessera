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
    _widthDraft = State(initialValue: item.wrappedValue.style.size.width)
    _heightDraft = State(initialValue: item.wrappedValue.style.size.height)
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
    max(8, editor.tesseraSize.width)
  }

  private var maximumHeight: Double {
    max(8, editor.tesseraSize.height)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .medium) {
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
        .transition(.opacity)
      }
    }
    .padding(.mediumRelaxed)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.white.opacity(0.2)),
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .animation(.default, value: expandedItemID)
    .animation(.default, value: item.usesCustomScaleRange)
    .geometryGroup()
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
    }
    .onChange(of: editor.tesseraSize) {
      widthDraft = min(widthDraft, editor.tesseraSize.width)
      heightDraft = min(heightDraft, editor.tesseraSize.height)
      applySizeDraft()
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
        Text(item.preset.title)
          .font(.headline)
        Spacer()

        Button(role: .destructive, action: onRemove) {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
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

  @ViewBuilder private var colorOption: some View {
    OptionRow(item.preset.colorLabel) {
      ColorPicker("", selection: $colorDraft, supportsOpacity: true)
        .labelsHidden()
        .onChange(of: colorDraft) {
          item.style.color = colorDraft
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
          in: 10...64,
          step: 1,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          item.style.fontSize = fontSizeDraft
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
    } else if item.preset.capabilities.supportsTextContent {
      OptionRow("Text") {
        OptionTextField(text: $textContentDraft)
          .onSubmit {
            item.specificOptions = item.specificOptions.updatingTextContent(textContentDraft)
          }
          .onChange(of: textContentDraft) {
            item.specificOptions = item.specificOptions.updatingTextContent(textContentDraft)
          }
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
      OptionRow("Scale Range") {
        RangeSliderView(
          range: $scaleRangeDraft,
          bounds: 0.3...2,
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
