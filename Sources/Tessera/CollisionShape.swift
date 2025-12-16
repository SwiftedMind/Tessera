// By Dennis Müller

import CoreGraphics

/// A coarse description of a drawable item's geometry used for collision checks.
public enum CollisionShape: Sendable, Hashable {
  /// A circle centered at `center` in local space.
  ///
  /// - Parameters:
  ///   - center: The circle's center in local space.
  ///   - radius: The circle's radius in local space.
  case circle(center: CGPoint, radius: CGFloat)
  /// An axis-aligned rectangle centered at `center` in local space.
  ///
  /// - Parameters:
  ///   - center: The rectangle's center in local space.
  ///   - size: The rectangle's size in local space.
  case rectangle(center: CGPoint, size: CGSize)
  /// An arbitrary polygon defined in local space.
  case polygon(points: [CGPoint])
}

/// A lightweight transform describing where and how a shape is placed.
struct CollisionTransform: Sendable {
  /// Position in tile space.
  var position: CGPoint
  /// Rotation in radians.
  var rotation: CGFloat
  /// Uniform scale factor.
  var scale: CGFloat

  init(position: CGPoint, rotation: CGFloat, scale: CGFloat) {
    self.position = position
    self.rotation = rotation
    self.scale = scale
  }
}

public extension CollisionShape {
  /// Conservative radius around the shape, used for a quick broad-phase overlap check.
  func boundingRadius(atScale scale: CGFloat = 1) -> CGFloat {
    switch self {
    case let .circle(center, radius):
      return (hypot(center.x, center.y) + radius) * scale
    case let .rectangle(center, size):
      let halfWidth = size.width / 2
      let halfHeight = size.height / 2
      let maximumXDistance = abs(center.x) + halfWidth
      let maximumYDistance = abs(center.y) + halfHeight
      return hypot(maximumXDistance, maximumYDistance) * scale
    case let .polygon(points):
      guard !points.isEmpty else { return 0 }

      let maximumDistance = points.map { hypot($0.x, $0.y) }.max() ?? 0
      return maximumDistance * scale
    }
  }
}
