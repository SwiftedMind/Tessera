// By Dennis Müller

import CoreGraphics

/// Helper functions for shape-aware collision checks.
enum CollisionMath {
  /// Applies a transform to a point in local space to produce world-space coordinates.
  static func applyTransform(_ point: CGPoint, using transform: CollisionTransform) -> CGPoint {
    let scaledX = point.x * transform.scale
    let scaledY = point.y * transform.scale

    let cosineRotation = cos(transform.rotation)
    let sineRotation = sin(transform.rotation)

    let rotatedX = scaledX * cosineRotation - scaledY * sineRotation
    let rotatedY = scaledX * sineRotation + scaledY * cosineRotation

    return CGPoint(
      x: rotatedX + transform.position.x,
      y: rotatedY + transform.position.y,
    )
  }

  /// Fast broad-phase check using bounding circles.
  static func boundingCirclesIntersect(
    shapeA: CollisionShape,
    transformA: CollisionTransform,
    shapeB: CollisionShape,
    transformB: CollisionTransform,
  ) -> Bool {
    let radiusA = shapeA.boundingRadius(atScale: transformA.scale)
    let radiusB = shapeB.boundingRadius(atScale: transformB.scale)
    let combinedRadius = radiusA + radiusB

    let deltaX = transformA.position.x - transformB.position.x
    let deltaY = transformA.position.y - transformB.position.y
    let distanceSquared = deltaX * deltaX + deltaY * deltaY

    return distanceSquared < combinedRadius * combinedRadius
  }

  /// Separating Axis Theorem intersection with optional buffer padding.
  static func polygonsIntersect(
    _ polygonA: [CGPoint],
    transformA: CollisionTransform,
    _ polygonB: [CGPoint],
    transformB: CollisionTransform,
    buffer: CGFloat = 0,
  ) -> Bool {
    guard !polygonA.isEmpty, !polygonB.isEmpty else { return false }

    let worldPolygonA = polygonA.map { applyTransform($0, using: transformA) }
    let worldPolygonB = polygonB.map { applyTransform($0, using: transformB) }

    let axes = separatingAxes(for: worldPolygonA) + separatingAxes(for: worldPolygonB)

    for axis in axes {
      let projectionA = projectionRange(of: worldPolygonA, onto: axis, buffer: buffer)
      let projectionB = projectionRange(of: worldPolygonB, onto: axis, buffer: buffer)

      if projectionA.max < projectionB.min || projectionB.max < projectionA.min {
        return false
      }
    }

    return true
  }

  static func polygonPoints(
    for shape: CollisionShape,
    circleSubdivisionCount: Int = 12,
  ) -> [CGPoint] {
    switch shape {
    case let .circle(center, radius):
      let steps = max(circleSubdivisionCount, 6)
      return stride(from: 0, to: steps, by: 1).map { step in
        let angle = (Double(step) / Double(steps)) * (2 * Double.pi)
        let cosine = cos(angle)
        let sine = sin(angle)
        return CGPoint(
          x: center.x + radius * CGFloat(cosine),
          y: center.y + radius * CGFloat(sine),
        )
      }
    case let .rectangle(center, size):
      let halfWidth = size.width / 2
      let halfHeight = size.height / 2
      return [
        CGPoint(x: center.x - halfWidth, y: center.y - halfHeight),
        CGPoint(x: center.x + halfWidth, y: center.y - halfHeight),
        CGPoint(x: center.x + halfWidth, y: center.y + halfHeight),
        CGPoint(x: center.x - halfWidth, y: center.y + halfHeight),
      ]
    case let .polygon(points):
      return points
    }
  }

  private static func separatingAxes(for polygon: [CGPoint]) -> [CGVector] {
    guard polygon.count >= 2 else { return [] }

    var axes: [CGVector] = []
    axes.reserveCapacity(polygon.count)

    for index in polygon.indices {
      let start = polygon[index]
      let end = polygon[(index + 1) % polygon.count]
      let deltaX = end.x - start.x
      let deltaY = end.y - start.y

      guard deltaX != 0 || deltaY != 0 else { continue }

      let normal = CGVector(dx: -deltaY, dy: deltaX)
      let length = hypot(normal.dx, normal.dy)
      let normalizedAxis = CGVector(dx: normal.dx / length, dy: normal.dy / length)
      axes.append(normalizedAxis)
    }

    return axes
  }

  private static func projectionRange(
    of polygon: [CGPoint],
    onto axis: CGVector,
    buffer: CGFloat,
  ) -> (min: CGFloat, max: CGFloat) {
    var minimum = CGFloat.greatestFiniteMagnitude
    var maximum = -CGFloat.greatestFiniteMagnitude

    for point in polygon {
      let projection = point.x * axis.dx + point.y * axis.dy
      minimum = min(minimum, projection)
      maximum = max(maximum, projection)
    }

    let halfBuffer = max(buffer, 0) / 2
    return (minimum - halfBuffer, maximum + halfBuffer)
  }
}
