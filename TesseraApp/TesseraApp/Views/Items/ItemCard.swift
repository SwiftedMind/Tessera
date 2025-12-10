// By Dennis Müller

import CompactSlider
import SwiftUI

struct ItemCard: View {
  @Binding var item: EditableItem
  @Binding var expandedItemID: EditableItem.ID?
  @State private var weightDraft: Double
  @State private var rotationDraft: ClosedRange<Double>
  @State private var scaleRangeDraft: ClosedRange<Double>
  var onRemove: () -> Void

  init(
    item: Binding<EditableItem>,
    expandedItemID: Binding<EditableItem.ID?>,
    onRemove: @escaping () -> Void,
  ) {
    _item = item
    _expandedItemID = expandedItemID
    self.onRemove = onRemove
    _weightDraft = State(initialValue: item.wrappedValue.weight)
    _rotationDraft = State(initialValue: item.wrappedValue.minimumRotation...item.wrappedValue.maximumRotation)
    _scaleRangeDraft = State(initialValue: item.wrappedValue.minimumScale...item.wrappedValue.maximumScale)
  }

  private var isExpanded: Bool {
    expandedItemID == item.id
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button {
        toggleExpansion()
      } label: {
        HStack(alignment: .center, spacing: 12) {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .foregroundStyle(.secondary)
            .animation(.default, value: isExpanded)
          Text(item.preset.title)
            .font(.headline)
          Spacer()

          Button(role: .destructive, action: onRemove) {
            Image(systemName: "trash")
          }
          .buttonStyle(.plain)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(alignment: .leading, spacing: 12) {
          OptionRow(title: "Weight") {
            VStack(alignment: .leading, spacing: 8) {
              SystemSlider(
                value: $weightDraft,
                in: 0.2...6,
                step: 0.1,
              )
              .compactSliderScale(visibility: .hidden)
              .onSliderCommit {
                item.weight = weightDraft
              }
              HStack {
                Text("Low")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Spacer()
                Text("High")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }

          RangeSliderView(
            title: "Rotation",
            range: $rotationDraft,
            bounds: -180...180,
            step: 1,
            valueLabel: { range in
              let lower = range.lowerBound.formatted(
                FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)),
              )
              let upper = range.upperBound.formatted(
                FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)),
              )
              return Text("\(lower)° – \(upper)°")
            },
            onCommit: {
              item.minimumRotation = rotationDraft.lowerBound
              item.maximumRotation = rotationDraft.upperBound
            },
          )

          OptionRow(
            title: "Scale",
            trailing: {
              Toggle(isOn: $item.usesCustomScaleRange.animation()) {
                Text("Custom")
              }
            },
          ) {
            if item.usesCustomScaleRange {
              RangeSliderView(
                title: "Scale",
                range: $scaleRangeDraft,
                bounds: 0.3...2,
                step: 0.05,
                valueLabel: { range in
                  Text(
                    "\(range.lowerBound, format: .number.precision(.fractionLength(2)))x – \(range.upperBound, format: .number.precision(.fractionLength(2)))x",
                  )
                },
                onCommit: {
                  item.minimumScale = scaleRangeDraft.lowerBound
                  item.maximumScale = scaleRangeDraft.upperBound
                },
              )
              .transition(.opacity)
            } else {
              Text("Uses base scale range")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .transition(.opacity)
      }
    }
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.white.opacity(0.2)),
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .animation(.default, value: expandedItemID)
    .geometryGroup()
    .onChange(of: item.weight) {
      if weightDraft != item.weight {
        weightDraft = item.weight
      }
    }
    .onChange(of: item.minimumRotation) {
      rotationDraft = item.minimumRotation...item.maximumRotation
    }
    .onChange(of: item.maximumRotation) {
      rotationDraft = item.minimumRotation...item.maximumRotation
    }
    .onChange(of: item.minimumScale) {
      scaleRangeDraft = item.minimumScale...item.maximumScale
    }
    .onChange(of: item.maximumScale) {
      scaleRangeDraft = item.minimumScale...item.maximumScale
    }
  }

  private func toggleExpansion() {
    if isExpanded {
      expandedItemID = nil
    } else {
      expandedItemID = item.id
    }
  }
}

#Preview {
  @Previewable @State var item: EditableItem = .demoItems[0]
  @Previewable @State var expandedItemID: EditableItem.ID?

  ItemCard(item: $item, expandedItemID: $expandedItemID) {}
    .padding()
    .frame(height: 600)
}
