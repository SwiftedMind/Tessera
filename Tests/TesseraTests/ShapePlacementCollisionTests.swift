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
    minimumSpacing: 0,
  )

  let candidate = ShapePlacementEngine.PlacedSymbolDescriptor(
    symbolId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    position: CGPoint(x: 95, y: 50),
    rotationRadians: 0,
    scale: 1,
    collisionShape: collisionShape,
  )
  let candidateCollision = ShapePlacementCollision.PlacementCandidate(
    collisionShape: candidate.collisionShape,
    collisionTransform: candidate.collisionTransform,
    polygons: polygons,
    boundingRadius: candidate.collisionShape.boundingRadius(atScale: candidate.collisionTransform.scale),
    minimumSpacing: 0,
  )

  let wrappedOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .seamlessWrapping)
  let isValidWhenWrapped = ShapePlacementCollision.isPlacementValid(
    candidate: candidateCollision,
    existingColliderIndices: [0],
    allColliders: [collider],
    tileSize: size,
    edgeBehavior: .seamlessWrapping,
    wrapOffsets: wrappedOffsets,
  )

  let finiteOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .finite)
  let isValidWhenFinite = ShapePlacementCollision.isPlacementValid(
    candidate: candidateCollision,
    existingColliderIndices: [0],
    allColliders: [collider],
    tileSize: size,
    edgeBehavior: .finite,
    wrapOffsets: finiteOffsets,
  )

  #expect(isValidWhenWrapped == false)
  #expect(isValidWhenFinite == true)
}

@Test func circleCollisionFastPathSkipsPolygonNarrowPhase() async throws {
  let size = CGSize(width: 100, height: 100)
  let collisionShape = CollisionShape.circle(center: .zero, radius: 10)
  let polygons = CollisionMath.polygons(for: collisionShape)

  let colliderTransform = CollisionTransform(position: CGPoint(x: 20, y: 50), rotation: 0, scale: 1)
  let collider = ShapePlacementEngine.PlacedCollider(
    collisionShape: collisionShape,
    collisionTransform: colliderTransform,
    polygons: polygons,
    boundingRadius: collisionShape.boundingRadius(atScale: colliderTransform.scale),
    minimumSpacing: 0,
  )

  let candidateCollision = ShapePlacementCollision.PlacementCandidate(
    collisionShape: collisionShape,
    collisionTransform: CollisionTransform(position: CGPoint(x: 30, y: 50), rotation: 0, scale: 1),
    polygons: polygons,
    boundingRadius: collisionShape.boundingRadius(atScale: 1),
    minimumSpacing: 0,
  )
  let diagnostics = ShapePlacementCollision.Diagnostics()

  let isValid = ShapePlacementCollision.isPlacementValid(
    candidate: candidateCollision,
    existingColliderIndices: [0],
    allColliders: [collider],
    tileSize: size,
    edgeBehavior: .finite,
    wrapOffsets: ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .finite),
    diagnostics: diagnostics,
  )

  #expect(isValid == false)
  #expect(diagnostics.pairChecks == 1)
  #expect(diagnostics.circleFastPathChecks == 1)
  #expect(diagnostics.polygonChecks == 0)
}

@Test func mixedShapeCollisionFallsBackToPolygonNarrowPhase() async throws {
  let size = CGSize(width: 100, height: 100)
  let candidateShape = CollisionShape.circle(center: .zero, radius: 10)
  let candidatePolygons = CollisionMath.polygons(for: candidateShape)

  let colliderShape = CollisionShape.rectangle(center: .zero, size: CGSize(width: 18, height: 18))
  let colliderTransform = CollisionTransform(position: CGPoint(x: 35, y: 50), rotation: 0, scale: 1)
  let collider = ShapePlacementEngine.PlacedCollider(
    collisionShape: colliderShape,
    collisionTransform: colliderTransform,
    polygons: CollisionMath.polygons(for: colliderShape),
    boundingRadius: colliderShape.boundingRadius(atScale: colliderTransform.scale),
    minimumSpacing: 0,
  )

  let candidateCollision = ShapePlacementCollision.PlacementCandidate(
    collisionShape: candidateShape,
    collisionTransform: CollisionTransform(position: CGPoint(x: 30, y: 50), rotation: 0, scale: 1),
    polygons: candidatePolygons,
    boundingRadius: candidateShape.boundingRadius(atScale: 1),
    minimumSpacing: 0,
  )
  let diagnostics = ShapePlacementCollision.Diagnostics()

  let isValid = ShapePlacementCollision.isPlacementValid(
    candidate: candidateCollision,
    existingColliderIndices: [0],
    allColliders: [collider],
    tileSize: size,
    edgeBehavior: .finite,
    wrapOffsets: ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .finite),
    diagnostics: diagnostics,
  )

  #expect(isValid == false)
  #expect(diagnostics.pairChecks == 1)
  #expect(diagnostics.circleFastPathChecks == 0)
  #expect(diagnostics.polygonChecks == 1)
}
