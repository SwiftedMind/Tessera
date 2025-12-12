// By Dennis Müller

import CompactSlider
import SwiftUI

struct PatternControls: View {
  @Environment(TesseraEditorModel.self) private var editor
  @Binding var isCustomizationEnabled: Bool
  @State private var patternDraft = PatternDraft()
  @State private var didLoadDraft = false

  init(isCustomizationEnabled: Binding<Bool> = .constant(true)) {
    _isCustomizationEnabled = isCustomizationEnabled
  }

  var body: some View {
    @Bindable var editor = editor

    VStack(alignment: .leading, spacing: .large) {
      patternModeRow()
      sizeRow()
      spacingRow()
      customizationToggleRow()
      if isCustomizationEnabled {
        offsetRow()
        densityRow()
        scaleRow()
        maximumItemCountRow()
        seedRow()
      }
    }
    .onAppear {
      loadDraftIfNeeded(from: editor)
    }
    .onChange(of: editor.tesseraSeed) {
      patternDraft.seedText = editor.tesseraSeed.description
    }
    .onChange(of: editor.tesseraSize) {
      patternDraft.tileWidth = editor.tesseraSize.width
      patternDraft.tileHeight = editor.tesseraSize.height
      if editor.patternMode == .tile {
        clampMinimumSpacing(to: maximumSpacing)
      }
    }
    .onChange(of: editor.canvasSize) {
      patternDraft.canvasWidth = editor.canvasSize.width
      patternDraft.canvasHeight = editor.canvasSize.height
      if editor.patternMode == .canvas {
        clampMinimumSpacing(to: maximumSpacing)
      }
    }
    .onChange(of: editor.patternMode) {
      clampMinimumSpacing(to: maximumSpacing)
    }
    .onChange(of: editor.minimumSpacing) {
      patternDraft.minimumSpacing = editor.minimumSpacing
    }
    .onChange(of: editor.maximumItemCount) {
      patternDraft.maximumItemCount = Double(editor.maximumItemCount)
    }
    .onChange(of: editor.density) {
      patternDraft.density = editor.density
    }
    .onChange(of: editor.baseScaleRange) {
      patternDraft.baseScaleRange = editor.baseScaleRange
    }
    .onChange(of: editor.patternOffset) {
      patternDraft.offsetX = editor.patternOffset.width
      patternDraft.offsetY = editor.patternOffset.height
    }
  }

  private func patternModeRow() -> some View {
    @Bindable var editor = editor

    return OptionRow("Pattern Mode") {
      Picker("", selection: $editor.patternMode) {
        Text("Tile")
          .tag(PatternMode.tile)
        Text("Canvas")
          .tag(PatternMode.canvas)
      }
      .labelsHidden()
      .pickerStyle(.segmented)
    }
    .help("Tile repeats a seamless tile infinitely. Canvas fills a finite canvas once and supports fixed items.")
  }

  @ViewBuilder
  private func sizeRow() -> some View {
    switch editor.patternMode {
    case .tile:
      tileSizeRow()
    case .canvas:
      canvasSizeRow()
    }
  }

  private func customizationToggleRow() -> some View {
    OptionRow("Pattern Customization") {
      EmptyView()
    } trailing: {
      Toggle(isOn: $isCustomizationEnabled) {
        Text("Enabled")
      }
    }
  }

