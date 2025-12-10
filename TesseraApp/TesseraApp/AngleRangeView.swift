// By Dennis Müller

import SwiftUI

struct AngleRangeView: View {
  @Binding var angleRange: ClosedRange<Double>
  var onCommit: () -> Void = {}

  var body: some View {
    RangeSliderView(
      title: "Rotation",
      range: $angleRange,
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
}

#Preview {
  @Previewable @State var angleRange = -45.0...90.0
  AngleRangeView(angleRange: $angleRange, onCommit: {})
    .padding()
}
