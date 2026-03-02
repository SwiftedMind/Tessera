// By Dennis Müller

import CoreGraphics

/// Shared mask-boundary validation used by organic and grid placement engines.
enum ShapePlacementMaskConstraint {
  /// Returns `true` when the candidate collision geometry stays inside the mask.
  static func isPlacementInsideMask(
    _ alphaMask: TesseraAlphaMask,
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
  ) -> Bool {
    guard alphaMask.contains(collisionTransform.position) else { return false }
    guard polygons.isEmpty == false else { return true }

    for point in sampledPoints(
      collisionTransform: collisionTransform,
      polygons: polygons,
    ) where alphaMask.contains(point) == false {
      return false
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