  private func tileSizeRow() -> some View {
    OptionRow("Tile Size") {
      Picker("", selection: Binding(
        get: { patternDraft.tileWidth },
        set: { newValue in
          patternDraft.tileWidth = newValue
          patternDraft.tileHeight = newValue
          applyPatternDraft()
        },
      )) {
        ForEach(availableTileSizes, id: \.self) { size in
          Text(FormattedText.tileSize(size))
            .tag(size)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
    }
  }

  private func canvasSizeRow() -> some View {
    OptionRow("Canvas Size") {
      HStack(spacing: .medium) {
        canvasSizeField("Width", value: $patternDraft.canvasWidth)
        canvasSizeField("Height", value: $patternDraft.canvasHeight)
      }
    } trailing: {
      Menu {
        ForEach(CanvasSizePreset.allCases) { preset in
          Button(preset.title) {
            applyCanvasPreset(preset)
          }
        }
      } label: {
        Label("Preset", systemImage: "rectangle.3.offgrid")
      }
    }
  }

  private func canvasSizeField(
    _ title: LocalizedStringKey,
    value: Binding<CGFloat>,
  ) -> some View {
    let doubleValue = Binding<Double>(
      get: { Double(value.wrappedValue) },
      set: { newValue in
        value.wrappedValue = max(8, CGFloat(newValue))
      },
    )

    return VStack(alignment: .leading, spacing: .extraSmall) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField("", value: doubleValue, format: .number.precision(.fractionLength(0)))
        .textFieldStyle(.plain)
        .padding(.small)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
        .font(.title3.monospacedDigit().weight(.medium))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .onChange(of: value.wrappedValue) {
          applyPatternDraft()
        }
    }
  }

  private func offsetRow() -> some View {
    OptionRow("Offset") {
      SystemSlider(
        value: $patternDraft.offsetX,
        in: -maximumOffsetX...maximumOffsetX,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyPatternDraft)

      SystemSlider(
        value: $patternDraft.offsetY,
        in: -maximumOffsetY...maximumOffsetY,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyPatternDraft)
    } trailing: {
      HStack(spacing: .tight) {
        Text("X: \(patternDraft.offsetX.formatted()), Y: \(patternDraft.offsetY.formatted())")
        Button {
          patternDraft.offsetX = 0
          patternDraft.offsetY = 0
          applyPatternDraft()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .disabled(patternDraft.offsetX == 0 && patternDraft.offsetY == 0)
      }
    }
  }

  private func spacingRow() -> some View {
    OptionRow("Minimum Spacing") {
      VStack(alignment: .leading, spacing: .tight) {
        SystemSlider(
          value: $patternDraft.minimumSpacing,
          in: 0...maximumSpacing,
          step: 1,
        )
        .compactSliderScale(visibility: .hidden)
        .onSliderCommit {
          clampMinimumSpacing(to: maximumSpacingForDraft)
          applyPatternDraft()
        }

        HStack {
          Text("0")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Text(maximumSpacingLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    } trailing: {
      Text(patternDraft.minimumSpacing.formatted())
    }
  }

  private func densityRow() -> some View {
    OptionRow("Density") {
      SystemSlider(
        value: $patternDraft.density,
        in: 0.1...1,
        step: 0.02,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyPatternDraft)
      HStack {
        Text("Sparse")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text("Full")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } trailing: {
      Text(patternDraft.density.formatted())
    }
  }

  private func scaleRow() -> some View {
    OptionRow("Size Variability") {
      RangeSliderView(
        range: $patternDraft.baseScaleRange,
        bounds: 0.3...2.0,
        step: 0.1,
      )
      .onSliderCommit(applyPatternDraft)
    } trailing: {
      let lower = Double(patternDraft.baseScaleRange.lowerBound)
        .formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2)))
      let upper = Double(patternDraft.baseScaleRange.upperBound)
        .formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2)))
      Text("\(lower)× – \(upper)×")
    }
  }

