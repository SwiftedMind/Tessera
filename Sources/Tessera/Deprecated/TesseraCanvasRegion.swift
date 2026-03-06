// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Defines the drawable region used by a tessera canvas.
///
/// Polygon points are interpreted in an arbitrary source space and mapped into the resolved canvas size.
/// The default mapping uses aspect-fit and centered alignment.
public enum TesseraCanvasRegion: Sendable, Hashable {
  /// A full rectangular region that matches the canvas bounds.
  case rectangle
  /// A polygonal region defined by points in an arbitrary source space.
  /// - Parameters:
  ///   - points: Polygon points in a source space.
  ///   - mapping: Mapping strategy that fits the polygon into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  case polygon(points: [CGPoint], mapping: TesseraPolygonMapping, padding: CGFloat)
  /// An alpha mask that defines the allowed placement region.
  case alphaMask(TesseraAlphaMaskRegion)
}

public extension TesseraCanvasRegion {
  /// Creates a polygon region from points in a source space.
  ///
  /// - Parameters:
  ///   - points: Polygon points in a source space. Points are expected to form a simple (non-self-intersecting)
  ///     polygon with at least three points. Polygons with fewer points are treated as empty regions.
  ///   - mapping: Mapping strategy that fits the polygon into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  static func polygon(
    _ points: [CGPoint],
    mapping: TesseraPolygonMapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
  ) -> TesseraCanvasRegion {
    .polygon(points: points, mapping: mapping, padding: padding)
  }

  /// Creates a polygon region by flattening a `CGPath` into line segments.
  ///
  /// Curved segments are approximated by inserting additional points until the curve deviation is below `flatness`.
  ///
  /// - Parameters:
  ///   - path: The path to flatten. If the path contains multiple closed subpaths, the largest one is used.
  ///   - flatness: Maximum deviation in the path's coordinate space when approximating curves.
  ///   - mapping: Mapping strategy that fits the polygon into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  static func polygon(
    _ path: CGPath,
    flatness: CGFloat = 1,
    mapping: TesseraPolygonMapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
  ) -> TesseraCanvasRegion {
    let points = TesseraPathFlattening.largestClosedPolygonPoints(from: path, flatness: flatness)
    return .polygon(points: points, mapping: mapping, padding: padding)
  }
}

/// Describes how polygon points map into the canvas coordinate space.
public enum TesseraPolygonMapping: Sendable, Hashable {
  /// Fits the polygon bounds into the canvas using the provided scaling mode and alignment.
  case fit(mode: TesseraPolygonFitMode, alignment: UnitPoint)
  /// Interprets the polygon points as canvas coordinates without additional mapping.
  case canvasCoordinates
}

/// Defines how polygon bounds scale into the canvas when using a fit mapping.
public enum TesseraPolygonFitMode: Sendable, Hashable {
  /// Preserves aspect ratio, ensuring the polygon fits entirely inside the canvas.
  case aspectFit
  /// Preserves aspect ratio, filling the canvas even if parts of the polygon extend beyond the bounds.
  case aspectFill
  /// Stretches independently on each axis to fill the canvas.
  case stretch
}

// Defines an alpha mask used for placement.

public extension TesseraPolygonMapping {
  /// Compares mapping mode and alignment values.
  static func == (lhs: TesseraPolygonMapping, rhs: TesseraPolygonMapping) -> Bool {
    switch (lhs, rhs) {
    case let (.fit(lhsMode, lhsAlignment), .fit(rhsMode, rhsAlignment)):
      lhsMode == rhsMode &&
        lhsAlignment.x == rhsAlignment.x &&
        lhsAlignment.y == rhsAlignment.y
    case (.canvasCoordinates, .canvasCoordinates):
      true
    default:
      false
    }
  }

  /// Hashes mapping mode and alignment values.
  func hash(into hasher: inout Hasher) {
    switch self {
    case let .fit(mode, alignment):
      hasher.combine(0)
      hasher.combine(mode)
      hasher.combine(alignment.x)
      hasher.combine(alignment.y)
    case .canvasCoordinates:
      hasher.combine(1)
    }
  }
}

struct TesseraResolvedPolygonRegion: Sendable {
  var points: [CGPoint]
  var bounds: CGRect
  var samplingBounds: CGRect
  var area: CGFloat

  func contains(_ point: CGPoint) -> Bool {
    guard points.count >= 3, bounds.contains(point) else { return false }

    var isInside = false
    var j = points.count - 1

    for i in points.indices {
      let pointA = points[i]
      let pointB = points[j]
      let intersects = ((pointA.y > point.y) != (pointB.y > point.y)) &&
        (point.x < (pointB.x - pointA.x) * (point.y - pointA.y) / (pointB.y - pointA.y) + pointA.x)

      if intersects {
        isInside.toggle()
      }

      j = i
    }

    return isInside
  }
}

