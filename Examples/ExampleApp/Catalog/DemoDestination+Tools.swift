// By Dennis Müller

import SwiftUI

extension DemoDestination {
  @ViewBuilder
  func collisionShapeEditorView() -> some View {
    DemoExampleScreen(title: "Collision Shape Editor", ignoresSafeArea: false) {
      DemoExampleAssets.collisionPreviewSymbol
        .collisionShapeEditor()
    }
  }
}
