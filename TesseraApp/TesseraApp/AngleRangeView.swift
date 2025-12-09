// By Dennis Müller

import SwiftUI

struct AngleRangeView: View {
  @Binding var minimumAngle: Double
  @Binding var maximumAngle: Double
  var onCommit: () -> Void = {}

  var body: some View {
    RangeSliderView(
      title: "Rotation",
      range: angleRangeBinding,
      bounds: -180...180,
      step: 1,
      valueLabel: { range in
        let lower = range.lowerBound.formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)))
        let upper = range.upperBound.formatted(FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)))
        return Text("\(lower)° – \(upper)°")
      },
      onCommit: onCommit,
    )
  }

  private var angleRangeBinding: Binding<ClosedRange<Double>> {
    Binding {
      minimumAngle...maximumAngle
    } set: { newRange in
      minimumAngle = newRange.lowerBound
      maximumAngle = newRange.upperBound
    }
  }
}

#Preview {
  @Previewable @State var minimumAngle = -45.0
  @Previewable @State var maximumAngle = 90.0
  AngleRangeView(minimumAngle: $minimumAngle, maximumAngle: $maximumAngle, onCommit: {})
    .padding()
}
