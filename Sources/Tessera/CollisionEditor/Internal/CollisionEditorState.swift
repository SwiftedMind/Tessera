// By Dennis Müller

import Observation
import SwiftUI

/// Stores shared state for the collision editor environment.
@Observable
final class CollisionEditorState {
  var renderedContentSize: CGSize = .zero {
    didSet {
      applyInitialCollisionShapeIfNeeded()
    }
  }

  var selectedShapeKind: CollisionEditorShapeKind = .circle
  var polygonSymbolLocalPoints: [CGPoint] = []
  var isPolygonClosed: Bool = false
  var circleCenter: CGPoint = .zero
  var circleRadius: CGFloat = 0.35
  var rectangleCenter: CGPoint = .zero
  var rectangleSize: CGSize = .init(width: 0.7, height: 0.7)
  var initialCollisionShape: CollisionShape? {
    didSet {
      hasAppliedInitialCollisionShape = false
      applyInitialCollisionShapeIfNeeded()
    }
  }

  @ObservationIgnored private var hasAppliedInitialCollisionShape: Bool = false

  init(initialCollisionShape: CollisionShape?) {
    self.initialCollisionShape = initialCollisionShape
  }
}

extension CollisionEditorState {
  var hasPolygonPoints: Bool {
    polygonSymbolLocalPoints.isEmpty == false
  }

  var canClosePolygon: Bool {
    polygonSymbolLocalPoints.count >= 3 && isPolygonClosed == false
  }

  var safeRenderedContentSize: CGSize {
    guard renderedContentSize.width > 0, renderedContentSize.height > 0 else {
      return CGSize(width: 120, height: 120)
    }

    return renderedContentSize
  }

  func undoPolygonPoint() {
    _ = polygonSymbolLocalPoints.popLast()
    if polygonSymbolLocalPoints.count < 3 {
      isPolygonClosed = false
    }
  }

  func clearPolygonPoints() {
    polygonSymbolLocalPoints = []
    isPolygonClosed = false
  }

  func centerCircle() {
    circleCenter = .zero
  }

  func fitCircle() {
    circleCenter = .zero
    circleRadius = 0.5
  }

  func centerRectangle() {
    rectangleCenter = .zero
  }

  func fitRectangle() {
    rectangleCenter = .zero
    rectangleSize = CGSize(width: 1, height: 1)
  }

  func applyInitialCollisionShapeIfNeeded() {
    guard renderedContentSize != .zero else { return }
    guard hasAppliedInitialCollisionShape == false else { return }

    defer { hasAppliedInitialCollisionShape = true }

    guard let initialCollisionShape else {
      selectedShapeKind = .circle
      return
    }

    let clampedWidth = max(safeRenderedContentSize.width, 1)
    let clampedHeight = max(safeRenderedContentSize.height, 1)
    let minimumDimension = min(clampedWidth, clampedHeight)

    switch initialCollisionShape {
    case let .circle(center, radius):
      circleCenter = CGPoint(x: center.x / clampedWidth, y: center.y / clampedHeight)
      circleRadius = radius / minimumDimension
      selectedShapeKind = .circle
    case let .rectangle(center, size):
      rectangleCenter = CGPoint(x: center.x / clampedWidth, y: center.y / clampedHeight)
      rectangleSize = CGSize(width: size.width / clampedWidth, height: size.height / clampedHeight)
      selectedShapeKind = .rectangle
    case let .polygon(points):
      applyViewPolygonPoints(
        points,
        clampedWidth: clampedWidth,
        clampedHeight: clampedHeight,
      )
    case let .polygons(pointSets):
      applyViewPolygonPointSets(
        pointSets,
        clampedWidth: clampedWidth,
        clampedHeight: clampedHeight,
      )
    case let .anchoredPolygon(points, anchor, size):
      applyAnchoredPolygonPoints(
        points,
        anchor: anchor,
        size: size,
        clampedWidth: clampedWidth,
        clampedHeight: clampedHeight,
      )
    case let .anchoredPolygons(pointSets, anchor, size):
      applyAnchoredPolygonPointSets(
        pointSets,
        anchor: anchor,
        size: size,
        clampedWidth: clampedWidth,
        clampedHeight: clampedHeight,
      )
    case let .centeredPolygon(points):
      applyCenteredPolygonPoints(
        points,
        clampedWidth: clampedWidth,
        clampedHeight: clampedHeight,
      )
    case let .centeredPolygons(pointSets):
      applyCenteredPolygonPointSets(
        pointSets,
        clampedWidth: clampedWidth,
        clampedHeight: clampedHeight,
      )
    }
  }

