// By Dennis Müller

import SwiftUI

struct ItemCard: View {
  @Binding var item: EditableItem
  @Binding var expandedItemID: EditableItem.ID?
  var onRemove: () -> Void
  @State private var weightDraft: Double
  @State private var minRotationDraft: Double
  @State private var maxRotationDraft: Double
  @State private var minScaleDraft: CGFloat
  @State private var maxScaleDraft: CGFloat

  init(
    item: Binding<EditableItem>,
    expandedItemID: Binding<EditableItem.ID?>,
    onRemove: @escaping () -> Void,
  ) {
    _item = item
    _expandedItemID = expandedItemID
    self.onRemove = onRemove
    _weightDraft = State(initialValue: item.wrappedValue.weight)
    _minRotationDraft = State(initialValue: item.wrappedValue.minimumRotation)
    _maxRotationDraft = State(initialValue: item.wrappedValue.maximumRotation)
    _minScaleDraft = State(initialValue: item.wrappedValue.minimumScale)
    _maxScaleDraft = State(initialValue: item.wrappedValue.maximumScale)
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
            Slider(
              value: $weightDraft,
              in: 0.2...6,
              step: 0.1,
            ) {} minimumValueLabel: {
              Text("Low")
            } maximumValueLabel: {
              Text("High")
            } onEditingChanged: { isEditing in
              if isEditing == false {
                item.weight = weightDraft
              }
            }
          }

          VStack(alignment: .leading, spacing: 8) {
            AngleRangeView(
              minimumAngle: $minRotationDraft,
              maximumAngle: $maxRotationDraft,
              onCommit: {
                item.minimumRotation = minRotationDraft
                item.maximumRotation = maxRotationDraft
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
                minScale: $minScaleDraft,
                maxScale: $maxScaleDraft,
                onCommit: {
                  item.minimumScale = minScaleDraft
                  item.maximumScale = maxScaleDraft
                },
              )
              .transition(.opacity)
              .onChange(of: minScaleDraft) { _, newValue in item.minimumScale = newValue }
              .onChange(of: maxScaleDraft) { _, newValue in item.maximumScale = newValue }
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
}

#Preview {
  @Previewable @State var item: EditableItem = .demoItems[0]
  @Previewable @State var expandedItemID: EditableItem.ID?
  
  ItemCard(item: $item, expandedItemID: $expandedItemID) {}
    .padding()
    .frame(height: 600)
}
