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
  }

  private func tileSizeRow() -> some View {
    OptionRow("Tile Size") {
      HStack(spacing: .medium) {
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
        Label("Randomized", systemImage: "arrow.clockwise")
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

  var maximumSpacingLabel: String {
    Double(maximumSpacing).formatted(.number.precision(.fractionLength(0)))
  }

  func clampMinimumSpacing(to maximum: CGFloat) {
    patternDraft.minimumSpacing = min(max(patternDraft.minimumSpacing, 0), maximum)
  }
}

#Preview {
  PatternControls()
    .environment(TesseraEditorModel())
    .padding(.large)
}

private struct PatternDraft {
  var tileWidth: CGFloat = 256
  var tileHeight: CGFloat = 256
  var minimumSpacing: CGFloat = 10
  var density: Double = 0.8
  var baseScaleRange: ClosedRange<Double> = 0.5...1.2
  var seedText: String = "0"
}
