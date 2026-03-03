// By Dennis Müller

import CoreGraphics
import Foundation

/// Spatial acceleration index used for point-in-mask checks against transformed polygons.
struct ShapeMaskBroadPhaseIndex: Sendable {
  var bounds: CGRect?
  var columnCount: Int
  var rowCount: Int
  var cellWidth: CGFloat
  var cellHeight: CGFloat
  var polygonIndicesByCell: [[Int]]

  init(polygonBounds: [CGRect]) {
    let resolvedBounds: CGRect? = polygonBounds.reduce(nil as CGRect?) { partialResult, polygonBounds in
      if let partialResult {
        return partialResult.union(polygonBounds)
      }
      return polygonBounds
    }
    guard let resolvedBounds,
          resolvedBounds.isNull == false,
          resolvedBounds.isEmpty == false
    else {
      bounds = nil
      columnCount = 0
      rowCount = 0
      cellWidth = 1
      cellHeight = 1
      polygonIndicesByCell = []
      return
    }

    bounds = resolvedBounds
    let polygonCount = max(polygonBounds.count, 1)
    let targetCellCount = min(max(polygonCount * 4, 16), 256)
    let aspectRatio = max(Double(resolvedBounds.width) / Double(max(resolvedBounds.height, 1)), 0.1)
    let resolvedColumns = max(
      1,
      Int(sqrt(Double(targetCellCount) * aspectRatio).rounded(.up)),
    )
    let resolvedRows = max(
      1,
      Int((Double(targetCellCount) / Double(resolvedColumns)).rounded(.up)),
    )

    columnCount = resolvedColumns
    rowCount = resolvedRows
    cellWidth = max(resolvedBounds.width / CGFloat(resolvedColumns), 0.000_1)
    cellHeight = max(resolvedBounds.height / CGFloat(resolvedRows), 0.000_1)
    polygonIndicesByCell = Array(repeating: [Int](), count: resolvedColumns * resolvedRows)

    for (polygonIndex, polygonBounds) in polygonBounds.enumerated() {
      let columnRange = cellColumnRange(for: polygonBounds)
      let rowRange = cellRowRange(for: polygonBounds)
      for row in rowRange {
        for column in columnRange {
          let index = row * resolvedColumns + column
          polygonIndicesByCell[index].append(polygonIndex)
        }
      }
    }
  }

  func cellIndex(for point: CGPoint) -> Int? {
    guard let bounds,
          bounds.contains(point),
          columnCount > 0,
          rowCount > 0
    else {
      return nil
    }

    let rawColumn = Int(floor((point.x - bounds.minX) / cellWidth))
    let rawRow = Int(floor((point.y - bounds.minY) / cellHeight))
    let column = max(0, min(columnCount - 1, rawColumn))
    let row = max(0, min(rowCount - 1, rawRow))
    return row * columnCount + column
  }

  private func cellColumnRange(for polygonBounds: CGRect) -> ClosedRange<Int> {
    guard let bounds, columnCount > 0 else { return 0...0 }

    let minimum = Int(floor((polygonBounds.minX - bounds.minX) / cellWidth))
    let maximum = Int(floor((polygonBounds.maxX - bounds.minX) / cellWidth))
    let clampedMinimum = max(0, min(columnCount - 1, minimum))
    let clampedMaximum = max(0, min(columnCount - 1, maximum))
    return clampedMinimum...max(clampedMinimum, clampedMaximum)
  }

  private func cellRowRange(for polygonBounds: CGRect) -> ClosedRange<Int> {
    guard let bounds, rowCount > 0 else { return 0...0 }

    let minimum = Int(floor((polygonBounds.minY - bounds.minY) / cellHeight))
    let maximum = Int(floor((polygonBounds.maxY - bounds.minY) / cellHeight))
    let clampedMinimum = max(0, min(rowCount - 1, minimum))
    let clampedMaximum = max(0, min(rowCount - 1, maximum))
    return clampedMinimum...max(clampedMinimum, clampedMaximum)
  }
}

/// Collision-shape-derived mask used for mosaic placement acceptance and clipping.
struct MosaicShapeMask: Sendable {
  enum ExactShape: Sendable {
    struct Circle: Sendable {
      var center: CGPoint
      var radius: CGFloat
    }

    struct Rectangle: Sendable {
      var position: CGPoint
      var cosineRotation: CGFloat
      var sineRotation: CGFloat
      var inverseScale: CGFloat
      var localCenter: CGPoint
      var halfWidth: CGFloat
      var halfHeight: CGFloat
    }

    case circle(Circle)
    case rectangle(Rectangle)
  }

  struct Polygon: Sendable {
    var points: [CGPoint]
    var bounds: CGRect
  }

