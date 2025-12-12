// By Dennis Müller

import SwiftUI

struct FixedItemList: View {
  @Environment(TesseraEditorModel.self) private var editor
  @State private var expandedFixedItemID: EditableFixedItem.ID?

  var body: some View {
    @Bindable var editor = editor

    VStack(alignment: .leading, spacing: .medium) {
      HStack {
        Label("Fixed Items", systemImage: "pin.fill")
          .font(.headline)
          .help("Placed once; the pattern fills around them.")
        Spacer()
        HStack(spacing: .tight) {
          Menu {
            ForEach(EditableItem.Preset.allPresetGroups) { group in
              Menu {
                ForEach(group.presets) { preset in
                  Button(preset.title) {
                    editor.fixedItems.append(EditableFixedItem(preset: preset))
                  }
                }
              } label: {
                Label(group.title, systemImage: group.iconName)
              }
            }
          } label: {
            Label("Add Fixed Item", systemImage: "plus")
          }
          .buttonStyle(.bordered)
        }
        Button(role: .destructive) {
          removeAllFixedItems()
        } label: {
          Label("Remove All", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .disabled(editor.fixedItems.isEmpty)
      }

      VStack(spacing: .medium) {
        ForEach($editor.fixedItems) { $fixedItem in
          FixedItemCard(
            fixedItem: $fixedItem,
            expandedFixedItemID: $expandedFixedItemID,
          ) {
            remove(fixedItem)
          }
        }
      }
      .animation(.default, value: expandedFixedItemID)
      .animation(.default, value: editor.fixedItems)
    }
  }

  private func remove(_ fixedItem: EditableFixedItem) {
    editor.fixedItems.removeAll(where: { $0.id == fixedItem.id })
  }

  private func removeAllFixedItems() {
    guard editor.fixedItems.isEmpty == false else { return }

    editor.fixedItems.removeAll()
    expandedFixedItemID = nil
  }
}

#Preview {
  @Previewable @Environment(TesseraEditorModel.self) var editor

  FixedItemList()
    .environment(editor)
    .padding(.large)
}
