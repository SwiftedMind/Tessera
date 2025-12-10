// By Dennis Müller

import CompactSlider
import SwiftUI

struct RangeSliderView: View {
  @Binding var range: ClosedRange<Double>
  var bounds: ClosedRange<Double>
  var step: Double

  init(
    range: Binding<ClosedRange<Double>>,
    bounds: ClosedRange<Double>,
    step: Double,
  ) {
    _range = range
    self.bounds = bounds
    self.step = step
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .mediumTight) {
      SystemSlider(
        from: lowerBoundBinding,
        to: upperBoundBinding,
        in: bounds,
        step: step,
      )
      .compactSliderScale(visibility: .hidden)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onChange(of: range) {
      clampRangeIfNeeded()
    }
    .onAppear {
      clampRangeIfNeeded()
    }
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
    range: $range,
    bounds: 0.3...1.8,
    step: 0.05,
  )
  .padding(.large)
}
