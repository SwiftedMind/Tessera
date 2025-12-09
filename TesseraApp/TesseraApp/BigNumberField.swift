// By Dennis Müller

import SwiftUI

struct BigNumberField: View {
  var title: String
  @Binding var value: CGFloat
  var range: ClosedRange<CGFloat>
  var step: CGFloat

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Text(title)
      Spacer()
      HStack(spacing: 8) {
        TextField("", value: valueBinding, format: .number.precision(.fractionLength(0)))
          .textFieldStyle(.plain)
          .padding(8)
          .background(.background.secondary, in: .rect(cornerRadius: 10))
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var rangeDouble: ClosedRange<Double> {
    Double(range.lowerBound)...Double(range.upperBound)
  }

  private var valueBinding: Binding<Double> {
    Binding {
      min(max(Double(value), rangeDouble.lowerBound), rangeDouble.upperBound)
    } set: { newValue in
      let clamped = min(max(newValue, rangeDouble.lowerBound), rangeDouble.upperBound)
      value = CGFloat(clamped)
    }
  }
}

#Preview {
  BigNumberField(title: "Tile Width", value: .constant(256), range: 64...512, step: 8)
    .padding()
}
