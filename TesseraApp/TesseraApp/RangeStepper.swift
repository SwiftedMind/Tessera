// By Dennis Müller

import SwiftUI

struct RangeStepper: View {
  @Binding var range: ClosedRange<CGFloat>
  var bounds: ClosedRange<CGFloat>
  var step: CGFloat
  @State private var lowerValue: CGFloat
  @State private var upperValue: CGFloat

  init(range: Binding<ClosedRange<CGFloat>>, bounds: ClosedRange<CGFloat>, step: CGFloat) {
    _range = range
    self.bounds = bounds
    self.step = step
    let clampedRange = RangeStepper.clamp(range.wrappedValue, to: bounds)
    _lowerValue = State(initialValue: clampedRange.lowerBound)
    _upperValue = State(initialValue: clampedRange.upperBound)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Stepper(value: $lowerValue, in: bounds.lowerBound...upperValue, step: step) {
        Text("Minimum \(lowerValue, format: .number.precision(.fractionLength(2)))")
          .monospacedDigit()
      }
      Stepper(value: $upperValue, in: lowerValue...bounds.upperBound, step: step) {
        Text("Maximum \(upperValue, format: .number.precision(.fractionLength(2)))")
          .monospacedDigit()
      }
    }
    .onAppear {
      synchronizeStateWithRange()
    }
    .onChange(of: lowerValue) {
      applyStateValuesToRange()
    }
    .onChange(of: upperValue) {
      applyStateValuesToRange()
    }
    .onChange(of: range) {
      synchronizeStateWithRange()
    }
  }

  private func applyStateValuesToRange() {
    let updatedRange = RangeStepper.clamp(lowerValue...upperValue, to: bounds)
    if range != updatedRange {
      range = updatedRange
    }
    if lowerValue != updatedRange.lowerBound {
      lowerValue = updatedRange.lowerBound
    }
    if upperValue != updatedRange.upperBound {
      upperValue = updatedRange.upperBound
    }
  }

  private func synchronizeStateWithRange() {
    let clampedRange = RangeStepper.clamp(range, to: bounds)
    if range != clampedRange {
      range = clampedRange
    }
    if lowerValue != clampedRange.lowerBound {
      lowerValue = clampedRange.lowerBound
    }
    if upperValue != clampedRange.upperBound {
      upperValue = clampedRange.upperBound
    }
  }

  private static func clamp(_ range: ClosedRange<CGFloat>, to bounds: ClosedRange<CGFloat>) -> ClosedRange<CGFloat> {
    let lowerBound = min(max(range.lowerBound, bounds.lowerBound), bounds.upperBound)
    let upperBound = min(max(range.upperBound, lowerBound), bounds.upperBound)
    return lowerBound...upperBound
  }
}

#Preview {
  RangeStepper(range: .constant(0.5...1.2), bounds: 0.3...1.8, step: 0.05)
    .padding()
}