extension TesseraCanvasRegion {
  var isPolygon: Bool {
    switch self {
    case .rectangle:
      false
    case .polygon:
      true
    case .alphaMask:
      false
    }
  }

  var isAlphaMask: Bool {
    switch self {
    case .alphaMask:
      true
    case .rectangle, .polygon:
      false
    }
  }

  func resolvedPolygon(in canvasSize: CGSize) -> TesseraResolvedPolygonRegion? {
    guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

    switch self {
    case .rectangle:
      return nil
    case let .polygon(points, mapping, padding):
      let resolvedPoints = resolvePoints(points, mapping: mapping, canvasSize: canvasSize, padding: padding)
      guard resolvedPoints.count >= 3, let bounds = bounds(for: resolvedPoints) else {
        return TesseraResolvedPolygonRegion(
          points: [],
          bounds: .null,
          samplingBounds: .null,
          area: 0,
        )
      }

      let samplingBounds = bounds.intersection(CGRect(origin: .zero, size: canvasSize))
      let area = polygonArea(for: resolvedPoints)
      return TesseraResolvedPolygonRegion(
        points: resolvedPoints,
        bounds: bounds,
        samplingBounds: samplingBounds,
        area: area,
      )
    case .alphaMask:
      return nil
    }
  }

  func clipPath(in canvasSize: CGSize) -> Path? {
    guard let region = resolvedPolygon(in: canvasSize) else { return nil }

    return Path { path in
      guard let firstPoint = region.points.first else { return }

      path.move(to: firstPoint)
      for point in region.points.dropFirst() {
        path.addLine(to: point)
      }
      path.closeSubpath()
    }
  }

  private func resolvePoints(
    _ points: [CGPoint],
    mapping: TesseraPolygonMapping,
    canvasSize: CGSize,
    padding: CGFloat,
  ) -> [CGPoint] {
    let clampedPadding = max(padding, 0)
    switch mapping {
    case .canvasCoordinates:
      guard clampedPadding > 0 else { return points }

      return points.map { point in
        CGPoint(x: point.x + clampedPadding, y: point.y + clampedPadding)
      }
    case let .fit(mode, alignment):
      return fitPoints(points, mode: mode, alignment: alignment, canvasSize: canvasSize, padding: clampedPadding)
    }
  }

  private func fitPoints(
    _ points: [CGPoint],
    mode: TesseraPolygonFitMode,
    alignment: UnitPoint,
    canvasSize: CGSize,
    padding: CGFloat,
  ) -> [CGPoint] {
    let availableWidth = max(canvasSize.width - padding * 2, 0)
    let availableHeight = max(canvasSize.height - padding * 2, 0)
    let availableSize = CGSize(width: availableWidth, height: availableHeight)
    guard availableSize.width > 0, availableSize.height > 0 else { return [] }
    guard let bounds = bounds(for: points), bounds.width > 0, bounds.height > 0 else { return [] }

    let scaleX = availableSize.width / bounds.width
    let scaleY = availableSize.height / bounds.height

    let resolvedScaleX: CGFloat
    let resolvedScaleY: CGFloat

    switch mode {
    case .stretch:
      resolvedScaleX = scaleX
      resolvedScaleY = scaleY
    case .aspectFit:
      let scale = min(scaleX, scaleY)
      resolvedScaleX = scale
      resolvedScaleY = scale
    case .aspectFill:
      let scale = max(scaleX, scaleY)
      resolvedScaleX = scale
      resolvedScaleY = scale
    }

    let scaledSize = CGSize(
      width: bounds.width * resolvedScaleX,
      height: bounds.height * resolvedScaleY,
    )

    let origin = CGPoint(
      x: padding + (availableSize.width - scaledSize.width) * alignment.x,
      y: padding + (availableSize.height - scaledSize.height) * alignment.y,
    )

    return points.map { point in
      let translatedX = (point.x - bounds.minX) * resolvedScaleX
      let translatedY = (point.y - bounds.minY) * resolvedScaleY
      return CGPoint(x: origin.x + translatedX, y: origin.y + translatedY)
    }
  }

  private func bounds(for points: [CGPoint]) -> CGRect? {
    guard let firstPoint = points.first else { return nil }

    var minX = firstPoint.x
    var maxX = firstPoint.x
    var minY = firstPoint.y
    var maxY = firstPoint.y

    for point in points.dropFirst() {
      minX = min(minX, point.x)
      maxX = max(maxX, point.x)
      minY = min(minY, point.y)
      maxY = max(maxY, point.y)
    }

    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private func polygonArea(for points: [CGPoint]) -> CGFloat {
    guard points.count >= 3 else { return 0 }

    var sum: CGFloat = 0
    var j = points.count - 1

    for i in points.indices {
      let pointA = points[j]
      let pointB = points[i]
      sum += (pointA.x * pointB.y) - (pointB.x * pointA.y)
      j = i
    }

    return abs(sum) * 0.5
  }
}
