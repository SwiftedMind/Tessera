// By Dennis Müller

import CoreGraphics

/// Converts geometry between an unscaled coordinate space and a scaled view coordinate space.
struct ViewScaleTransform: Equatable, Sendable {
  /// The scale factor applied to map unscaled space into view space.
  var scale: CGFloat

  /// The minimum magnitude used when inverting the scale.
  var minimumInvertibleScale: CGFloat = 0.000_1

  init(scale: CGFloat) {
    self.scale = scale
  }

  /// Returns `scale` clamped to a minimum positive value suitable for inversion.
  var invertibleScale: CGFloat {
    max(abs(scale), minimumInvertibleScale)
  }

  /// Converts an unscaled point into view space by multiplying with `scale`.
  func viewPoint(fromUnscaledPoint unscaledPoint: CGPoint) -> CGPoint {
    CGPoint(x: unscaledPoint.x * scale, y: unscaledPoint.y * scale)
  }

  /// Converts a view-space point into unscaled space by dividing by `invertibleScale`.
  func unscaledPoint(fromViewPoint viewPoint: CGPoint) -> CGPoint {
    CGPoint(x: viewPoint.x / invertibleScale, y: viewPoint.y / invertibleScale)
  }

  /// Converts an unscaled size into view space by multiplying with `scale`.
  func viewSize(fromUnscaledSize unscaledSize: CGSize) -> CGSize {
    CGSize(width: unscaledSize.width * scale, height: unscaledSize.height * scale)
  }

  /// Converts a view-space size into unscaled space by dividing by `invertibleScale`.
  func unscaledSize(fromViewSize viewSize: CGSize) -> CGSize {
    CGSize(width: viewSize.width / invertibleScale, height: viewSize.height / invertibleScale)
  }

  /// Converts a view-space translation into unscaled space.
  func unscaledTranslation(fromViewTranslation viewTranslation: CGSize) -> CGSize {
    unscaledSize(fromViewSize: viewTranslation)
  }
}
