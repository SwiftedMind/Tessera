// By Dennis Müller

import CompactSlider
import SwiftUI

struct PatternControls: View {
  @Environment(TesseraEditorModel.self) private var editor
  @State private var patternDraft = PatternDraft()
  @State private var didLoadDraft = false

  var body: some View {
    @Bindable var editor = editor

    VStack(alignment: .leading, spacing: .large) {
      tileSizeRow()
      spacingRow()
      offsetRow()
      densityRow()
      scaleRow()
      seedRow()
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
      clampMinimumSpacing(to: maximumSpacing)
    }
    .onChange(of: editor.minimumSpacing) {
      patternDraft.minimumSpacing = editor.minimumSpacing
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
    OptionRow("Scale Range") {
      RangeSliderView(
        range: $patternDraft.baseScaleRange,
        bounds: 0.3...1.8,
        step: 0.05,
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

  private func seedRow() -> some View {
    OptionRow {
      OptionTextField(text: $patternDraft.seedText, onCommit: applyPatternDraft)
    } trailing: {
      Button {
        editor.shuffleSeed()
        patternDraft.seedText = editor.tesseraSeed.description
      } label: {
        Label("Shuffle", systemImage: "shuffle")
      }
      .buttonStyle(.plain)
    }
  }

  private func applyPatternDraft() {
    clampMinimumSpacing(to: maximumSpacingForDraft)
    editor.tesseraSize = CGSize(width: patternDraft.tileWidth, height: patternDraft.tileHeight)
    editor.minimumSpacing = patternDraft.minimumSpacing
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
      minimumSpacing: editor.minimumSpacing,
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
    min(editor.tesseraSize.width, editor.tesseraSize.height) / 2
  }

  var maximumSpacingForDraft: CGFloat {
    min(patternDraft.tileWidth, patternDraft.tileHeight) / 2
  }

  var maximumOffsetX: CGFloat {
    patternDraft.tileWidth
  }

  var maximumOffsetY: CGFloat {
    patternDraft.tileHeight
  }

  var maximumSpacingLabel: String {
    Double(maximumSpacing).formatted(.number.precision(.fractionLength(0)))
  }

  func clampMinimumSpacing(to maximum: CGFloat) {
    patternDraft.minimumSpacing = min(max(patternDraft.minimumSpacing, 0), maximum)
  }

  var availableTileSizes: [CGFloat] {
    [16, 32, 64, 128, 256, 512, 1024]
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
  var minimumSpacing: CGFloat = 10
  var density: Double = 0.8
  var baseScaleRange: ClosedRange<Double> = 0.5...1.2
  var offsetX: CGFloat = 0
  var offsetY: CGFloat = 0
  var seedText: String = "0"
}
