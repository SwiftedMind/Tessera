// By Dennis Müller

import CoreGraphics

/// A polygon plus cached data to speed up collision checks.
struct CollisionPolygon: Sendable {
  var points: [CGPoint]
  var localUnitAxes: [CGVector]

  init(points: [CGPoint]) {
    self.points = points
    localUnitAxes = CollisionMath.separatingAxes(for: points)
  }
}

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
    polygonsIntersect(
      CollisionPolygon(points: polygonA),
      transformA: transformA,
      CollisionPolygon(points: polygonB),
      transformB: transformB,
      buffer: buffer,
    )
  }

  /// Separating Axis Theorem intersection with optional buffer padding.
  ///
  /// This overload accepts cached polygon data to avoid repeated allocations and recomputation.
  static func polygonsIntersect(
    _ polygonA: CollisionPolygon,
    transformA: CollisionTransform,
    _ polygonB: CollisionPolygon,
    transformB: CollisionTransform,
    buffer: CGFloat = 0,
  ) -> Bool {
    guard !polygonA.points.isEmpty, !polygonB.points.isEmpty else { return false }

    let halfBuffer = max(buffer, 0) / 2

    let cosineRotationA = cos(transformA.rotation)
    let sineRotationA = sin(transformA.rotation)
    let cosineRotationB = cos(transformB.rotation)
    let sineRotationB = sin(transformB.rotation)

    let rotationDifference = transformA.rotation - transformB.rotation
    let cosineRotationDifference = cos(rotationDifference)
    let sineRotationDifference = sin(rotationDifference)

    let positionA = transformA.position
    let positionB = transformB.position

    // Axes derived from polygon A edges (in A-local space).
    for axisInLocalSpaceA in polygonA.localUnitAxes {
      let axisInWorldSpace = rotate(axisInLocalSpaceA, cosine: cosineRotationA, sine: sineRotationA)
      let axisInLocalSpaceB = rotate(
        axisInLocalSpaceA,
        cosine: cosineRotationDifference,
        sine: sineRotationDifference,
      )

      let positionProjectionA = dot(positionA, axisInWorldSpace)
      let positionProjectionB = dot(positionB, axisInWorldSpace)

      let projectionA = projectionRange(
        of: polygonA.points,
        onto: axisInLocalSpaceA,
        scale: transformA.scale,
        positionProjection: positionProjectionA,
        halfBuffer: halfBuffer,
      )
      let projectionB = projectionRange(
        of: polygonB.points,
        onto: axisInLocalSpaceB,
        scale: transformB.scale,
        positionProjection: positionProjectionB,
        halfBuffer: halfBuffer,
      )

      if projectionA.max < projectionB.min || projectionB.max < projectionA.min {
        return false
      }
    }

    // Axes derived from polygon B edges (in B-local space).
    for axisInLocalSpaceB in polygonB.localUnitAxes {
      let axisInWorldSpace = rotate(axisInLocalSpaceB, cosine: cosineRotationB, sine: sineRotationB)
      let axisInLocalSpaceA = rotate(
        axisInLocalSpaceB,
        cosine: cosineRotationDifference,
        sine: -sineRotationDifference,
      )

      let positionProjectionA = dot(positionA, axisInWorldSpace)
      let positionProjectionB = dot(positionB, axisInWorldSpace)

      let projectionA = projectionRange(
        of: polygonA.points,
        onto: axisInLocalSpaceA,
        scale: transformA.scale,
        positionProjection: positionProjectionA,
        halfBuffer: halfBuffer,
      )
      let projectionB = projectionRange(
        of: polygonB.points,
        onto: axisInLocalSpaceB,
        scale: transformB.scale,
        positionProjection: positionProjectionB,
        halfBuffer: halfBuffer,
      )

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

  static func polygon(
    for shape: CollisionShape,
    circleSubdivisionCount: Int = 12,
  ) -> CollisionPolygon {
    CollisionPolygon(
      points: polygonPoints(
        for: shape,
        circleSubdivisionCount: circleSubdivisionCount,
      ),
    )
  }

  fileprivate static func separatingAxes(for polygon: [CGPoint]) -> [CGVector] {
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
    scale: CGFloat,
    positionProjection: CGFloat,
    halfBuffer: CGFloat,
  ) -> (min: CGFloat, max: CGFloat) {
    var minimum = CGFloat.greatestFiniteMagnitude
    var maximum = -CGFloat.greatestFiniteMagnitude

    for point in polygon {
      let localProjection = point.x * axis.dx + point.y * axis.dy
      let projection = localProjection * scale + positionProjection
      minimum = min(minimum, projection)
      maximum = max(maximum, projection)
    }

    return (minimum - halfBuffer, maximum + halfBuffer)
  }

  private static func dot(_ point: CGPoint, _ vector: CGVector) -> CGFloat {
    point.x * vector.dx + point.y * vector.dy
  }

  private static func rotate(_ vector: CGVector, cosine: CGFloat, sine: CGFloat) -> CGVector {
    CGVector(
      dx: vector.dx * cosine - vector.dy * sine,
      dy: vector.dx * sine + vector.dy * cosine,
    )
  }
}
