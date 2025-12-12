// By Dennis Müller

import CompactSlider
import SwiftUI

struct InspectorPanel: View {
  @Environment(TesseraEditorModel.self) private var editor
  @State private var isCustomizationEnabled = false
  @State private var expandedItemID: UUID?
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .extraLarge) {
        PatternControls(isCustomizationEnabled: $isCustomizationEnabled)
          .clipped()
        if editor.patternMode == .canvas {
          FixedItemList(expandedItemID: $expandedItemID)
            .clipped()
        }
        ItemList(expandedItemID: $expandedItemID)
          .clipped()
      }
      .padding(.extraLarge)
    }
    .animation(.default, value: isCustomizationEnabled)
    .animation(.default, value: editor.patternMode)
    .animation(.default, value: expandedItemID)
    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
  }
}

#Preview {
  @Previewable @Environment(TesseraEditorModel.self) var editor

  InspectorPanel()
    .environment(editor)
}