  func addPoint(at displayLocation: CGPoint, using transform: CollisionEditorViewTransform) {
    guard isPolygonClosed == false else { return }

    let symbolLocalPoint = transform.symbolLocalPoint(fromViewPoint: displayLocation)

    if shouldClosePolygon(at: displayLocation, using: transform) {
      isPolygonClosed = true
      return
    }

    polygonSymbolLocalPoints.append(symbolLocalPoint)
  }

  func closePolygon() {
    guard canClosePolygon else { return }

    isPolygonClosed = true
  }

  func movePoint(at index: Int, to displayLocation: CGPoint, using transform: CollisionEditorViewTransform) {
    guard polygonSymbolLocalPoints.indices.contains(index) else { return }

    polygonSymbolLocalPoints[index] = transform.symbolLocalPoint(fromViewPoint: displayLocation)
  }

  func movePolygon(
    from startingSymbolLocalPoints: [CGPoint],
    by displayTranslation: CGSize,
    using transform: CollisionEditorViewTransform,
  ) {
    guard startingSymbolLocalPoints.isEmpty == false else { return }

    let translationInSymbolLocalCoordinates = transform.symbolLocalTranslation(fromViewTranslation: displayTranslation)

    let clampedTranslationInSymbolLocalCoordinates = clampedPolygonTranslation(
      for: startingSymbolLocalPoints,
      proposedTranslation: translationInSymbolLocalCoordinates,
    )

    polygonSymbolLocalPoints = startingSymbolLocalPoints.map { point in
      CGPoint(
        x: point.x + clampedTranslationInSymbolLocalCoordinates.x,
        y: point.y + clampedTranslationInSymbolLocalCoordinates.y,
      )
    }
  }

  func moveCircle(
    from startingCenter: CGPoint,
    by displayTranslation: CGSize,
    using transform: CollisionEditorViewTransform,
  ) {
    let translationInSymbolLocalCoordinates = transform.symbolLocalTranslation(fromViewTranslation: displayTranslation)

    let proposedCenter = CGPoint(
      x: startingCenter.x + translationInSymbolLocalCoordinates.x,
      y: startingCenter.y + translationInSymbolLocalCoordinates.y,
    )

    let clampedCircle = clampedCircle(center: proposedCenter, radius: circleRadius)

    if case let .circle(center, _) = clampedCircle {
      circleCenter = center
    }
  }

  func resizeCircle(
    from startingCenter: CGPoint,
    startingRadius: CGFloat,
    to displayLocation: CGPoint,
    using transform: CollisionEditorViewTransform,
  ) {
    let zoomScale = transform.viewScaleTransform.invertibleScale
    let minimumDimension = min(safeRenderedContentSize.width, safeRenderedContentSize.height)

    let centerDisplayPoint = transform.viewPoint(fromSymbolLocalPoint: startingCenter)
    let displayDistance = hypot(displayLocation.x - centerDisplayPoint.x, displayLocation.y - centerDisplayPoint.y)
    let baseDistance = displayDistance / zoomScale
    let proposedRadius = baseDistance / minimumDimension

    let clampedCircle = clampedCircle(center: startingCenter, radius: proposedRadius)

    if case let .circle(center, radius) = clampedCircle {
      circleCenter = center
      circleRadius = max(radius, 0)
    } else {
      circleRadius = startingRadius
    }
  }