  var size: CGSize
  var exactShape: ExactShape?
  var polygons: [Polygon]
  var bounds: CGRect?
  var broadPhaseIndex: ShapeMaskBroadPhaseIndex

  init(mosaicMask: MosaicMask, canvasSize: CGSize) {
    size = canvasSize
    let position = mosaicMask.position.resolvedPoint(in: canvasSize)
    let collisionTransform = CollisionTransform(
      position: position,
      rotation: CGFloat(mosaicMask.rotation.radians),
      scale: mosaicMask.scale,
    )

    if case let .circle(localCenter, localRadius) = mosaicMask.symbol.collisionShape {
      let transformedCenter = CollisionMath.applyTransform(localCenter, using: collisionTransform)
      let transformedRadius = abs(collisionTransform.scale) * abs(localRadius)
      exactShape = .circle(
        .init(
          center: transformedCenter,
          radius: transformedRadius,
        ),
      )
      polygons = []
      bounds = CGRect(
        x: transformedCenter.x - transformedRadius,
        y: transformedCenter.y - transformedRadius,
        width: transformedRadius * 2,
        height: transformedRadius * 2,
      )
      broadPhaseIndex = ShapeMaskBroadPhaseIndex(polygonBounds: [])
      return
    }

    if case let .rectangle(localCenter, localSize) = mosaicMask.symbol.collisionShape {
      let halfWidth = abs(localSize.width) / 2
      let halfHeight = abs(localSize.height) / 2
      let localCorners: [CGPoint] = [
        CGPoint(x: localCenter.x - halfWidth, y: localCenter.y - halfHeight),
        CGPoint(x: localCenter.x + halfWidth, y: localCenter.y - halfHeight),
        CGPoint(x: localCenter.x + halfWidth, y: localCenter.y + halfHeight),
        CGPoint(x: localCenter.x - halfWidth, y: localCenter.y + halfHeight),
      ]
      let transformedCorners = localCorners.map { corner in
        CollisionMath.applyTransform(corner, using: collisionTransform)
      }
      let resolvedBounds = Self.bounds(for: transformedCorners)
      let cosineRotation = cos(collisionTransform.rotation)
      let sineRotation = sin(collisionTransform.rotation)
      let inverseScale: CGFloat = if abs(collisionTransform.scale) > 0.000_001 {
        1 / collisionTransform.scale
      } else {
        0
      }

      exactShape = .rectangle(
        .init(
          position: collisionTransform.position,
          cosineRotation: cosineRotation,
          sineRotation: sineRotation,
          inverseScale: inverseScale,
          localCenter: localCenter,
          halfWidth: halfWidth,
          halfHeight: halfHeight,
        ),
      )
      polygons = []
      bounds = resolvedBounds
      broadPhaseIndex = ShapeMaskBroadPhaseIndex(polygonBounds: [])
      return
    }

    exactShape = nil
    let transformedPolygons: [Polygon] = CollisionMath.polygons(for: mosaicMask.symbol.collisionShape).compactMap {
      polygon -> Polygon? in
      let transformedPoints = polygon.points.map { point in
        CollisionMath.applyTransform(point, using: collisionTransform)
      }
      guard let polygonBounds = Self.bounds(for: transformedPoints) else {
        return nil
      }

      return Polygon(
        points: transformedPoints,
        bounds: polygonBounds,
      )
    }

    polygons = transformedPolygons
    bounds = transformedPolygons.reduce(nil as CGRect?) { partialResult, polygon in
      if let partialResult {
        return partialResult.union(polygon.bounds)
      }
      return polygon.bounds
    }
    broadPhaseIndex = ShapeMaskBroadPhaseIndex(
      polygonBounds: transformedPolygons.map { polygon in polygon.bounds },
    )
  }

  func contains(_ point: CGPoint) -> Bool {
    guard let bounds, bounds.contains(point) else { return false }

    if let exactShape {
      switch exactShape {
      case let .circle(circle):
        let deltaX = point.x - circle.center.x
        let deltaY = point.y - circle.center.y
        return deltaX * deltaX + deltaY * deltaY <= circle.radius * circle.radius
      case let .rectangle(rectangle):
        guard rectangle.inverseScale != 0 else {
          return false
        }

        let deltaX = point.x - rectangle.position.x
        let deltaY = point.y - rectangle.position.y
        let localX = (deltaX * rectangle.cosineRotation + deltaY * rectangle.sineRotation) * rectangle.inverseScale
        let localY = (-deltaX * rectangle.sineRotation + deltaY * rectangle.cosineRotation) * rectangle.inverseScale
        let epsilon: CGFloat = 0.000_1
        return abs(localX - rectangle.localCenter.x) <= rectangle.halfWidth + epsilon &&
          abs(localY - rectangle.localCenter.y) <= rectangle.halfHeight + epsilon
      }
    }

    let candidatePolygonIndices: [Int]
    if let cellIndex = broadPhaseIndex.cellIndex(for: point) {
      let indexedCandidates = broadPhaseIndex.polygonIndicesByCell[cellIndex]
      candidatePolygonIndices = indexedCandidates.isEmpty ? Array(polygons.indices) : indexedCandidates
    } else {
      candidatePolygonIndices = Array(polygons.indices)
    }

    for polygonIndex in candidatePolygonIndices {
      let polygon = polygons[polygonIndex]
      guard polygon.bounds.contains(point) else { continue }

      if Self.contains(point, inPolygon: polygon.points) {
        return true
      }
    }

    return false
  }

