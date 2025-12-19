// By Dennis Müller

import Observation
import SwiftUI

extension CollisionShapeEditor {
  /// Allows switching between polygon, circle, and rectangle editing modes.
  struct PickerView: View {
    @Environment(CollisionEditorState.self) private var editorState

    var body: some View {
      @Bindable var editorState = editorState

      Picker("", selection: $editorState.selectedShapeKind) {
        ForEach(ShapeKind.allCases) { kind in
          Text(kind.title).tag(kind)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: .infinity)
    }
  }
}
