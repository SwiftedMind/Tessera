// By Dennis Müller

import CompactSlider
import SwiftUI

struct RangeSliderView<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
  var title: String
  @Binding var range: ClosedRange<Value>
  var bounds: ClosedRange<Value>
  var step: Value
  var valueLabel: (ClosedRange<Value>) -> Text
  var onCommit: () -> Void = {}

  @State private var isDragging = false
  @State private var lowerValue: Value
  @State private var upperValue: Value

  init(
    title: String,
    range: Binding<ClosedRange<Value>>,
    bounds: ClosedRange<Value>,
    step: Value,
    valueLabel: @escaping (ClosedRange<Value>) -> Text,
    onCommit: @escaping () -> Void = {}
  ) {
    self.title = title
    _range = range
    self.bounds = bounds
    self.step = step
    self.valueLabel = valueLabel
    self.onCommit = onCommit

    let clampedRange = RangeSliderView.clamp(range.wrappedValue, to: bounds)
    _lowerValue = State(initialValue: clampedRange.lowerBound)
    _upperValue = State(initialValue: clampedRange.upperBound)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
        Spacer()
        valueLabel(currentRange)
          .foregroundStyle(.secondary)
      }

      SystemSlider(
        from: $lowerValue,
        to: $upperValue,
        in: bounds,
        step: step
      )
      .compactSliderScale(visibility: .hidden)
      .compactSliderOnChange { configuration in
        handleSliderChange(configuration)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
      synchronizeStateWithRange()
    }
    .onChange(of: lowerValue) {
      applyStateValuesToRange()
    }
    .onChange(of: upperValue) {
      applyStateValuesToRange()
    }
    .onChange(of: range) {
      synchronizeStateWithRange()
    }
  }

  private var currentRange: ClosedRange<Value> {
    RangeSliderView.clamp(range, to: bounds)
  }

  private func handleSliderChange(_ configuration: CompactSliderStyleConfiguration) {
    let isCurrentlyDragging = configuration.focusState.isDragging
    if isDragging == isCurrentlyDragging { return }

    let wasDragging = isDragging
    Task { // Needed to avoid Modifying state during view update, this will cause undefined behavior errors
      if wasDragging, isCurrentlyDragging == false {
        print("NOW")
        onCommit()
      }
      isDragging = isCurrentlyDragging
    }
  }

  private func applyStateValuesToRange() {
    let updatedRange = RangeSliderView.clamp(lowerValue...upperValue, to: bounds)
    if range != updatedRange {
      range = updatedRange
    }
    if lowerValue != updatedRange.lowerBound {
      lowerValue = updatedRange.lowerBound
    }
    if upperValue != updatedRange.upperBound {
      upperValue = updatedRange.upperBound
    }
  }

  private func synchronizeStateWithRange() {
    let clampedRange = RangeSliderView.clamp(range, to: bounds)
    if range != clampedRange {
      range = clampedRange
    }
    if lowerValue != clampedRange.lowerBound {
      lowerValue = clampedRange.lowerBound
    }
    if upperValue != clampedRange.upperBound {
      upperValue = clampedRange.upperBound
    }
  }

  private static func clamp(_ range: ClosedRange<Value>, to bounds: ClosedRange<Value>) -> ClosedRange<Value> {
    let lowerBound = min(max(range.lowerBound, bounds.lowerBound), bounds.upperBound)
    let upperBound = min(max(range.upperBound, lowerBound), bounds.upperBound)
    return lowerBound...upperBound
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