  /// Returns an exact vector path for debug rendering when available.
  func debugCGPath() -> CGPath? {
    if let exactShape {
      switch exactShape {
      case let .circle(circle):
        return CGPath(
          ellipseIn: CGRect(
            x: circle.center.x - circle.radius,
            y: circle.center.y - circle.radius,
            width: circle.radius * 2,
            height: circle.radius * 2,
          ),
          transform: nil,
        )
      case let .rectangle(rectangle):
        guard rectangle.inverseScale != 0 else { return nil }

        let scale = 1 / rectangle.inverseScale
        let corners: [CGPoint] = [
          CGPoint(x: rectangle.localCenter.x - rectangle.halfWidth, y: rectangle.localCenter.y - rectangle.halfHeight),
          CGPoint(x: rectangle.localCenter.x + rectangle.halfWidth, y: rectangle.localCenter.y - rectangle.halfHeight),
          CGPoint(x: rectangle.localCenter.x + rectangle.halfWidth, y: rectangle.localCenter.y + rectangle.halfHeight),
          CGPoint(x: rectangle.localCenter.x - rectangle.halfWidth, y: rectangle.localCenter.y + rectangle.halfHeight),
        ]

        let path = CGMutablePath()
        guard let firstCorner = corners.first else { return nil }

        path.move(to: transformedRectanglePoint(firstCorner, rectangle: rectangle, scale: scale))
        for corner in corners.dropFirst() {
          path.addLine(to: transformedRectanglePoint(corner, rectangle: rectangle, scale: scale))
        }
        path.closeSubpath()
        return path.copy()
      }
    }

    guard polygons.isEmpty == false else { return nil }

    let path = CGMutablePath()
    var hasSubpath = false
    for polygon in polygons {
      guard let firstPoint = polygon.points.first else { continue }

      path.move(to: firstPoint)
      for point in polygon.points.dropFirst() {
        path.addLine(to: point)
      }
      path.closeSubpath()
      hasSubpath = true
    }
    return hasSubpath ? path.copy() : nil
  }

  private func transformedRectanglePoint(
    _ point: CGPoint,
    rectangle: ExactShape.Rectangle,
    scale: CGFloat,
  ) -> CGPoint {
    let scaledX = point.x * scale
    let scaledY = point.y * scale
    return CGPoint(
      x: scaledX * rectangle.cosineRotation - scaledY * rectangle.sineRotation + rectangle.position.x,
      y: scaledX * rectangle.sineRotation + scaledY * rectangle.cosineRotation + rectangle.position.y,
    )
  }

  private static func contains(_ point: CGPoint, inPolygon polygon: [CGPoint]) -> Bool {
    guard polygon.count >= 3 else { return false }

    var isInside = false
    var previousPoint = polygon[polygon.count - 1]

    for currentPoint in polygon {
      if isPoint(point, onSegmentFrom: previousPoint, to: currentPoint) {
        return true
      }

      let intersects = ((currentPoint.y > point.y) != (previousPoint.y > point.y))
      if intersects {
        let denominator = previousPoint.y - currentPoint.y
        if denominator != 0 {
          let intersectionX = (previousPoint.x - currentPoint.x) * (point.y - currentPoint.y) / denominator +
            currentPoint.x
          if point.x < intersectionX {
            isInside.toggle()
          }
        }
      }

      previousPoint = currentPoint
    }

    return isInside
  }

  private static func isPoint(
    _ point: CGPoint,
    onSegmentFrom start: CGPoint,
    to end: CGPoint,
  ) -> Bool {
    let epsilon: CGFloat = 0.000_1
    let deltaX = end.x - start.x
    let deltaY = end.y - start.y
    let segmentLengthSquared = deltaX * deltaX + deltaY * deltaY
    guard segmentLengthSquared > epsilon else {
      return hypot(point.x - start.x, point.y - start.y) <= epsilon
    }

    let t = ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / segmentLengthSquared
    guard t >= -epsilon, t <= 1 + epsilon else { return false }

    let projection = CGPoint(
      x: start.x + t * deltaX,
      y: start.y + t * deltaY,
    )
    return hypot(point.x - projection.x, point.y - projection.y) <= epsilon
  }

