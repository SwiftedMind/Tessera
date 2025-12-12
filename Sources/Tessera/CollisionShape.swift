// By Dennis Müller

import CoreGraphics

/// A coarse description of a drawable item's geometry used for collision checks.
public enum CollisionShape: Sendable, Hashable {
  /// A circle centered on the origin.
  case circle(radius: CGFloat)
  /// An axis-aligned rectangle centered on the origin.
  case rectangle(size: CGSize)
  /// An arbitrary polygon defined in local space and centered on the origin.
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
    case let .circle(radius):
      return radius * scale
    case let .rectangle(size):
      let halfWidth = size.width * scale / 2
      let halfHeight = size.height * scale / 2
      return hypot(halfWidth, halfHeight)
    case let .polygon(points):
      guard !points.isEmpty else { return 0 }

      let maximumDistance = points.map { hypot($0.x, $0.y) }.max() ?? 0
      return maximumDistance * scale
    }
  }
}
