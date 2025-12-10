// By Dennis Müller

import CompactSlider
import SwiftUI

struct LabeledSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
  var label: String
  @Binding var value: Value
  var range: ClosedRange<Value>
  var step: Value = 1
  var onEditingChanged: ((Bool) -> Void)?

  var body: some View {
    HStack(spacing: .medium) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)

      SystemSlider(
        value: $value,
        in: range,
        step: step,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit {
        onEditingChanged?(false)
      }
    }
  }
}

#Preview {
  @Previewable @State var value = 0.5
  LabeledSlider(label: "Min", value: $value, range: 0...1, step: 0.1)
    .padding(.large)
}
