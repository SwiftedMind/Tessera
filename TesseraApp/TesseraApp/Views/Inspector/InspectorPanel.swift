// By Dennis Müller

import CompactSlider
import SwiftUI

struct InspectorPanel: View {
  @Environment(TesseraEditorModel.self) private var editor

  @State private var start = 0.9
  @State private var end = 1.2

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .extraLarge) {
        PatternControls()
        ItemList()
      }
      .padding(.extraLarge)
    }
    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
  }
}

#Preview {
  @Previewable @Environment(TesseraEditorModel.self) var editor
  
  InspectorPanel()
    .environment(editor)
}
