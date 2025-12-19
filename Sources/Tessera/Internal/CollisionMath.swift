// By Dennis Müller

import CoreGraphics
import SwiftUI

/// A polygon plus cached data to speed up collision checks.
struct CollisionPolygon: Sendable {
  var points: [CGPoint]
  var localUnitAxes: [CGVector]
  var localCenter: CGPoint
  var localBoundingRadius: CGFloat

  init(points: [CGPoint]) {
    self.points = points
    localUnitAxes = CollisionMath.separatingAxes(for: points)
    localCenter = CollisionMath.polygonCenter(for: points)
    localBoundingRadius = CollisionMath.maximumDistance(from: localCenter, in: points)
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

  static func polygonsIntersect(
    _ polygonsA: [CollisionPolygon],
    transformA: CollisionTransform,
    _ polygonsB: [CollisionPolygon],
    transformB: CollisionTransform,
    buffer: CGFloat = 0,
  ) -> Bool {
    guard !polygonsA.isEmpty, !polygonsB.isEmpty else { return false }

    let halfBuffer = max(buffer, 0) / 2

    for polygonA in polygonsA {
      let centerA = applyTransform(polygonA.localCenter, using: transformA)
      let radiusA = polygonA.localBoundingRadius * transformA.scale + halfBuffer

      for polygonB in polygonsB {
        let centerB = applyTransform(polygonB.localCenter, using: transformB)
        let radiusB = polygonB.localBoundingRadius * transformB.scale + halfBuffer
        let deltaX = centerA.x - centerB.x
        let deltaY = centerA.y - centerB.y
        let distanceSquared = deltaX * deltaX + deltaY * deltaY
        let combinedRadius = radiusA + radiusB

        guard distanceSquared <= combinedRadius * combinedRadius else { continue }

        if polygonsIntersect(
          polygonA,
          transformA: transformA,
          polygonB,
          transformB: transformB,
          buffer: buffer,
        ) {
          return true
        }
      }
    }

    return false
  }

  static func polygonPointSets(
    for shape: CollisionShape,
    circleSubdivisionCount: Int = 12,
  ) -> [[CGPoint]] {
    switch shape {
    case let .circle(center, radius):
      let steps = max(circleSubdivisionCount, 6)
      return [
        stride(from: 0, to: steps, by: 1).map { step in
          let angle = (Double(step) / Double(steps)) * (2 * Double.pi)
          let cosine = cos(angle)
          let sine = sin(angle)
          return CGPoint(
            x: center.x + radius * CGFloat(cosine),
            y: center.y + radius * CGFloat(sine),
          )
        },
      ]
    case let .rectangle(center, size):
      let halfWidth = size.width / 2
      let halfHeight = size.height / 2
      return [[
        CGPoint(x: center.x - halfWidth, y: center.y - halfHeight),
        CGPoint(x: center.x + halfWidth, y: center.y - halfHeight),
        CGPoint(x: center.x + halfWidth, y: center.y + halfHeight),
        CGPoint(x: center.x - halfWidth, y: center.y + halfHeight),
      ]]
    case let .polygon(points: points):
      return [centeredPointsUsingBounds(points)]
    case let .polygons(pointSets: pointSets):
      return centeredPointSetsUsingBounds(pointSets)
    case let .centeredPolygon(points):
      return [points]
    case let .anchoredPolygon(points: points, anchor: anchor, size: size):
      return [centeredPoints(points, anchor: anchor, size: size)]
    case let .centeredPolygons(points):
      return points
    case let .anchoredPolygons(pointSets: pointSets, anchor: anchor, size: size):
      return centeredPointSets(pointSets, anchor: anchor, size: size)
    }
  }

  static func polygons(
    for shape: CollisionShape,
    circleSubdivisionCount: Int = 12,
  ) -> [CollisionPolygon] {
    let pointSets = polygonPointSets(
      for: shape,
      circleSubdivisionCount: circleSubdivisionCount,
    )

    return pointSets.flatMap { points in
      convexPolygonPointSets(from: points)
        .map { CollisionPolygon(points: $0) }
    }
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

  private static let polygonEpsilon: CGFloat = 0.000_001

  fileprivate static func polygonCenter(for points: [CGPoint]) -> CGPoint {
    guard points.isEmpty == false else { return .zero }

    var sumX: CGFloat = 0
    var sumY: CGFloat = 0

    for point in points {
      sumX += point.x
      sumY += point.y
    }

    let count = CGFloat(points.count)
    return CGPoint(x: sumX / count, y: sumY / count)
  }

  fileprivate static func maximumDistance(from center: CGPoint, in points: [CGPoint]) -> CGFloat {
    guard points.isEmpty == false else { return 0 }

    return points.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
  }

  static func centeredPointsUsingBounds(_ points: [CGPoint]) -> [CGPoint] {
    guard let bounds = bounds(for: points) else { return [] }

    let offset = CGPoint(x: -bounds.midX, y: -bounds.midY)
    return points.map { point in
      CGPoint(x: point.x + offset.x, y: point.y + offset.y)
    }
  }

  static func centeredPointSetsUsingBounds(_ pointSets: [[CGPoint]]) -> [[CGPoint]] {
    let allPoints = pointSets.flatMap(\.self)
    guard let bounds = bounds(for: allPoints) else { return pointSets }

    let offset = CGPoint(x: -bounds.midX, y: -bounds.midY)
    return pointSets.map { points in
      points.map { point in
        CGPoint(x: point.x + offset.x, y: point.y + offset.y)
      }
    }
  }

  static func centeredPointSets(
    _ pointSets: [[CGPoint]],
    anchor: UnitPoint,
    size: CGSize,
  ) -> [[CGPoint]] {
    guard pointSets.isEmpty == false else { return [] }

    let anchorPoint = CGPoint(x: size.width * anchor.x, y: size.height * anchor.y)
    let centerPoint = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    let offset = CGPoint(x: anchorPoint.x - centerPoint.x, y: anchorPoint.y - centerPoint.y)

    return pointSets.map { points in
      points.map { point in
        CGPoint(x: point.x + offset.x, y: point.y + offset.y)
      }
    }
  }

  static func centeredPoints(
    _ points: [CGPoint],
    anchor: UnitPoint,
    size: CGSize,
  ) -> [CGPoint] {
    guard points.isEmpty == false else { return [] }

    let anchorPoint = CGPoint(x: size.width * anchor.x, y: size.height * anchor.y)
    let centerPoint = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    let offset = CGPoint(x: anchorPoint.x - centerPoint.x, y: anchorPoint.y - centerPoint.y)

    return points.map { point in
      CGPoint(x: point.x + offset.x, y: point.y + offset.y)
    }
  }

  private static func convexPolygonPointSets(from points: [CGPoint]) -> [[CGPoint]] {
    let sanitizedPoints = sanitizePolygonPoints(points)
    guard sanitizedPoints.count >= 3 else { return [] }

    if isConvexPolygon(sanitizedPoints) {
      return [sanitizedPoints]
    }

    if let triangles = triangulatePolygon(sanitizedPoints) {
      return triangles
    }

    let hull = convexHull(from: sanitizedPoints)
    return hull.count >= 3 ? [hull] : []
  }

  private static func sanitizePolygonPoints(_ points: [CGPoint]) -> [CGPoint] {
    guard points.count > 1 else { return points }

    var uniquePoints: [CGPoint] = []
    uniquePoints.reserveCapacity(points.count)

    for point in points {
      if let lastPoint = uniquePoints.last,
         distanceBetween(lastPoint, point) <= polygonEpsilon {
        continue
      }
      uniquePoints.append(point)
    }

    if uniquePoints.count > 1,
       let firstPoint = uniquePoints.first,
       let lastPoint = uniquePoints.last,
       distanceBetween(firstPoint, lastPoint) <= polygonEpsilon {
      uniquePoints.removeLast()
    }

    return removeColinearPoints(from: uniquePoints)
  }

  private static func removeColinearPoints(from points: [CGPoint]) -> [CGPoint] {
    guard points.count > 2 else { return points }

    var cleanedPoints = points
    var didRemovePoint = true
    var iteration = 0
    let maximumIterations = points.count

    while didRemovePoint, cleanedPoints.count > 2, iteration < maximumIterations {
      didRemovePoint = false
      iteration += 1
      let count = cleanedPoints.count

      var filteredPoints: [CGPoint] = []
      filteredPoints.reserveCapacity(count)

      for index in 0..<count {
        let previousPoint = cleanedPoints[(index - 1 + count) % count]
        let currentPoint = cleanedPoints[index]
        let nextPoint = cleanedPoints[(index + 1) % count]

        let cross = cornerCross(
          previous: previousPoint,
          current: currentPoint,
          next: nextPoint,
        )

        if abs(cross) <= polygonEpsilon {
          didRemovePoint = true
          continue
        }

        filteredPoints.append(currentPoint)
      }

      cleanedPoints = filteredPoints
    }

    return cleanedPoints
  }

  private static func isConvexPolygon(_ points: [CGPoint]) -> Bool {
    guard points.count >= 4 else { return true }

    let signedArea = polygonSignedArea(points)
    guard abs(signedArea) > polygonEpsilon else { return true }

    var previousCross: CGFloat?
    let count = points.count

    for index in 0..<count {
      let previousPoint = points[(index - 1 + count) % count]
      let currentPoint = points[index]
      let nextPoint = points[(index + 1) % count]

      let cross = cornerCross(
        previous: previousPoint,
        current: currentPoint,
        next: nextPoint,
      )

      if abs(cross) <= polygonEpsilon {
        continue
      }

      if let previousCross {
        if cross.sign != previousCross.sign {
          return false
        }
      } else {
        previousCross = cross
      }
    }

    return true
  }

  private static func triangulatePolygon(_ points: [CGPoint]) -> [[CGPoint]]? {
    guard points.count >= 3 else { return nil }

    var remainingPoints = points
    var triangles: [[CGPoint]] = []
    let isCounterClockwise = polygonSignedArea(remainingPoints) > 0
    let maximumIterations = remainingPoints.count * remainingPoints.count
    var iteration = 0

    while remainingPoints.count > 3, iteration < maximumIterations {
      iteration += 1
      var didFindEar = false
      let count = remainingPoints.count

      for index in 0..<count {
        let previousIndex = (index - 1 + count) % count
        let nextIndex = (index + 1) % count

        let previousPoint = remainingPoints[previousIndex]
        let currentPoint = remainingPoints[index]
        let nextPoint = remainingPoints[nextIndex]

        if !isConvexVertex(
          previousPoint,
          currentPoint,
          nextPoint,
          isCounterClockwise: isCounterClockwise,
        ) {
          continue
        }

        let triangle = [previousPoint, currentPoint, nextPoint]
        if triangleContainsAnyPoint(
          triangle,
          in: remainingPoints,
          excludingIndices: [previousIndex, index, nextIndex],
          isCounterClockwise: isCounterClockwise,
        ) {
          continue
        }

        triangles.append(triangle)
        remainingPoints.remove(at: index)
        didFindEar = true
        break
      }

      if !didFindEar {
        return nil
      }
    }

    if remainingPoints.count == 3 {
      triangles.append(remainingPoints)
    }

    return triangles
  }

  private static func isConvexVertex(
    _ previousPoint: CGPoint,
    _ currentPoint: CGPoint,
    _ nextPoint: CGPoint,
    isCounterClockwise: Bool,
  ) -> Bool {
    let cross = cornerCross(previous: previousPoint, current: currentPoint, next: nextPoint)
    guard abs(cross) > polygonEpsilon else { return false }

    return isCounterClockwise ? cross > 0 : cross < 0
  }

  private static func triangleContainsAnyPoint(
    _ triangle: [CGPoint],
    in points: [CGPoint],
    excludingIndices: [Int],
    isCounterClockwise: Bool,
  ) -> Bool {
    let excludedSet = Set(excludingIndices)

    for (index, point) in points.enumerated() where excludedSet.contains(index) == false {
      if pointIsInsideTriangle(
        point,
        triangle: triangle,
        isCounterClockwise: isCounterClockwise,
      ) {
        return true
      }
    }

    return false
  }

  private static func pointIsInsideTriangle(
    _ point: CGPoint,
    triangle: [CGPoint],
    isCounterClockwise: Bool,
  ) -> Bool {
    guard triangle.count == 3 else { return false }

    let pointA = triangle[0]
    let pointB = triangle[1]
    let pointC = triangle[2]

    let cross1 = crossProduct(pointA, pointB, point)
    let cross2 = crossProduct(pointB, pointC, point)
    let cross3 = crossProduct(pointC, pointA, point)

    if isCounterClockwise {
      return cross1 >= -polygonEpsilon && cross2 >= -polygonEpsilon && cross3 >= -polygonEpsilon
    }

    return cross1 <= polygonEpsilon && cross2 <= polygonEpsilon && cross3 <= polygonEpsilon
  }

  private static func convexHull(from points: [CGPoint]) -> [CGPoint] {
    guard points.count > 1 else { return points }

    let sortedPoints = points.sorted {
      if $0.x == $1.x {
        return $0.y < $1.y
      }
      return $0.x < $1.x
    }

    var uniquePoints: [CGPoint] = []
    uniquePoints.reserveCapacity(sortedPoints.count)

    for point in sortedPoints {
      if let lastPoint = uniquePoints.last,
         distanceBetween(lastPoint, point) <= polygonEpsilon {
        continue
      }
      uniquePoints.append(point)
    }

    guard uniquePoints.count >= 3 else { return uniquePoints }

    var lowerHull: [CGPoint] = []
    for point in uniquePoints {
      while lowerHull.count >= 2 {
        let lastPoint = lowerHull[lowerHull.count - 1]
        let secondToLastPoint = lowerHull[lowerHull.count - 2]
        let cross = crossProduct(secondToLastPoint, lastPoint, point)
        if cross > polygonEpsilon {
          break
        }
        lowerHull.removeLast()
      }
      lowerHull.append(point)
    }

    var upperHull: [CGPoint] = []
    for point in uniquePoints.reversed() {
      while upperHull.count >= 2 {
        let lastPoint = upperHull[upperHull.count - 1]
        let secondToLastPoint = upperHull[upperHull.count - 2]
        let cross = crossProduct(secondToLastPoint, lastPoint, point)
        if cross > polygonEpsilon {
          break
        }
        upperHull.removeLast()
      }
      upperHull.append(point)
    }

    lowerHull.removeLast()
    upperHull.removeLast()

    return lowerHull + upperHull
  }

  private static func bounds(for points: [CGPoint]) -> CGRect? {
    guard let firstPoint = points.first else { return nil }

    var minimumX = firstPoint.x
    var maximumX = firstPoint.x
    var minimumY = firstPoint.y
    var maximumY = firstPoint.y

    for point in points.dropFirst() {
      minimumX = min(minimumX, point.x)
      maximumX = max(maximumX, point.x)
      minimumY = min(minimumY, point.y)
      maximumY = max(maximumY, point.y)
    }

    return CGRect(
      x: minimumX,
      y: minimumY,
      width: maximumX - minimumX,
      height: maximumY - minimumY,
    )
  }

  private static func polygonSignedArea(_ points: [CGPoint]) -> CGFloat {
    guard points.count >= 3 else { return 0 }

    var area: CGFloat = 0
    for index in points.indices {
      let pointA = points[index]
      let pointB = points[(index + 1) % points.count]
      area += pointA.x * pointB.y - pointB.x * pointA.y
    }

    return area / 2
  }

  private static func cornerCross(
    previous: CGPoint,
    current: CGPoint,
    next: CGPoint,
  ) -> CGFloat {
    let vectorA = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
    let vectorB = CGPoint(x: next.x - current.x, y: next.y - current.y)
    return vectorA.x * vectorB.y - vectorA.y * vectorB.x
  }

  private static func crossProduct(
    _ pointA: CGPoint,
    _ pointB: CGPoint,
    _ pointC: CGPoint,
  ) -> CGFloat {
    let vectorA = CGPoint(x: pointB.x - pointA.x, y: pointB.y - pointA.y)
    let vectorB = CGPoint(x: pointC.x - pointA.x, y: pointC.y - pointA.y)
    return vectorA.x * vectorB.y - vectorA.y * vectorB.x
  }

  private static func distanceBetween(_ pointA: CGPoint, _ pointB: CGPoint) -> CGFloat {
    hypot(pointA.x - pointB.x, pointA.y - pointB.y)
  }
}
