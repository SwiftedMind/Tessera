// By Dennis Müller

import SwiftUI

extension CollisionShapeEditor {
  /// The collision shape types available in the editor.
  enum ShapeKind: String, CaseIterable, Identifiable {
    case circle
    case rectangle
    case polygon

    var id: String { rawValue }

    var title: LocalizedStringKey {
      switch self {
      case .circle:
        "Circle"
      case .rectangle:
        "Rectangle"
      case .polygon:
        "Polygon"
      }
    }

    var subtitle: LocalizedStringKey {
      switch self {
      case .circle:
        "Drag inside the circle to move it. Drag the handle on the outline to resize."
      case .rectangle:
        "Drag inside the rectangle to move it. Drag a corner handle to resize."
      case .polygon:
        "Tap to add points. Drag points to adjust. Drag inside the shape to move it."
      }
    }
  }

}
