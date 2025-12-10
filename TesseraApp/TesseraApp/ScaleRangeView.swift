// By Dennis Müller

import SwiftUI

struct ScaleRangeView: View {
  @Binding var scaleRange: ClosedRange<Double>
  var onCommit: () -> Void

  private let bounds: ClosedRange<Double> = 0.3...2
  private let step: CGFloat = 0.05

  var body: some View {
    RangeSliderView(
      title: "Scale",
      range: $scaleRange,
      bounds: bounds,
      step: step,
      valueLabel: { range in
        Text(
          "\(range.lowerBound, format: .number.precision(.fractionLength(2)))x – \(range.upperBound, format: .number.precision(.fractionLength(2)))x"
        )
      },
      onCommit: onCommit
    )
  }
}

#Preview {
  @Previewable @State var scaleRange: ClosedRange<Double> = 0.7...1.3
  ScaleRangeView(scaleRange: $scaleRange, onCommit: {})
    .padding()
}
