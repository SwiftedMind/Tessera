// By Dennis Müller

import SwiftUI

struct ItemList: View {
  @Environment(TesseraEditorModel.self) private var editor
  @State private var expandedItemID: EditableItem.ID?

  var body: some View {
    @Bindable var editor = editor

    VStack(alignment: .leading, spacing: .medium) {
      HStack {
        Label("Items", systemImage: "square.fill.text.grid.1x2")
          .font(.headline)
        Spacer()
        Menu {
          ForEach(EditableItem.Preset.allCases) { preset in
            Button(preset.title) {
              editor.tesseraItems.append(EditableItem(preset: preset))
            }
          }
        } label: {
          Label("Add Item", systemImage: "plus")
        }
        .buttonStyle(.bordered)
      }

      VStack(spacing: .medium) {
        ForEach($editor.tesseraItems) { $item in
          ItemCard(item: $item, expandedItemID: $expandedItemID) {
            remove(item)
          }
        }
      }
      .animation(.default, value: expandedItemID)
      .animation(.default, value: editor.tesseraItems.count)
    }
  }

  private func remove(_ item: EditableItem) {
    editor.tesseraItems.removeAll(where: { $0.id == item.id })
  }
}

#Preview {
  ItemList()
    .environment(TesseraEditorModel())
    .padding(.large)
}
