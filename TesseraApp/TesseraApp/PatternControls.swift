// By Dennis Müller

import CompactSlider
import SwiftUI

struct PatternControls: View {
  @Environment(TesseraEditorModel.self) private var editor
  @State private var seedInput: String = ""
  @State private var isDensitySliderDragging = false

  var body: some View {
    @Bindable var editor = editor

    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 16) {
        BigNumberField(
          title: "Tile Width",
          value: $editor.tesseraSize.width,
          range: 64...512,
          step: 8,
        )

        BigNumberField(
          title: "Tile Height",
          value: $editor.tesseraSize.height,
          range: 64...512,
          step: 8,
        )

        BigNumberField(
          title: "Minimum Spacing",
          value: $editor.minimumSpacing,
          range: 4...64,
          step: 1,
        )

        VStack(alignment: .leading, spacing: 8) {
          Text("Density")
          SystemSlider(
            value: $editor.densityDraft,
            in: 0.1...1,
            step: 0.02
          )
          .compactSliderScale(visibility: .hidden)
          .compactSliderOnChange { configuration in
            handleDensitySliderChange(configuration)
          }
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

        VStack(alignment: .leading, spacing: 8) {
          RangeSliderView(
            title: "Base Scale",
            range: $editor.baseScaleRange,
            bounds: 0.3...1.8,
            step: 0.05,
            valueLabel: { range in
              let lower = Double(range.lowerBound)
                .formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2)))
              let upper = Double(range.upperBound)
                .formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2)))
              return Text("\(lower)× – \(upper)×")
            },
          )
        }

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .center, spacing: 12) {
            Text("Seed")
              .font(.subheadline.weight(.semibold))
            Spacer()
            HStack(spacing: 8) {
              TextField("", text: $seedInput)
                .textFieldStyle(.plain)
                .padding(8)
                .background(.background.secondary, in: .rect(cornerRadius: 10))
                .font(.title3.monospacedDigit().weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .submitLabel(.done)
                .onSubmit(applySeedInput)
                .onChange(of: seedInput) {
                  applySeedIfValid(seedInput)
                }
                .frame(maxWidth: .infinity)

              Button(action: {
                editor.shuffleSeed()
                seedInput = editor.tesseraSeed.description
              }) {
                Label("Randomized", systemImage: "arrow.clockwise")
                  .frame(maxHeight: .infinity)
              }
              .buttonStyle(.borderedProminent)
            }
            .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .padding(16)
      .background(.quaternary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .onAppear {
      seedInput = editor.tesseraSeed.description
    }
    .onChange(of: editor.tesseraSeed) {
      seedInput = editor.tesseraSeed.description
    }
  }

  private func applySeedIfValid(_ newValue: String) {
    guard let parsedSeed = UInt64(newValue.filter(\.isWholeNumber)) else { return }

    editor.tesseraSeed = parsedSeed
  }

  private func handleDensitySliderChange(_ configuration: CompactSliderStyleConfiguration) {
    let isCurrentlyDragging = configuration.focusState.isDragging
    if isDensitySliderDragging == isCurrentlyDragging { return }

    let wasDragging = isDensitySliderDragging
    Task {
      if wasDragging, isCurrentlyDragging == false {
        editor.commitDensityDraft()
      }
      isDensitySliderDragging = isCurrentlyDragging
    }
  }

  private func applySeedInput() {
    applySeedIfValid(seedInput)
  }
}

#Preview {
  PatternControls()
    .environment(TesseraEditorModel())
    .padding()
}
