// By Dennis Müller

import SwiftUI

struct ScaleRangeView: View {
  @Binding var minScale: CGFloat
  @Binding var maxScale: CGFloat
  var onCommit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Scale")
        Spacer()
        Text(
          "\(minScale, format: .number.precision(.fractionLength(2)))x – \(maxScale, format: .number.precision(.fractionLength(2)))x",
        )
        .foregroundStyle(.secondary)
      }
      LabeledSlider(label: "Min", value: $minScale, range: 0.3...2, step: 0.05) { isEditing in
        if isEditing == false { commitBounds() }
      }
      LabeledSlider(label: "Max", value: $maxScale, range: 0.3...2, step: 0.05) { isEditing in
        if isEditing == false { commitBounds() }
      }
    }
  }

  private func commitBounds() {
    let clampedMin = min(max(minScale, 0.3), 2)
    let clampedMax = min(max(maxScale, 0.3), 2)
    if clampedMin > clampedMax {
      minScale = clampedMax
      maxScale = clampedMax
    } else {
      minScale = clampedMin
      maxScale = clampedMax
    }
    onCommit()
  }
}

#Preview {
  ScaleRangeView(minScale: .constant(0.7), maxScale: .constant(1.3), onCommit: {})
    .padding()
}
