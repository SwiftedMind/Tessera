// By Dennis Müller

import CompactSlider
import SwiftUI

struct LabeledSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
  var label: String
  @Binding var value: Value
  var range: ClosedRange<Value>
  var step: Value = 1
  var onEditingChanged: ((Bool) -> Void)?

  @State private var isDragging = false

  var body: some View {
    HStack(spacing: 12) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)

      SystemSlider(
        value: $value,
        in: range,
        step: step
      )
      .compactSliderScale(visibility: .hidden)
      .compactSliderOnChange { configuration in
        handleDragChange(configuration)
      }
    }
  }

  private func handleDragChange(_ configuration: CompactSliderStyleConfiguration) {
    let isCurrentlyDragging = configuration.focusState.isDragging
    if isDragging == isCurrentlyDragging { return }

    Task {
      onEditingChanged?(isCurrentlyDragging)
      isDragging = isCurrentlyDragging
    }
  }
}

#Preview {
  @Previewable @State var value = 0.5
  LabeledSlider(label: "Min", value: $value, range: 0...1, step: 0.1)
    .padding()
}