  func moveRectangle(
    from startingCenter: CGPoint,
    by displayTranslation: CGSize,
    using transform: CollisionEditorViewTransform,
  ) {
    let translationInSymbolLocalCoordinates = transform.symbolLocalTranslation(fromViewTranslation: displayTranslation)

    let proposedCenter = CGPoint(
      x: startingCenter.x + translationInSymbolLocalCoordinates.x,
      y: startingCenter.y + translationInSymbolLocalCoordinates.y,
    )

    let clampedRectangle = clampedRectangle(center: proposedCenter, size: rectangleSize)

    if case let .rectangle(center, _) = clampedRectangle {
      rectangleCenter = center
    }
  }

  func resizeRectangle(
    from startingCenter: CGPoint,
    startingSize: CGSize,
    handle: CollisionRectangleEditor.ResizeHandle,
    to displayLocation: CGPoint,
    using transform: CollisionEditorViewTransform,
  ) {
    let draggedCorner = transform.symbolLocalPoint(fromViewPoint: displayLocation)

    let halfWidth = startingSize.width / 2
    let halfHeight = startingSize.height / 2

    let fixedCorner = switch handle {
    case .topLeading:
      CGPoint(x: startingCenter.x + halfWidth, y: startingCenter.y + halfHeight)
    case .topTrailing:
      CGPoint(x: startingCenter.x - halfWidth, y: startingCenter.y + halfHeight)
    case .bottomLeading:
      CGPoint(x: startingCenter.x + halfWidth, y: startingCenter.y - halfHeight)
    case .bottomTrailing:
      CGPoint(x: startingCenter.x - halfWidth, y: startingCenter.y - halfHeight)
    }

    let proposedCenter = CGPoint(
      x: (draggedCorner.x + fixedCorner.x) / 2,
      y: (draggedCorner.y + fixedCorner.y) / 2,
    )

    let proposedSize = CGSize(
      width: abs(draggedCorner.x - fixedCorner.x),
      height: abs(draggedCorner.y - fixedCorner.y),
    )

    let clampedRectangle = clampedRectangle(center: proposedCenter, size: proposedSize)

    if case let .rectangle(center, size) = clampedRectangle {
      rectangleCenter = center
      rectangleSize = size
    }
  }

  private func shouldClosePolygon(at displayLocation: CGPoint, using transform: CollisionEditorViewTransform) -> Bool {
    guard polygonSymbolLocalPoints.count >= 3 else { return false }
    guard let firstPoint = polygonSymbolLocalPoints.first else { return false }

    let firstDisplayPoint = transform.viewPoint(fromSymbolLocalPoint: firstPoint)
    let distance = hypot(displayLocation.x - firstDisplayPoint.x, displayLocation.y - firstDisplayPoint.y)
    return distance <= 16
  }

  private func applyViewPolygonPoints(
    _ points: [CGPoint],
    clampedWidth: CGFloat,
    clampedHeight: CGFloat,
  ) {
    let centeredPoints = CollisionMath.centeredPointsUsingBounds(points)
    applyCenteredPolygonPoints(
      centeredPoints,
      clampedWidth: clampedWidth,
      clampedHeight: clampedHeight,
    )
  }

  private func applyViewPolygonPointSets(
    _ pointSets: [[CGPoint]],
    clampedWidth: CGFloat,
    clampedHeight: CGFloat,
  ) {
    guard let points = pointSets.first else { return }

    applyViewPolygonPoints(points, clampedWidth: clampedWidth, clampedHeight: clampedHeight)
  }

  private func applyAnchoredPolygonPoints(
    _ points: [CGPoint],
    anchor: UnitPoint,
    size: CGSize,
    clampedWidth: CGFloat,
    clampedHeight: CGFloat,
  ) {
    let centeredPoints = CollisionMath.centeredPoints(points, anchor: anchor, size: size)
    applyCenteredPolygonPoints(
      centeredPoints,
      clampedWidth: clampedWidth,
      clampedHeight: clampedHeight,
    )
  }

