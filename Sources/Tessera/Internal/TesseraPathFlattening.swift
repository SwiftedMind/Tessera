// By Dennis Müller

import CoreGraphics

enum TesseraPathFlattening {
  static func largestClosedPolygonPoints(
    from path: CGPath,
    flatness: CGFloat,
  ) -> [CGPoint] {
    let subpaths = flattenedSubpaths(from: path, flatness: max(flatness, 0.000_1))
    let candidates = subpaths.filter { $0.count >= 3 }

    var bestPoints: [CGPoint] = []
    var bestArea: CGFloat = 0

    for points in candidates {
      let area = abs(polygonArea(points))
      if area > bestArea {
        bestArea = area
        bestPoints = points
      }
    }

    return bestPoints
  }

  private static func flattenedSubpaths(from path: CGPath, flatness: CGFloat) -> [[CGPoint]] {
    var currentPoints: [CGPoint] = []
    var subpaths: [[CGPoint]] = []

    var currentPoint: CGPoint?
    var currentStartPoint: CGPoint?

    func finishCurrentSubpath() {
      guard currentPoints.isEmpty == false else { return }

      currentPoints = normalizedSubpathPoints(currentPoints)
      if currentPoints.count >= 3 {
        subpaths.append(currentPoints)
      }

      currentPoints = []
      currentPoint = nil
      currentStartPoint = nil
    }

    path.applyWithBlock { elementPointer in
      let element = elementPointer.pointee
      let points = element.points

      switch element.type {
      case .moveToPoint:
        finishCurrentSubpath()
        let point = points[0]
        currentStartPoint = point
        currentPoint = point
        currentPoints.append(point)

      case .addLineToPoint:
        let point = points[0]
        currentPoint = point
        currentPoints.append(point)

      case .addQuadCurveToPoint:
        guard let start = currentPoint else { break }

        let control = points[0]
        let end = points[1]
        currentPoints.append(contentsOf: flattenQuadratic(
          start: start,
          control: control,
          end: end,
          flatness: flatness,
          depth: 0,
          maximumDepth: 12,
        ))
        currentPoint = end

      case .addCurveToPoint:
        guard let start = currentPoint else { break }

        let control1 = points[0]
        let control2 = points[1]
        let end = points[2]
        currentPoints.append(contentsOf: flattenCubic(
          start: start,
          control1: control1,
          control2: control2,
          end: end,
          flatness: flatness,
          depth: 0,
          maximumDepth: 12,
        ))
        currentPoint = end

      case .closeSubpath:
        if let start = currentStartPoint {
          currentPoint = start
        }
        finishCurrentSubpath()

      @unknown default:
        break
      }
    }

    finishCurrentSubpath()
    return subpaths
  }

  private static func normalizedSubpathPoints(_ points: [CGPoint]) -> [CGPoint] {
    guard points.count >= 3 else { return points }

    var trimmed = points

    if let first = trimmed.first, let last = trimmed.last, distanceSquared(first, last) <= 0.000_001 {
      trimmed.removeLast()
    }

    return trimmed
  }

  private static func flattenQuadratic(
    start: CGPoint,
    control: CGPoint,
    end: CGPoint,
    flatness: CGFloat,
    depth: Int,
    maximumDepth: Int,
  ) -> [CGPoint] {
    if depth >= maximumDepth {
      return [end]
    }

    if quadraticIsFlatEnough(start: start, control: control, end: end, flatness: flatness) {
      return [end]
    }

    let startControl = midpoint(start, control)
    let controlEnd = midpoint(control, end)
    let startControlEnd = midpoint(startControl, controlEnd)

    let left = flattenQuadratic(
      start: start,
      control: startControl,
      end: startControlEnd,
      flatness: flatness,
      depth: depth + 1,
      maximumDepth: maximumDepth,
    )
    let right = flattenQuadratic(
      start: startControlEnd,
      control: controlEnd,
      end: end,
      flatness: flatness,
      depth: depth + 1,
      maximumDepth: maximumDepth,
    )

    return left + right
  }

  private static func flattenCubic(
    start: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    end: CGPoint,
    flatness: CGFloat,
    depth: Int,
    maximumDepth: Int,
  ) -> [CGPoint] {
    if depth >= maximumDepth {
      return [end]
    }

    if cubicIsFlatEnough(start: start, control1: control1, control2: control2, end: end, flatness: flatness) {
      return [end]
    }

    let startControl1 = midpoint(start, control1)
    let control1Control2 = midpoint(control1, control2)
    let control2End = midpoint(control2, end)

    let startControl1Control2 = midpoint(startControl1, control1Control2)
    let control1Control2End = midpoint(control1Control2, control2End)

    let splitPoint = midpoint(startControl1Control2, control1Control2End)

    let left = flattenCubic(
      start: start,
      control1: startControl1,
      control2: startControl1Control2,
      end: splitPoint,
      flatness: flatness,
      depth: depth + 1,
      maximumDepth: maximumDepth,
    )
    let right = flattenCubic(
      start: splitPoint,
      control1: control1Control2End,
      control2: control2End,
      end: end,
      flatness: flatness,
      depth: depth + 1,
      maximumDepth: maximumDepth,
    )

    return left + right
  }

  private static func quadraticIsFlatEnough(
    start: CGPoint,
    control: CGPoint,
    end: CGPoint,
    flatness: CGFloat,
  ) -> Bool {
    let distance = distanceFromPointToLine(control, lineStart: start, lineEnd: end)
    return distance <= flatness
  }

  private static func cubicIsFlatEnough(
    start: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    end: CGPoint,
    flatness: CGFloat,
  ) -> Bool {
    let distance1 = distanceFromPointToLine(control1, lineStart: start, lineEnd: end)
    let distance2 = distanceFromPointToLine(control2, lineStart: start, lineEnd: end)
    return max(distance1, distance2) <= flatness
  }

  private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
    CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
  }

  private static func distanceFromPointToLine(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
    let dx = lineEnd.x - lineStart.x
    let dy = lineEnd.y - lineStart.y

    if dx == 0, dy == 0 {
      return sqrt(distanceSquared(point, lineStart))
    }

    let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)
    let projection = CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)
    return sqrt(distanceSquared(point, projection))
  }

  private static func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return dx * dx + dy * dy
  }

  private static func polygonArea(_ points: [CGPoint]) -> CGFloat {
    guard points.count >= 3 else { return 0 }

    var sum: CGFloat = 0
    var j = points.count - 1

    for i in points.indices {
      let pointA = points[j]
      let pointB = points[i]
      sum += (pointA.x * pointB.y) - (pointB.x * pointA.y)
      j = i
    }

    return sum * 0.5
  }
}
