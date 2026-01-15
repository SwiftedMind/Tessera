// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func seamlessWrappingRejectsCollisionsAcrossTileEdges() async throws {
  let size = CGSize(width: 100, height: 100)
  let collisionShape = CollisionShape.circle(center: .zero, radius: 10)
  let polygons = CollisionMath.polygons(for: collisionShape)

  let colliderTransform = CollisionTransform(position: CGPoint(x: 5, y: 50), rotation: 0, scale: 1)
  let collider = ShapePlacementEngine.PlacedCollider(
    collisionShape: collisionShape,
    collisionTransform: colliderTransform,
    polygons: polygons,
    boundingRadius: collisionShape.boundingRadius(atScale: colliderTransform.scale),
  )

  let candidate = ShapePlacementEngine.PlacedSymbolDescriptor(
    symbolId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    position: CGPoint(x: 95, y: 50),
    rotationRadians: 0,
    scale: 1,
    collisionShape: collisionShape,
  )

  let wrappedOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .seamlessWrapping)
  let isValidWhenWrapped = ShapePlacementCollision.isPlacementValid(
    candidate: candidate,
    candidatePolygons: polygons,
    existingColliderIndices: [0],
    allColliders: [collider],
    tileSize: size,
    edgeBehavior: .seamlessWrapping,
    wrapOffsets: wrappedOffsets,
    minimumSpacing: 0,
  )

  let finiteOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .finite)
  let isValidWhenFinite = ShapePlacementCollision.isPlacementValid(
    candidate: candidate,
    candidatePolygons: polygons,
    existingColliderIndices: [0],
    allColliders: [collider],
    tileSize: size,
    edgeBehavior: .finite,
    wrapOffsets: finiteOffsets,
    minimumSpacing: 0,
  )

  #expect(isValidWhenWrapped == false)
  #expect(isValidWhenFinite == true)
}
