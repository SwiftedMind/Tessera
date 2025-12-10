// By Dennis Müller

import SwiftUI
import CompactSlider

struct InspectorPanel: View {
  @Environment(TesseraEditorModel.self) private var editor
  
  @State private var start = 0.9
  @State private var end = 1.2
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        
        PatternControls()

        ItemList()
      }
      .padding(20)
    }
    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
  }
}

#Preview {
  InspectorPanel()
  .environment(TesseraEditorModel())
}
