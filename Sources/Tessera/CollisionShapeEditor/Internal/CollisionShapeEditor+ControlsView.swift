// By Dennis Müller

import SwiftUI

extension CollisionShapeEditor {
  /// Presents context-aware controls for the active collision shape.
  struct ControlsView: View {
    @Environment(CollisionEditorState.self) private var editorState

    var body: some View {
      Menu("Options") {
        switch editorState.selectedShapeKind {
        case .polygon:
          polygonControls
        case .circle:
          circleControls
        case .rectangle:
          rectangleControls
        }
      }
      .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var polygonControls: some View {
      Button("Undo") {
        editorState.undoPolygonPoint()
      }
      .disabled(editorState.hasPolygonPoints == false)

      Button("Clear") {
        editorState.clearPolygonPoints()
      }
      .disabled(editorState.hasPolygonPoints == false)

      Button("Close Polygon") {
        editorState.closePolygon()
      }
      .disabled(editorState.canClosePolygon == false)
    }

    @ViewBuilder
    private var circleControls: some View {
      Button("Center") {
        editorState.centerCircle()
      }

      Button("Fit") {
        editorState.fitCircle()
      }
    }

    @ViewBuilder
    private var rectangleControls: some View {
      Button("Center") {
        editorState.centerRectangle()
      }

      Button("Fit") {
        editorState.fitRectangle()
      }
    }
  }

}
