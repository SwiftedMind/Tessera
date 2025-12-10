// By Dennis Müller

import CompactSlider
import SwiftUI

struct ItemCard: View {
  @Binding var item: EditableItem
  @Binding var expandedItemID: EditableItem.ID?
  @State private var weightDraft: Double
  @State private var rotationDraft: ClosedRange<Double>
  @State private var scaleRangeDraft: ClosedRange<Double>
  @State private var isWeightSliderDragging = false
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
          item.preset.preview
            .frame(width: 15, height: 15)
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
          VStack(alignment: .leading, spacing: 8) {
            Text("Weight")
            SystemSlider(
              value: $weightDraft,
              in: 0.2...6,
              step: 0.1
            )
            .compactSliderScale(visibility: .hidden)
            .compactSliderOnChange { configuration in
              handleWeightSliderChange(configuration)
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

          VStack(alignment: .leading, spacing: 8) {
            AngleRangeView(
              angleRange: $rotationDraft,
              onCommit: {
                item.minimumRotation = rotationDraft.lowerBound
                item.maximumRotation = rotationDraft.upperBound
              },
            )
          }

          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Override Scale Range")
              Toggle(isOn: $item.usesCustomScaleRange.animation()) {
                Text("Custom")
              }
            }
            if item.usesCustomScaleRange {
              ScaleRangeView(
                scaleRange: $scaleRangeDraft,
                onCommit: {
                  item.minimumScale = scaleRangeDraft.lowerBound
                  item.maximumScale = scaleRangeDraft.upperBound
                },
              )
              .transition(.opacity)
              .onChange(of: scaleRangeDraft) { _, newValue in
                item.minimumScale = newValue.lowerBound
                item.maximumScale = newValue.upperBound
              }
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
  }

  private func toggleExpansion() {
    if isExpanded {
      expandedItemID = nil
    } else {
      expandedItemID = item.id
    }
  }

  private func handleWeightSliderChange(_ configuration: CompactSliderStyleConfiguration) {
    let isCurrentlyDragging = configuration.focusState.isDragging
    if isWeightSliderDragging == isCurrentlyDragging { return }

    let wasDragging = isWeightSliderDragging
    Task {
      if wasDragging, isCurrentlyDragging == false {
        item.weight = weightDraft
      }
      isWeightSliderDragging = isCurrentlyDragging
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
