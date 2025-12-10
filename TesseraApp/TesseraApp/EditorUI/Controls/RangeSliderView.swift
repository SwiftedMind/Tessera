// By Dennis Müller

import CompactSlider
import SwiftUI

struct RangeSliderView: View {
  var title: String
  @Binding var range: ClosedRange<Double>
  var bounds: ClosedRange<Double>
  var step: Double
  var valueLabel: (ClosedRange<Double>) -> Text
  var onCommit: () -> Void = {}

  init(
    title: String,
    range: Binding<ClosedRange<Double>>,
    bounds: ClosedRange<Double>,
    step: Double,
    valueLabel: @escaping (ClosedRange<Double>) -> Text,
    onCommit: @escaping () -> Void = {},
  ) {
    self.title = title
    _range = range
    self.bounds = bounds
    self.step = step
    self.valueLabel = valueLabel
    self.onCommit = onCommit
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .mediumTight) {
      HStack {
        Text(title)
        Spacer()
        valueLabel(currentRange)
          .foregroundStyle(.secondary)
      }

      SystemSlider(
        from: lowerBoundBinding,
        to: upperBoundBinding,
        in: bounds,
        step: step,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(onCommit)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onChange(of: range) {
      clampRangeIfNeeded()
    }
    .onAppear {
      clampRangeIfNeeded()
    }
  }

  private var currentRange: ClosedRange<Double> {
    clampedRange
  }

  private var clampedRange: ClosedRange<Double> {
    RangeSliderView.clamp(range, to: bounds)
  }

  private var lowerBoundBinding: Binding<Double> {
    Binding(
      get: { clampedRange.lowerBound },
      set: { newLowerBound in
        let updatedRange = Self.clamp(newLowerBound...range.upperBound, to: bounds)
        range = updatedRange
      },
    )
  }

  private var upperBoundBinding: Binding<Double> {
    Binding(
      get: { clampedRange.upperBound },
      set: { newUpperBound in
        let updatedRange = Self.clamp(range.lowerBound...newUpperBound, to: bounds)
        range = updatedRange
      },
    )
  }

  private func clampRangeIfNeeded() {
    let clampedRangeCandidate = clampedRange
    if range != clampedRangeCandidate {
      range = clampedRangeCandidate
    }
  }

  private static func clamp(_ range: ClosedRange<Double>, to bounds: ClosedRange<Double>) -> ClosedRange<Double> {
    let lowerBound = min(max(range.lowerBound, bounds.lowerBound), bounds.upperBound)
    let upperBound = min(max(range.upperBound, lowerBound), bounds.upperBound)
    return lowerBound...upperBound
  }
}

#Preview {
  @Previewable @State var range = 0.5...1.2
  RangeSliderView(
    title: "Base Scale",
    range: $range,
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
  .padding(.large)
}
