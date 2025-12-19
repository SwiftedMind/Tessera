// By Dennis Müller

import Observation
import SwiftUI

/// Allows switching between polygon, circle, and rectangle editing modes.
struct CollisionEditorShapePickerView: View {
  @Environment(CollisionEditorState.self) private var editorState

  var body: some View {
    @Bindable var editorState = editorState

    Picker("", selection: $editorState.selectedShapeKind) {
      ForEach(CollisionEditorShapeKind.allCases) { kind in
        Text(kind.title).tag(kind)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(maxWidth: .infinity)
  }
}
