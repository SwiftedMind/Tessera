// By Dennis Müller

import SwiftUI

/// Shows the generated collision shape snippets.
struct CollisionEditorOutputSectionView: View {
  @Environment(CollisionEditorState.self) private var editorState

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if editorState.selectedShapeKind == .polygon {
        CollisionEditorOutputBlockView(
          title: "Polygon Points",
          snippet: editorState.polygonPointsSnippet,
          onCopy: {
            CollisionEditorPasteboard.copy(editorState.polygonPointsSnippet)
          },
        )
      }

      CollisionEditorOutputBlockView(
        title: "Collision Shape",
        snippet: editorState.collisionShapeSnippet,
        onCopy: {
          CollisionEditorPasteboard.copy(editorState.collisionShapeSnippet)
        },
      )
    }
  }
}