  private func applyAnchoredPolygonPointSets(
    _ pointSets: [[CGPoint]],
    anchor: UnitPoint,
    size: CGSize,
    clampedWidth: CGFloat,
    clampedHeight: CGFloat,
  ) {
    guard let points = pointSets.first else { return }

    applyAnchoredPolygonPoints(
      points,
      anchor: anchor,
      size: size,
      clampedWidth: clampedWidth,
      clampedHeight: clampedHeight,
    )
  }

  private func applyCenteredPolygonPoints(
    _ centeredPoints: [CGPoint],
    clampedWidth: CGFloat,
    clampedHeight: CGFloat,
  ) {
    polygonSymbolLocalPoints = centeredPoints.map { point in
      CGPoint(x: point.x / clampedWidth, y: point.y / clampedHeight)
    }
    isPolygonClosed = polygonSymbolLocalPoints.count >= 3
    selectedShapeKind = .polygon
  }

  private func applyCenteredPolygonPointSets(
    _ pointSets: [[CGPoint]],
    clampedWidth: CGFloat,
    clampedHeight: CGFloat,
  ) {
    guard let points = pointSets.first else { return }

    applyCenteredPolygonPoints(points, clampedWidth: clampedWidth, clampedHeight: clampedHeight)
  }

  private func clampedPolygonTranslation(for symbolLocalPoints: [CGPoint], proposedTranslation: CGPoint) -> CGPoint {
    guard symbolLocalPoints.isEmpty == false else { return .zero }

    let minimumX = symbolLocalPoints.map(\.x).min() ?? 0
    let maximumX = symbolLocalPoints.map(\.x).max() ?? 0
    let minimumY = symbolLocalPoints.map(\.y).min() ?? 0
    let maximumY = symbolLocalPoints.map(\.y).max() ?? 0

    let minimumAllowedTranslationX = -0.5 - minimumX
    let maximumAllowedTranslationX = 0.5 - maximumX
    let minimumAllowedTranslationY = -0.5 - minimumY
    let maximumAllowedTranslationY = 0.5 - maximumY

    return CGPoint(
      x: min(max(proposedTranslation.x, minimumAllowedTranslationX), maximumAllowedTranslationX),
      y: min(max(proposedTranslation.y, minimumAllowedTranslationY), maximumAllowedTranslationY),
    )
  }

  private func clampedCircle(center: CGPoint, radius: CGFloat) -> CollisionEditorShape {
    let clampedRadius = min(max(radius, 0), 0.5)
    let minimumDimension = min(safeRenderedContentSize.width, safeRenderedContentSize.height)
    let radiusInSymbolLocalX = clampedRadius * minimumDimension / safeRenderedContentSize.width
    let radiusInSymbolLocalY = clampedRadius * minimumDimension / safeRenderedContentSize.height

    let clampedCenterX = min(max(center.x, -0.5 + radiusInSymbolLocalX), 0.5 - radiusInSymbolLocalX)
    let clampedCenterY = min(max(center.y, -0.5 + radiusInSymbolLocalY), 0.5 - radiusInSymbolLocalY)

    return .circle(center: CGPoint(x: clampedCenterX, y: clampedCenterY), radius: clampedRadius)
  }

  private func clampedRectangle(center: CGPoint, size: CGSize) -> CollisionEditorShape {
    let clampedWidth = min(max(size.width, 0), 1)
    let clampedHeight = min(max(size.height, 0), 1)

    let halfWidth = clampedWidth / 2
    let halfHeight = clampedHeight / 2

    let clampedCenterX = min(max(center.x, -0.5 + halfWidth), 0.5 - halfWidth)
    let clampedCenterY = min(max(center.y, -0.5 + halfHeight), 0.5 - halfHeight)

    return .rectangle(
      center: CGPoint(x: clampedCenterX, y: clampedCenterY),
      size: CGSize(width: clampedWidth, height: clampedHeight),
    )
  }
}

