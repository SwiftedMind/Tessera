// By Dennis Müller

import SwiftUI

extension CollisionShapeEditor {
  /// Shows the generated collision shape snippets.
  struct OutputSectionView: View {
    @Environment(CollisionEditorState.self) private var editorState

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        if editorState.selectedShapeKind == .polygon {
          OutputBlockView(
            title: "Polygon Points",
            snippet: editorState.polygonPointsSnippet,
            onCopy: {
              Pasteboard.copy(editorState.polygonPointsSnippet)
            },
          )
        }

        OutputBlockView(
          title: "Collision Shape",
          snippet: editorState.collisionShapeSnippet,
          onCopy: {
            Pasteboard.copy(editorState.collisionShapeSnippet)
          },
        )
      }
    }
  }
}
