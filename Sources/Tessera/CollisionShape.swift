// By Dennis Müller

import CoreGraphics
import SwiftUI

/// A coarse description of a drawable symbol's geometry used for collision checks.
///
/// > Important: Complex polygons and multi-polygon shapes are more expensive to evaluate and can reduce placement
/// > performance, especially at high densities.
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
  /// An arbitrary polygon defined in view-local space.
  ///
  /// The points are interpreted in view-local space with a top-leading origin.
  ///
  /// > Important: Polygons are expected to be simple (non-self-intersecting) and contain at least three points.
  /// > Non-simple polygons fall back to a convex hull; polygons with too few points are ignored.
  ///
  /// - Parameter points: The polygon points in view-local space.
  case polygon(points: [CGPoint])
  /// Multiple polygons defined in view-local space, treated as a single collision shape.
  ///
  /// The point sets are interpreted in view-local space with a top-leading origin.
  ///
  /// > Important: Polygons are expected to be simple (non-self-intersecting) and contain at least three points.
  /// > Non-simple polygons fall back to a convex hull; polygons with too few points are ignored.
  ///
  /// - Parameter pointSets: The polygon point lists in view-local space.
  case polygons(pointSets: [[CGPoint]])
  /// An arbitrary polygon defined in view-local space with an explicit anchor.
  ///
  /// > Important: Polygons are expected to be simple (non-self-intersecting) and contain at least three points.
  /// > Non-simple polygons fall back to a convex hull; polygons with too few points are ignored.
  ///
  /// - Parameters:
  ///   - points: The polygon points in view-local space.
  ///   - anchor: The anchor in view-local space that corresponds to the view's origin.
  ///   - size: The view size used to translate points into centered local space.
  case anchoredPolygon(points: [CGPoint], anchor: UnitPoint, size: CGSize)
  /// Multiple polygons defined in view-local space, treated as a single collision shape.
  ///
  /// > Important: Polygons are expected to be simple (non-self-intersecting) and contain at least three points.
  /// > Non-simple polygons fall back to a convex hull; polygons with too few points are ignored.
  ///
  /// - Parameters:
  ///   - pointSets: The polygon point lists in view-local space.
  ///   - anchor: The anchor in view-local space that corresponds to the view's origin.
  ///   - size: The view size used to translate points into centered local space.
  case anchoredPolygons(pointSets: [[CGPoint]], anchor: UnitPoint, size: CGSize)
  /// An arbitrary polygon defined in local space, with a center origin.
  ///
  /// > Important: Polygons are expected to be simple (non-self-intersecting) and contain at least three points.
  /// > Non-simple polygons fall back to a convex hull; polygons with too few points are ignored.
  ///
  /// - Parameter points: The polygon points in centered local space.
  case centeredPolygon(points: [CGPoint])
  /// Multiple polygons defined in local space, with a center origin.
  ///
  /// Concave polygons are supported by decomposing them into convex pieces for collision checks.
  /// This yields a more accurate footprint but increases placement cost.
  ///
  /// > Important: Polygons are expected to be simple (non-self-intersecting) and contain at least three points.
  /// > Non-simple polygons fall back to a convex hull; polygons with too few points are ignored.
  ///
  /// - Parameter points: The point lists for each polygon in centered local space.
  case centeredPolygons(pointSets: [[CGPoint]])
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
    case let .polygon(points: points):
      let centeredPoints = CollisionMath.centeredPointsUsingBounds(points)
      return maximumDistance(from: centeredPoints) * scale
    case let .polygons(pointSets: points):
      let centeredPoints = CollisionMath.centeredPointSetsUsingBounds(points).flatMap(\.self)
      return maximumDistance(from: centeredPoints) * scale
    case let .anchoredPolygon(points: viewPoints, anchor: anchor, size: size):
      let centeredPoints = CollisionMath.centeredPoints(viewPoints, anchor: anchor, size: size)
      return maximumDistance(from: centeredPoints) * scale
    case let .anchoredPolygons(pointSets: viewPointSets, anchor: anchor, size: size):
      let centeredPoints = CollisionMath.centeredPointSets(viewPointSets, anchor: anchor, size: size).flatMap(\.self)
      return maximumDistance(from: centeredPoints) * scale
    case let .centeredPolygon(points):
      return maximumDistance(from: points) * scale
    case let .centeredPolygons(pointSets):
      let flattenedPoints = pointSets.flatMap(\.self)
      return maximumDistance(from: flattenedPoints) * scale
    }
  }

  private func maximumDistance(from points: [CGPoint]) -> CGFloat {
    guard !points.isEmpty else { return 0 }

    return points.map { hypot($0.x, $0.y) }.max() ?? 0
  }
}
