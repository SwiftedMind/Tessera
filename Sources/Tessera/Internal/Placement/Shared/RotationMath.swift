// By Dennis Müller

import CoreGraphics

enum RotationMath {
  static func rotate(
    _ point: CGPoint,
    around anchor: CGPoint,
    radians: Double,
  ) -> CGPoint {
    guard radians.isZero == false else { return point }

    let cosine = CGFloat(cos(radians))
    let sine = CGFloat(sin(radians))
    let translatedX = point.x - anchor.x
    let translatedY = point.y - anchor.y
    return CGPoint(
      x: anchor.x + translatedX * cosine - translatedY * sine,
      y: anchor.y + translatedX * sine + translatedY * cosine,
    )
  }

  static func inverseRotatedTileBounds(
    tileSize: CGSize,
    anchor: CGPoint,
    rotationRadians: Double,
  ) -> CGRect {
    let inverseRadians = -rotationRadians
    let corners = [
      CGPoint(x: 0, y: 0),
      CGPoint(x: tileSize.width, y: 0),
      CGPoint(x: 0, y: tileSize.height),
      CGPoint(x: tileSize.width, y: tileSize.height),
    ]

    let rotatedCorners = corners.map { rotate($0, around: anchor, radians: inverseRadians) }

    var minX = rotatedCorners[0].x
    var maxX = rotatedCorners[0].x
    var minY = rotatedCorners[0].y
    var maxY = rotatedCorners[0].y

    for point in rotatedCorners.dropFirst() {
      minX = min(minX, point.x)
      maxX = max(maxX, point.x)
      minY = min(minY, point.y)
      maxY = max(maxY, point.y)
    }

    return CGRect(
      x: minX,
      y: minY,
      width: max(0, maxX - minX),
      height: max(0, maxY - minY),
    )
  }

  static func indexRangeCoveringBounds(
    min: CGFloat,
    max: CGFloat,
    cellSize: CGFloat,
  ) -> ClosedRange<Int> {
    guard cellSize > 0 else { return 0...0 }

    let minIndex = Int(floor((min / cellSize) - 0.5))
    let maxIndex = Int(ceil((max / cellSize) - 0.5))
    return minIndex...maxIndex
  }

  static func clampedIndexRange(
    _ range: ClosedRange<Int>,
    maximumCount: Int,
  ) -> ClosedRange<Int> {
    guard maximumCount > 0 else { return 0...0 }

    let count = range.upperBound - range.lowerBound + 1
    guard count > maximumCount else { return range }

    let mid = (range.lowerBound + range.upperBound) / 2
    let half = (maximumCount - 1) / 2
    let clampedLower = mid - half
    return clampedLower...(clampedLower + maximumCount - 1)
  }
}
