// By Dennis Müller

import SwiftUI

struct RangeStepper: View {
  @Binding var range: ClosedRange<CGFloat>
  var bounds: ClosedRange<CGFloat>
  var step: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Stepper(value: lowerBinding, in: bounds.lowerBound...range.upperBound, step: step) {
        Text("Minimum \(range.lowerBound, format: .number.precision(.fractionLength(2)))")
          .monospacedDigit()
      }
      Stepper(value: upperBinding, in: range.lowerBound...bounds.upperBound, step: step) {
        Text("Maximum \(range.upperBound, format: .number.precision(.fractionLength(2)))")
          .monospacedDigit()
      }
    }
  }

  private var lowerBinding: Binding<CGFloat> {
    Binding {
      range.lowerBound
    } set: { newValue in
      range = newValue...max(newValue, range.upperBound)
    }
  }

  private var upperBinding: Binding<CGFloat> {
    Binding {
      range.upperBound
    } set: { newValue in
      range = min(range.lowerBound, newValue)...newValue
    }
  }
}

#Preview {
  RangeStepper(range: .constant(0.5...1.2), bounds: 0.3...1.8, step: 0.05)
    .padding()
}
