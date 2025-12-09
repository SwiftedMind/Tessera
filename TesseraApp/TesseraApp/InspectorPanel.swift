// By Dennis Müller

import SwiftUI

struct InspectorPanel: View {
  @Environment(TesseraEditorModel.self) private var editor

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Tessera Inspector")
          .font(.title3.weight(.semibold))
          .padding(.bottom, 4)

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
