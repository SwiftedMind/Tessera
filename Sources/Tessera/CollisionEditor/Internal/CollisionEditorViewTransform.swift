// By Dennis Müller

import CoreGraphics

/// Converts between item-local collision coordinates and view coordinates for editor overlays.
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

  /// Converts an item-local point into view coordinates.
  func viewPoint(fromItemLocalPoint itemLocalPoint: CGPoint) -> CGPoint {
    let basePoint = CGPoint(
      x: (itemLocalPoint.x + 0.5) * renderedContentSize.width,
      y: (itemLocalPoint.y + 0.5) * renderedContentSize.height,
    )
    return viewScaleTransform.viewPoint(fromUnscaledPoint: basePoint)
  }

  /// Converts a view-space point into item-local coordinates, clamped to the valid bounds.
  func itemLocalPoint(fromViewPoint viewPoint: CGPoint) -> CGPoint {
    let basePoint = viewScaleTransform.unscaledPoint(fromViewPoint: viewPoint)
    let itemLocalX = (basePoint.x - renderedContentSize.width / 2) / renderedContentSize.width
    let itemLocalY = (basePoint.y - renderedContentSize.height / 2) / renderedContentSize.height

    return CGPoint(
      x: min(max(itemLocalX, -0.5), 0.5),
      y: min(max(itemLocalY, -0.5), 0.5),
    )
  }

  /// Converts an item-local size into a view-space size.
  func viewSize(fromItemLocalSize itemLocalSize: CGSize) -> CGSize {
    let baseSize = CGSize(
      width: itemLocalSize.width * renderedContentSize.width,
      height: itemLocalSize.height * renderedContentSize.height,
    )
    return viewScaleTransform.viewSize(fromUnscaledSize: baseSize)
  }

  /// Converts an item-local circle radius into a view-space radius.
  func viewRadius(fromItemLocalRadius itemLocalRadius: CGFloat) -> CGFloat {
    let minimumDimension = min(renderedContentSize.width, renderedContentSize.height)
    let baseRadius = itemLocalRadius * minimumDimension
    return baseRadius * zoomScale
  }

  /// Converts a view-space translation into an item-local translation.
  func itemLocalTranslation(fromViewTranslation viewTranslation: CGSize) -> CGPoint {
    let baseTranslation = viewScaleTransform.unscaledTranslation(fromViewTranslation: viewTranslation)
    return CGPoint(
      x: baseTranslation.width / renderedContentSize.width,
      y: baseTranslation.height / renderedContentSize.height,
    )
  }
}
