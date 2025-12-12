// By Dennis Müller

import CompactSlider
import SwiftUI

struct InspectorSizeOptionRow: View {
  var supportsTextContent: Bool
  @Binding var widthDraft: Double
  @Binding var heightDraft: Double
  var maximumWidth: Double
  var maximumHeight: Double
  var onCommit: () -> Void

  var body: some View {
    if supportsTextContent {
      OptionRow("Size") {
        EmptyView()
      } trailing: {
        Text("Auto (\(widthDraft.formatted()) × \(heightDraft.formatted()))")
      }
    } else {
      OptionRow("Size") {
        HStack(spacing: .medium) {
          VStack(alignment: .leading, spacing: .extraSmall) {
            Text("Width")
              .font(.caption)
              .foregroundStyle(.secondary)
            SystemSlider(
              value: $widthDraft,
              in: 8...maximumWidth,
              step: 1,
            )
            .compactSliderScale(visibility: .hidden)
            .onSliderCommit(onCommit)
          }
          VStack(alignment: .leading, spacing: .extraSmall) {
            Text("Height")
              .font(.caption)
              .foregroundStyle(.secondary)
            SystemSlider(
              value: $heightDraft,
              in: 8...maximumHeight,
              step: 1,
            )
            .compactSliderScale(visibility: .hidden)
            .onSliderCommit(onCommit)
          }
        }
      } trailing: {
        Text("\(widthDraft.formatted()) × \(heightDraft.formatted())")
      }
    }
  }
}

struct InspectorColorOptionRow: View {
  var label: LocalizedStringKey
  @Binding var color: Color
  var onChange: (Color) -> Void

  var body: some View {
    OptionRow(label) {
      ColorPicker("", selection: $color, supportsOpacity: true)
        .labelsHidden()
        .onChange(of: color) {
          onChange(color)
        }
    }
  }
}

struct InspectorStrokeWidthOptionRow: View {
  @Binding var strokeWidth: Double
  var onCommit: () -> Void

  var body: some View {
    OptionRow("Stroke Width") {
      SystemSlider(
        value: $strokeWidth,
        in: 0.5...16,
        step: 0.5,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(onCommit)
    } trailing: {
      Text("\(strokeWidth.formatted(.number.precision(.fractionLength(1)))) pt")
    }
  }
}

struct InspectorFontSizeOptionRow: View {
  @Binding var fontSize: Double
  var onCommit: () -> Void

  var body: some View {
    OptionRow("Font Size") {
      SystemSlider(
        value: $fontSize,
        in: 10...150,
        step: 1,
      )
      .compactSliderScale(visibility: .hidden)
      .onSliderCommit(onCommit)
    } trailing: {
      Text(fontSize.formatted(.number.precision(.fractionLength(0))))
    }
  }
}