  private static func bounds(for points: [CGPoint]) -> CGRect? {
    guard let firstPoint = points.first else { return nil }

    var minimumX = firstPoint.x
    var minimumY = firstPoint.y
    var maximumX = firstPoint.x
    var maximumY = firstPoint.y

    for point in points.dropFirst() {
      minimumX = min(minimumX, point.x)
      minimumY = min(minimumY, point.y)
      maximumX = max(maximumX, point.x)
      maximumY = max(maximumY, point.y)
    }

    return CGRect(
      x: minimumX,
      y: minimumY,
      width: maximumX - minimumX,
      height: maximumY - minimumY,
    )
  }
}

/// Shared pixel grid for sampling shape-derived masks and aligned mask coverage.
struct ShapeMaskRasterGrid: Sendable {
  var size: CGSize
  var pixelsWide: Int
  var pixelsHigh: Int
  var sampleX: [CGFloat]
  var sampleY: [CGFloat]

  init(canvasSize: CGSize, pixelScale: CGFloat) {
    size = canvasSize
    let clampedScale = max(pixelScale, 0.1)
    let resolvedPixelsWide = max(Int((canvasSize.width * clampedScale).rounded(.up)), 1)
    let resolvedPixelsHigh = max(Int((canvasSize.height * clampedScale).rounded(.up)), 1)
    pixelsWide = resolvedPixelsWide
    pixelsHigh = resolvedPixelsHigh
    sampleX = (0..<resolvedPixelsWide).map { pixelX in
      (CGFloat(pixelX) + 0.5) / CGFloat(resolvedPixelsWide) * canvasSize.width
    }
    sampleY = (0..<resolvedPixelsHigh).map { pixelY in
      (CGFloat(pixelY) + 0.5) / CGFloat(resolvedPixelsHigh) * canvasSize.height
    }
  }

  var pixelCount: Int {
    pixelsWide * pixelsHigh
  }

  func point(pixelX: Int, pixelY: Int) -> CGPoint {
    CGPoint(x: sampleX[pixelX], y: sampleY[pixelY])
  }

  func pixelRange(for maskBounds: CGRect?) -> (x: ClosedRange<Int>, y: ClosedRange<Int>)? {
    guard let maskBounds,
          maskBounds.isNull == false,
          maskBounds.isEmpty == false,
          size.width > 0,
          size.height > 0
    else {
      return nil
    }

    let minimumX = Int(floor(maskBounds.minX / size.width * CGFloat(pixelsWide)))
    let maximumX = Int(ceil(maskBounds.maxX / size.width * CGFloat(pixelsWide))) - 1
    let minimumY = Int(floor(maskBounds.minY / size.height * CGFloat(pixelsHigh)))
    let maximumY = Int(ceil(maskBounds.maxY / size.height * CGFloat(pixelsHigh))) - 1

    let clampedMinimumX = max(0, min(pixelsWide - 1, minimumX))
    let clampedMaximumX = max(0, min(pixelsWide - 1, maximumX))
    let clampedMinimumY = max(0, min(pixelsHigh - 1, minimumY))
    let clampedMaximumY = max(0, min(pixelsHigh - 1, maximumY))
    guard clampedMinimumX <= clampedMaximumX, clampedMinimumY <= clampedMaximumY else {
      return nil
    }

    return (
      x: clampedMinimumX...clampedMaximumX,
      y: clampedMinimumY...clampedMaximumY,
    )
  }

  func makeMask(
    alphaBytes: [UInt8],
    thresholdByte: UInt8 = 128,
    sampling: TesseraAlphaMaskRegion.Sampling = .nearest,
    invert: Bool = false,
  ) -> TesseraAlphaMask {
    TesseraAlphaMask(
      size: size,
      pixelsWide: pixelsWide,
      pixelsHigh: pixelsHigh,
      alphaBytes: alphaBytes,
      thresholdByte: thresholdByte,
      sampling: sampling,
      invert: invert,
    )
  }

  func alignedCoverage(for mask: TesseraAlphaMask) -> [UInt8] {
    var coverage = [UInt8](repeating: 0, count: pixelCount)
    for pixelY in 0..<pixelsHigh {
      for pixelX in 0..<pixelsWide {
        let index = pixelY * pixelsWide + pixelX
        if mask.contains(point(pixelX: pixelX, pixelY: pixelY)) {
          coverage[index] = 255
        }
      }
    }
    return coverage
  }
}