  private func maximumItemCountRow() -> some View {
    OptionRow(
      "Maximum Item Count",
      subtitle: "Upper bound on generated items.",
    ) {
      SystemSlider(
        value: $patternDraft.maximumItemCount,
        in: 0...maximumItemCountUpperBound,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(applyPatternDraft)
    } trailing: {
      Text(Int(patternDraft.maximumItemCount).formatted())
    }
  }

  private func seedRow() -> some View {
    OptionRow("Seed") {
      OptionTextField(text: $patternDraft.seedText)
        .onSubmit {
          applyPatternDraft()
        }
    } trailing: {
      Button {
        editor.shuffleSeed()
        patternDraft.seedText = editor.tesseraSeed.description
      } label: {
        Label("Shuffle", systemImage: "shuffle")
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
    }
  }

  private func applyPatternDraft() {
    clampMinimumSpacing(to: maximumSpacingForDraft)
    switch editor.patternMode {
    case .tile:
      editor.tesseraSize = CGSize(width: patternDraft.tileWidth, height: patternDraft.tileHeight)
    case .canvas:
      editor.canvasSize = CGSize(width: patternDraft.canvasWidth, height: patternDraft.canvasHeight)
    }
    editor.minimumSpacing = patternDraft.minimumSpacing
    editor.maximumItemCount = max(0, Int(patternDraft.maximumItemCount.rounded()))
    editor.densityDraft = patternDraft.density
    editor.commitDensityDraft()
    editor.baseScaleRange = patternDraft.baseScaleRange
    editor.patternOffset = CGSize(width: patternDraft.offsetX, height: patternDraft.offsetY)
    if let parsedSeed = UInt64(patternDraft.seedText.filter(\.isWholeNumber)) {
      editor.tesseraSeed = parsedSeed
      patternDraft.seedText = parsedSeed.description
    }
  }

  private func loadDraftIfNeeded(from editor: TesseraEditorModel) {
    guard didLoadDraft == false else { return }

    patternDraft = PatternDraft(
      tileWidth: editor.tesseraSize.width,
      tileHeight: editor.tesseraSize.height,
      canvasWidth: editor.canvasSize.width,
      canvasHeight: editor.canvasSize.height,
      minimumSpacing: editor.minimumSpacing,
      maximumItemCount: Double(editor.maximumItemCount),
      density: editor.density,
      baseScaleRange: editor.baseScaleRange,
      offsetX: editor.patternOffset.width,
      offsetY: editor.patternOffset.height,
      seedText: editor.tesseraSeed.description,
    )
    clampMinimumSpacing(to: maximumSpacing)
    didLoadDraft = true
  }
}

private extension PatternControls {
  var maximumSpacing: CGFloat {
    min(editor.activePatternSize.width, editor.activePatternSize.height) / 2
  }

  var maximumSpacingForDraft: CGFloat {
    min(activeDraftSize.width, activeDraftSize.height) / 2
  }

  var maximumOffsetX: CGFloat {
    activeDraftSize.width
  }

  var maximumOffsetY: CGFloat {
    activeDraftSize.height
  }

  var maximumSpacingLabel: String {
    Double(maximumSpacing).formatted(.number.precision(.fractionLength(0)))
  }

  func clampMinimumSpacing(to maximum: CGFloat) {
    patternDraft.minimumSpacing = min(max(patternDraft.minimumSpacing, 0), maximum)
  }

  var activeDraftSize: CGSize {
    switch editor.patternMode {
    case .tile:
      CGSize(width: patternDraft.tileWidth, height: patternDraft.tileHeight)
    case .canvas:
      CGSize(width: patternDraft.canvasWidth, height: patternDraft.canvasHeight)
    }
  }

  var availableTileSizes: [CGFloat] {
    [128, 256, 512, 1024]
  }

  var maximumItemCountUpperBound: Double {
    5000
  }

  enum CanvasSizePreset: String, CaseIterable, Identifiable {
    case square1024
    case fullHD1080p
    case ultraHD4K
    case iPhonePortrait
    case iPhoneLandscape

    var id: String { rawValue }

    var title: LocalizedStringKey {
      switch self {
      case .square1024:
        "Square (1024 px)"
      case .fullHD1080p:
        "1080p (1920 × 1080)"
      case .ultraHD4K:
        "4K (3840 × 2160)"
      case .iPhonePortrait:
        "iPhone Portrait (1170 × 2532)"
      case .iPhoneLandscape:
        "iPhone Landscape (2532 × 1170)"
      }
    }

    var size: CGSize {
      switch self {
      case .square1024:
        CGSize(width: 1024, height: 1024)
      case .fullHD1080p:
        CGSize(width: 1920, height: 1080)
      case .ultraHD4K:
        CGSize(width: 3840, height: 2160)
      case .iPhonePortrait:
        CGSize(width: 1170, height: 2532)
      case .iPhoneLandscape:
        CGSize(width: 2532, height: 1170)
      }
    }
  }

  func applyCanvasPreset(_ preset: CanvasSizePreset) {
    patternDraft.canvasWidth = preset.size.width
    patternDraft.canvasHeight = preset.size.height
    applyPatternDraft()
  }

  enum FormattedText {
    static func tileSize(_ value: CGFloat) -> String {
      "\(Int(value)) px"
    }
  }
}

#Preview {
  @Previewable @Environment(TesseraEditorModel.self) var editor

  PatternControls()
    .environment(editor)
    .padding(.large)
}

private struct PatternDraft {
  var tileWidth: CGFloat = 256
  var tileHeight: CGFloat = 256
  var canvasWidth: CGFloat = 1024
  var canvasHeight: CGFloat = 1024
  var minimumSpacing: CGFloat = 10
  var maximumItemCount: Double = 512
  var density: Double = 0.8
  var baseScaleRange: ClosedRange<Double> = 0.5...1.2
  var offsetX: CGFloat = 0
  var offsetY: CGFloat = 0
  var seedText: String = "0"
}
