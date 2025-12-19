// By Dennis Müller

import CoreGraphics

/// Converts between symbol-local collision coordinates and view coordinates for editor overlays.
struct CollisionEditorViewTransform: Equatable, Sendable {
  /// The rendered (unscaled) content size in points.
  var renderedContentSize: CGSize

  /// The scale used to display the rendered content in the editor view.
  var zoomScale: CGFloat

  init(renderedContentSize: CGSize, zoomScale: CGFloat) {
    self.renderedContentSize = CGSize(
      width: max(renderedContentSize.width, 1),
      height: max(renderedContentSize.height, 1),
    )
    self.zoomScale = zoomScale
  }

  /// A transform that maps base (unscaled) content geometry into the zoomed preview.
  var viewScaleTransform: ViewScaleTransform {
    ViewScaleTransform(scale: zoomScale)
  }

  /// Converts an symbol-local point into view coordinates.
  func viewPoint(fromSymbolLocalPoint symbolLocalPoint: CGPoint) -> CGPoint {
    let basePoint = CGPoint(
      x: (symbolLocalPoint.x + 0.5) * renderedContentSize.width,
      y: (symbolLocalPoint.y + 0.5) * renderedContentSize.height,
    )
    return viewScaleTransform.viewPoint(fromUnscaledPoint: basePoint)
  }

  /// Converts a view-space point into symbol-local coordinates, clamped to the valid bounds.
  func symbolLocalPoint(fromViewPoint viewPoint: CGPoint) -> CGPoint {
    let basePoint = viewScaleTransform.unscaledPoint(fromViewPoint: viewPoint)
    let symbolLocalX = (basePoint.x - renderedContentSize.width / 2) / renderedContentSize.width
    let symbolLocalY = (basePoint.y - renderedContentSize.height / 2) / renderedContentSize.height

    return CGPoint(
      x: min(max(symbolLocalX, -0.5), 0.5),
      y: min(max(symbolLocalY, -0.5), 0.5),
    )
  }

  /// Converts an symbol-local size into a view-space size.
  func viewSize(fromSymbolLocalSize symbolLocalSize: CGSize) -> CGSize {
    let baseSize = CGSize(
      width: symbolLocalSize.width * renderedContentSize.width,
      height: symbolLocalSize.height * renderedContentSize.height,
    )
    return viewScaleTransform.viewSize(fromUnscaledSize: baseSize)
  }

  /// Converts an symbol-local circle radius into a view-space radius.
  func viewRadius(fromSymbolLocalRadius symbolLocalRadius: CGFloat) -> CGFloat {
    let minimumDimension = min(renderedContentSize.width, renderedContentSize.height)
    let baseRadius = symbolLocalRadius * minimumDimension
    return baseRadius * zoomScale
  }

  /// Converts a view-space translation into an symbol-local translation.
  func symbolLocalTranslation(fromViewTranslation viewTranslation: CGSize) -> CGPoint {
    let baseTranslation = viewScaleTransform.unscaledTranslation(fromViewTranslation: viewTranslation)
    return CGPoint(
      x: baseTranslation.width / renderedContentSize.width,
      y: baseTranslation.height / renderedContentSize.height,
    )
  }
}
