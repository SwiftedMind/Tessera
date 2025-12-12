// By Dennis Müller

import CompactSlider
import SwiftUI

struct InspectorPanel: View {
  @Environment(TesseraEditorModel.self) private var editor
  @State private var isCustomizationEnabled = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .extraLarge) {
        PatternControls(isCustomizationEnabled: $isCustomizationEnabled)
          .clipped()
        ItemList()
          .clipped()
        if editor.patternMode == .canvas {
          FixedItemList()
            .clipped()
            .transition(.opacity)
        }
      }
      .padding(.extraLarge)
    }
    .animation(.default, value: isCustomizationEnabled)
    .animation(.default, value: editor.patternMode)
    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
  }
}

#Preview {
  @Previewable @Environment(TesseraEditorModel.self) var editor

  InspectorPanel()
    .environment(editor)
}
