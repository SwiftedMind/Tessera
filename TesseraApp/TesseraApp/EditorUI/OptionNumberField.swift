// By Dennis Müller

import SwiftUI

struct OptionNumberField<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
  var title: LocalizedStringKey?
  @Binding var value: Value
  var range: ClosedRange<Value>
  var format: FloatingPointFormatStyle<Value> = .init()
    .precision(.fractionLength(0))
  var onCommit: () -> Void = {}

  @State private var draft: Value

  init(
    title: LocalizedStringKey? = nil,
    value: Binding<Value>,
    range: ClosedRange<Value>,
    format: FloatingPointFormatStyle<Value> = FloatingPointFormatStyle<Value>()
      .precision(.fractionLength(0)),
    onCommit: @escaping () -> Void = {},
  ) {
    self.title = title
    _value = value
    self.range = range
    self.format = format
    self.onCommit = onCommit
    _draft = State(initialValue: Self.clamp(value.wrappedValue, to: range))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .extraSmall) {
      if let title {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      TextField("", value: $draft, format: format)
        .textFieldStyle(.plain)
        .padding(.small)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
        .onSubmit(commitDraft)
        .onChange(of: draft) { _, newValue in
          let clamped = Self.clamp(newValue, to: range)
          if clamped != newValue {
            draft = clamped
          }
          if value != clamped {
            value = clamped
          }
        }
        .onChange(of: value) { _, newValue in
          let clamped = Self.clamp(newValue, to: range)
          if draft != clamped {
            draft = clamped
          }
        }
    }
  }

  private func commitDraft() {
    let clamped = Self.clamp(draft, to: range)
    if draft != clamped {
      draft = clamped
    }
    if value != clamped {
      value = clamped
    }
    onCommit()
  }

  private static func clamp(_ value: Value, to range: ClosedRange<Value>) -> Value {
    min(max(value, range.lowerBound), range.upperBound)
  }
}
