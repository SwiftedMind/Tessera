// By Dennis Müller

import CoreGraphics

/// Shared mask-boundary validation used by organic and grid placement engines.
enum ShapePlacementMaskConstraint {
  /// Defines how strictly collision geometry must stay inside an alpha mask.
  enum Mode: Sendable {
    /// Requires only the placement center point to be inside the mask.
    case centerPoint
    /// Requires sampled collision geometry points to stay inside the mask.
    case sampledCollisionGeometry
  }

  /// Returns `true` when the candidate collision geometry stays inside the mask.
  static func isPlacementInsideMask(
    _ alphaMask: any PlacementMask,
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: Mode,
    centerAlreadyValidated: Bool = false,
  ) -> Bool {
    isPlacementInsideMask(
      contains: PlacementMaskContainment.containsFunction(for: alphaMask),
      collisionTransform: collisionTransform,
      polygons: polygons,
      mode: mode,
      centerAlreadyValidated: centerAlreadyValidated,
    )
  }

  /// Returns `true` when all required sampled points satisfy the provided inclusion closure.
  static func isPlacementInsideMask(
    contains: (CGPoint) -> Bool,
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: Mode,
    centerAlreadyValidated: Bool = false,
  ) -> Bool {
    if centerAlreadyValidated == false, contains(collisionTransform.position) == false {
      return false
    }
    guard mode == .sampledCollisionGeometry else { return true }
    guard polygons.isEmpty == false else { return true }

    for polygon in polygons {
      if contains(CollisionMath.applyTransform(polygon.localCenter, using: collisionTransform)) == false {
        return false
      }

      let points = polygon.points
      guard points.isEmpty == false else { continue }

      for index in points.indices {
        let pointA = points[index]
        let pointB = points[(index + 1) % points.count]
        if contains(CollisionMath.applyTransform(pointA, using: collisionTransform)) == false {
          return false
        }

        let midpoint = CGPoint(
          x: (pointA.x + pointB.x) / 2,
          y: (pointA.y + pointB.y) / 2,
        )
        if contains(CollisionMath.applyTransform(midpoint, using: collisionTransform)) == false {
          return false
        }
      }
    }

    return true
  }

  /// Produces mask-validation sample points for transformed collision geometry.
  ///
  /// Sampling includes shape centers, polygon vertices, and edge midpoints.
  static func sampledPoints(
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
  ) -> [CGPoint] {
    var sampled: [CGPoint] = [collisionTransform.position]
    sampled.reserveCapacity(1 + polygons.reduce(0) { $0 + max(1, $1.points.count * 2) })

    for polygon in polygons {
      sampled.append(CollisionMath.applyTransform(polygon.localCenter, using: collisionTransform))

      let points = polygon.points
      guard points.isEmpty == false else { continue }

      for index in points.indices {
        let pointA = points[index]
        let pointB = points[(index + 1) % points.count]
        sampled.append(CollisionMath.applyTransform(pointA, using: collisionTransform))

        let midpoint = CGPoint(
          x: (pointA.x + pointB.x) / 2,
          y: (pointA.y + pointB.y) / 2,
        )
        sampled.append(CollisionMath.applyTransform(midpoint, using: collisionTransform))
      }
    }

    return sampled
  }
}
