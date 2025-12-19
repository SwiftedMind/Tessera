// By Dennis Müller

import CoreGraphics
@testable import Tessera
import Testing

@Test
func concavePolygonAvoidsNotchCollision() {
  let concavePolygonPoints: [CGPoint] = [
    CGPoint(x: 0, y: 0),
    CGPoint(x: 4, y: 0),
    CGPoint(x: 4, y: 1),
    CGPoint(x: 1, y: 1),
    CGPoint(x: 1, y: 4),
    CGPoint(x: 0, y: 4),
  ]

  let concaveShape = CollisionShape.polygon(points: concavePolygonPoints)
  let concavePolygons = CollisionMath.polygons(for: concaveShape)

  let squareShape = CollisionShape.rectangle(center: .zero, size: CGSize(width: 0.5, height: 0.5))
  let squarePolygons = CollisionMath.polygons(for: squareShape)

  let concaveTransform = CollisionTransform(position: .zero, rotation: 0, scale: 1)
  let squareTransform = CollisionTransform(position: CGPoint(x: 0.5, y: 0.5), rotation: 0, scale: 1)

  let isIntersecting = CollisionMath.polygonsIntersect(
    concavePolygons,
    transformA: concaveTransform,
    squarePolygons,
    transformB: squareTransform,
  )

  #expect(isIntersecting == false)
}

@Test
func multiPolygonCollisionsCheckEachPolygon() {
  let leftPolygonPoints = rectanglePoints(
    centeredAt: CGPoint(x: -2, y: 0),
    size: CGSize(width: 1, height: 1),
  )
  let rightPolygonPoints = rectanglePoints(
    centeredAt: CGPoint(x: 2, y: 0),
    size: CGSize(width: 1, height: 1),
  )

  let multiPolygonShape = CollisionShape.polygons(points: [leftPolygonPoints, rightPolygonPoints])
  let multiPolygons = CollisionMath.polygons(for: multiPolygonShape)

  let testShape = CollisionShape.rectangle(center: .zero, size: CGSize(width: 1, height: 1))
  let testPolygons = CollisionMath.polygons(for: testShape)

  let multiPolygonTransform = CollisionTransform(position: .zero, rotation: 0, scale: 1)

  let middleTransform = CollisionTransform(position: .zero, rotation: 0, scale: 1)
  let isIntersectingAtCenter = CollisionMath.polygonsIntersect(
    multiPolygons,
    transformA: multiPolygonTransform,
    testPolygons,
    transformB: middleTransform,
  )

  let leftTransform = CollisionTransform(position: CGPoint(x: -2, y: 0), rotation: 0, scale: 1)
  let isIntersectingAtLeft = CollisionMath.polygonsIntersect(
    multiPolygons,
    transformA: multiPolygonTransform,
    testPolygons,
    transformB: leftTransform,
  )

  #expect(isIntersectingAtCenter == false)
  #expect(isIntersectingAtLeft == true)
}

@Test
func viewSpacePolygonAutoCentersUsingBounds() {
  let viewSpacePoints: [CGPoint] = [
    CGPoint(x: 0, y: 0),
    CGPoint(x: 4, y: 0),
    CGPoint(x: 4, y: 2),
    CGPoint(x: 0, y: 2),
  ]
  let shape = CollisionShape.polygon(points: viewSpacePoints)
  let pointSets = CollisionMath.polygonPointSets(for: shape)

  let expectedPoints: [CGPoint] = [
    CGPoint(x: -2, y: -1),
    CGPoint(x: 2, y: -1),
    CGPoint(x: 2, y: 1),
    CGPoint(x: -2, y: 1),
  ]

  #expect(pointSets == [expectedPoints])
}

@Test
func viewSpacePolygonAnchorTranslationCentersCorrectly() {
  let viewSpacePoints: [CGPoint] = [
    CGPoint(x: 0, y: 0),
    CGPoint(x: 4, y: 0),
    CGPoint(x: 4, y: 2),
    CGPoint(x: 0, y: 2),
  ]
  let shape = CollisionShape.anchoredPolygon(
    viewPoints: viewSpacePoints,
    anchor: .topLeading,
    size: CGSize(width: 4, height: 2),
  )
  let pointSets = CollisionMath.polygonPointSets(for: shape)

  let expectedPoints: [CGPoint] = [
    CGPoint(x: -2, y: -1),
    CGPoint(x: 2, y: -1),
    CGPoint(x: 2, y: 1),
    CGPoint(x: -2, y: 1),
  ]

  #expect(pointSets == [expectedPoints])
}

private func rectanglePoints(
  centeredAt center: CGPoint,
  size: CGSize,
) -> [CGPoint] {
  let halfWidth = size.width / 2
  let halfHeight = size.height / 2

  return [
    CGPoint(x: center.x - halfWidth, y: center.y - halfHeight),
    CGPoint(x: center.x + halfWidth, y: center.y - halfHeight),
    CGPoint(x: center.x + halfWidth, y: center.y + halfHeight),
    CGPoint(x: center.x - halfWidth, y: center.y + halfHeight),
  ]
}