extension CollisionEditorState {
  var polygonPointsSnippet: String {
    guard renderedContentSize != .zero else {
      return "Measuring rendered size…"
    }

    let outputTransform = CollisionEditorViewTransform(
      renderedContentSize: safeRenderedContentSize,
      zoomScale: 1,
    )
    let viewPoints = polygonSymbolLocalPoints.map { point in
      outputTransform.viewPoint(fromSymbolLocalPoint: point)
    }
    return pointArraySnippet(for: viewPoints)
  }

  var collisionShapeSnippet: String {
    guard renderedContentSize != .zero else {
      return "Measuring rendered size…"
    }

    switch selectedShapeKind {
    case .polygon:
      return anchoredPolygonSnippet()
    case .circle:
      return circleSnippet()
    case .rectangle:
      return rectangleSnippet()
    }
  }

  private func anchoredPolygonSnippet() -> String {
    let outputTransform = CollisionEditorViewTransform(
      renderedContentSize: safeRenderedContentSize,
      zoomScale: 1,
    )
    let viewPoints = polygonSymbolLocalPoints.map { point in
      outputTransform.viewPoint(fromSymbolLocalPoint: point)
    }
    let pointsSnippet = pointArraySnippet(for: viewPoints)
    let sizeSnippet = sizeSnippet(for: safeRenderedContentSize)

    return """
    .anchoredPolygon(
      points: \(pointsSnippet),
      anchor: .topLeading,
      size: \(sizeSnippet)
    )
    """
  }

  private func circleSnippet() -> String {
    let clampedWidth = max(safeRenderedContentSize.width, 1)
    let clampedHeight = max(safeRenderedContentSize.height, 1)
    let minimumDimension = min(clampedWidth, clampedHeight)

    let center = CGPoint(
      x: circleCenter.x * clampedWidth,
      y: circleCenter.y * clampedHeight,
    )
    let radius = circleRadius * minimumDimension

    return ".circle(center: \(pointSnippet(for: center)), radius: \(formattedNumber(radius)))"
  }

  private func rectangleSnippet() -> String {
    let clampedWidth = max(safeRenderedContentSize.width, 1)
    let clampedHeight = max(safeRenderedContentSize.height, 1)

    let center = CGPoint(
      x: rectangleCenter.x * clampedWidth,
      y: rectangleCenter.y * clampedHeight,
    )
    let size = CGSize(
      width: rectangleSize.width * clampedWidth,
      height: rectangleSize.height * clampedHeight,
    )

    return ".rectangle(center: \(pointSnippet(for: center)), size: \(sizeSnippet(for: size)))"
  }

  private func pointArraySnippet(for points: [CGPoint]) -> String {
    guard points.isEmpty == false else { return "[]" }

    let lines = points.enumerated().map { index, point in
      let suffix = index == points.count - 1 ? "" : ","
      return "  \(pointSnippet(for: point))\(suffix)"
    }

    return """
    [
    \(lines.joined(separator: "\n"))
    ]
    """
  }

  private func pointSnippet(for point: CGPoint) -> String {
    "CGPoint(x: \(formattedNumber(point.x)), y: \(formattedNumber(point.y)))"
  }

  private func sizeSnippet(for size: CGSize) -> String {
    "CGSize(width: \(formattedNumber(size.width)), height: \(formattedNumber(size.height)))"
  }

  private func formattedNumber(_ value: CGFloat) -> String {
    Double(value)
      .formatted(.number.precision(.fractionLength(2)).locale(.init(identifier: "en_US_POSIX")))
  }
}

private enum CollisionEditorShape {
  case circle(center: CGPoint, radius: CGFloat)
  case rectangle(center: CGPoint, size: CGSize)
}
