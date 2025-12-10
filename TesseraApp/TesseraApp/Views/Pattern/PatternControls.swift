// By Dennis Müller

import CompactSlider
import SwiftUI

struct PatternControls: View {
  @Environment(TesseraEditorModel.self) private var editor
  @State private var patternDraft = PatternDraft()
  @State private var didLoadDraft = false

  var body: some View {
    @Bindable var editor = editor

    VStack(alignment: .leading, spacing: 16) {
      tileSizeRow()
      spacingRow()
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
  }

  private func tileSizeRow() -> some View {
    OptionRow(title: "Tile Size") {
      HStack(spacing: 12) {
        OptionNumberField(
          title: "Width",
          value: $patternDraft.tileWidth,
          range: 64...512,
          onCommit: applyPatternDraft,
        )
        OptionNumberField(
          title: "Height",
          value: $patternDraft.tileHeight,
          range: 64...512,
          onCommit: applyPatternDraft,
        )
      }
    }
  }

  private func spacingRow() -> some View {
    OptionRow(title: "Minimum Spacing") {
      OptionNumberField(
        value: $patternDraft.minimumSpacing,
        range: 4...64,
        onCommit: applyPatternDraft,
      )
    }
  }

  private func densityRow() -> some View {
    OptionRow(title: "Density") {
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
    }
  }

  private func scaleRow() -> some View {
    OptionRow(title: "Tile Scaling") {
      RangeSliderView(
        title: "Scale Range",
        range: $patternDraft.baseScaleRange,
        bounds: 0.3...1.8,
        step: 0.05,
        valueLabel: { range in
          let lower = Double(range.lowerBound)
            .formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2)))
          let upper = Double(range.upperBound)
            .formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2)))
          return Text("\(lower)× – \(upper)×")
        },
        onCommit: applyPatternDraft,
      )
    }
  }

  private func seedRow() -> some View {
    OptionRow(
      title: "Seed",
      trailing: {
        Button {
          editor.shuffleSeed()
          patternDraft.seedText = editor.tesseraSeed.description
        } label: {
          Label("Randomized", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.plain)
      },
    ) {
      OptionTextField(text: $patternDraft.seedText, onCommit: applyPatternDraft)
    }
  }

  private func applyPatternDraft() {
    editor.tesseraSize = CGSize(width: patternDraft.tileWidth, height: patternDraft.tileHeight)
    editor.minimumSpacing = patternDraft.minimumSpacing
    editor.densityDraft = patternDraft.density
    editor.commitDensityDraft()
    editor.baseScaleRange = patternDraft.baseScaleRange
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
      seedText: editor.tesseraSeed.description,
    )
    didLoadDraft = true
  }
}

#Preview {
  PatternControls()
    .environment(TesseraEditorModel())
    .padding()
}

private struct PatternDraft {
  var tileWidth: CGFloat = 256
  var tileHeight: CGFloat = 256
  var minimumSpacing: CGFloat = 10
  var density: Double = 0.8
  var baseScaleRange: ClosedRange<Double> = 0.5...1.2
  var seedText: String = "0"
}
