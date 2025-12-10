// By Dennis Müller

import SwiftUI

struct BigNumberField: View {
  var title: String
  @Binding var value: CGFloat
  var range: ClosedRange<CGFloat>
  var step: CGFloat
  @State private var displayedValue: Double

  init(title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) {
    self.title = title
    _value = value
    self.range = range
    self.step = step
    let initialValue = BigNumberField.clamp(Double(value.wrappedValue), to: range)
    _displayedValue = State(initialValue: initialValue)
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Text(title)
      Spacer()
      HStack(spacing: 8) {
        TextField("", value: $displayedValue, format: .number.precision(.fractionLength(0)))
          .textFieldStyle(.plain)
          .padding(8)
          .background(.background.secondary, in: .rect(cornerRadius: 10))
          .frame(maxWidth: .infinity)
      }
    }
    .onChange(of: displayedValue) {
      let clampedValue = BigNumberField.clamp(displayedValue, to: range)
      if clampedValue != displayedValue {
        displayedValue = clampedValue
      }
      value = CGFloat(clampedValue)
    }
    .onChange(of: value) {
      let clampedValue = BigNumberField.clamp(Double(value), to: range)
      if clampedValue != displayedValue {
        displayedValue = clampedValue
      }
    }
  }

  private static func clamp(_ value: Double, to range: ClosedRange<CGFloat>) -> Double {
    let lowerBound = Double(range.lowerBound)
    let upperBound = Double(range.upperBound)
    return min(max(value, lowerBound), upperBound)
  }
}

#Preview {
  BigNumberField(title: "Tile Width", value: .constant(256), range: 64...512, step: 8)
    .padding()
}
