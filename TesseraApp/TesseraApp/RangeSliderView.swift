// By Dennis Müller

import SwiftUI

struct RangeSliderView<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
  var title: String
  @Binding var range: ClosedRange<Value>
  var bounds: ClosedRange<Value>
  var step: Value
  var valueLabel: (ClosedRange<Value>) -> Text
  var onCommit: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
        Spacer()
        valueLabel(clampedRange)
          .foregroundStyle(.secondary)
      }
      VStack(spacing: 8) {
        LabeledSlider(
          label: "Min",
          value: lowerBinding,
          range: bounds.lowerBound...clampedRange.upperBound,
          step: step,
        ) { isEditing in
          if isEditing == false { onCommit() }
        }
        LabeledSlider(
          label: "Max",
          value: upperBinding,
          range: clampedRange.lowerBound...bounds.upperBound,
          step: step,
        ) { isEditing in
          if isEditing == false { onCommit() }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var clampedRange: ClosedRange<Value> {
    let lowerBound = min(max(range.lowerBound, bounds.lowerBound), bounds.upperBound)
    let upperBound = min(max(range.upperBound, lowerBound), bounds.upperBound)
    return lowerBound...upperBound
  }

  private var lowerBinding: Binding<Value> {
    Binding {
      clampedRange.lowerBound
    } set: { newValue in
      let clampedLower = min(max(newValue, bounds.lowerBound), bounds.upperBound)
      let updatedUpper = max(clampedLower, min(range.upperBound, bounds.upperBound))
      range = clampedLower...updatedUpper
    }
  }

  private var upperBinding: Binding<Value> {
    Binding {
      clampedRange.upperBound
    } set: { newValue in
      let clampedUpper = min(max(newValue, bounds.lowerBound), bounds.upperBound)
      let updatedLower = min(max(range.lowerBound, bounds.lowerBound), clampedUpper)
      range = updatedLower...clampedUpper
    }
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
  .padding()
}
