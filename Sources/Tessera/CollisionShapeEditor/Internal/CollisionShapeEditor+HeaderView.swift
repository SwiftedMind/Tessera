// By Dennis Müller

import SwiftUI

extension CollisionShapeEditor {
  /// Presents the editor title and a short guidance subtitle.
  struct HeaderView: View {
    var title: LocalizedStringKey

    @Environment(CollisionEditorState.self) private var editorState

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.title2)
          .fontWeight(.semibold)

        Text(editorState.selectedShapeKind.subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
