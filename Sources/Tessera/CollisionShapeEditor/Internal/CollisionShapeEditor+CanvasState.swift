// By Dennis Müller

import CoreGraphics

extension CollisionShapeEditor {
  /// Defines the rendered content size and zoom scale for editor canvases.
  struct CanvasState: Equatable {
    var renderedContentSize: CGSize
    var zoomScale: CGFloat
  }
}
