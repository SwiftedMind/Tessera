// By Dennis Müller

import CoreGraphics

/// Performs collision tests for candidate symbol placements.
enum ShapePlacementCollision {
  /// Returns whether a candidate placement clears all existing colliders.
  ///
  /// - Parameters:
  ///   - candidate: The candidate placement to validate.
  ///   - candidatePolygons: The collision polygons for the candidate symbol.
  ///   - existingColliderIndices: The indices of colliders to test against.
  ///   - allColliders: The full collider store referenced by the indices.
  ///   - tileSize: The size of the tile used for wrap checks.
  ///   - edgeBehavior: The edge behavior that determines wrapping rules.
  ///   - wrapOffsets: The offsets used for wrap-aware collision checks.
  ///   - minimumSpacing: The extra spacing buffer to enforce.
  /// - Returns: `true` when the candidate does not overlap any collider.
  static func isPlacementValid(
    candidate: ShapePlacementEngine.PlacedSymbolDescriptor,
    candidatePolygons: [CollisionPolygon],
    existingColliderIndices: [Int],
    allColliders: [ShapePlacementEngine.PlacedCollider],
    tileSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
    wrapOffsets: [CGPoint],
    minimumSpacing: CGFloat,
  ) -> Bool {
    let candidateBoundingRadius = candidate.collisionShape.boundingRadius(atScale: candidate.collisionTransform.scale)
    let candidatePosition = candidate.collisionTransform.position
    let minimumTileHalfDimension = min(tileSize.width, tileSize.height) / 2

    // Check candidate against every already-placed symbol, accounting for wrap offsets.
    for colliderIndex in existingColliderIndices {
      let collider = allColliders[colliderIndex]
      let colliderBoundingRadius = collider.boundingRadius
      let combinedRadius = candidateBoundingRadius + colliderBoundingRadius
      let bufferedDistance = combinedRadius + minimumSpacing
      let bufferedDistanceSquared = bufferedDistance * bufferedDistance

      let shouldUseNearestPeriodicImage = switch edgeBehavior {
      case .finite:
        true
      case .seamlessWrapping:
        bufferedDistance < minimumTileHalfDimension
      }

      if shouldUseNearestPeriodicImage {
        let offset = nearestPeriodicOffset(
          from: collider.collisionTransform.position,
          to: candidatePosition,
          tileSize: tileSize,
          edgeBehavior: edgeBehavior,
        )

        let shiftedPosition = CGPoint(
          x: collider.collisionTransform.position.x + offset.x,
          y: collider.collisionTransform.position.y + offset.y,
        )
        let deltaX = candidatePosition.x - shiftedPosition.x
        let deltaY = candidatePosition.y - shiftedPosition.y
        let centerDistanceSquared = deltaX * deltaX + deltaY * deltaY

        // If centers are farther apart than the buffered radii, spacing is satisfied.
        guard centerDistanceSquared < bufferedDistanceSquared else { continue }

        let shiftedTransform = CollisionTransform(
          position: shiftedPosition,
          rotation: collider.collisionTransform.rotation,
          scale: collider.collisionTransform.scale,
        )

        // Within the buffered range, run the narrow-phase polygon test with spacing buffer.
        if CollisionMath.polygonsIntersect(
          candidatePolygons,
          transformA: candidate.collisionTransform,
          collider.polygons,
          transformB: shiftedTransform,
          buffer: minimumSpacing,
        ) { return false }
      } else {
        for offset in wrapOffsets {
          let shiftedPosition = CGPoint(
            x: collider.collisionTransform.position.x + offset.x,
            y: collider.collisionTransform.position.y + offset.y,
          )
          let deltaX = candidatePosition.x - shiftedPosition.x
          let deltaY = candidatePosition.y - shiftedPosition.y
          let centerDistanceSquared = deltaX * deltaX + deltaY * deltaY

          // If centers are farther apart than the buffered radii, spacing is satisfied.
          guard centerDistanceSquared < bufferedDistanceSquared else { continue }

          let shiftedTransform = CollisionTransform(
            position: shiftedPosition,
            rotation: collider.collisionTransform.rotation,
            scale: collider.collisionTransform.scale,
          )

          // Within the buffered range, run the narrow-phase polygon test with spacing buffer.
          if CollisionMath.polygonsIntersect(
            candidatePolygons,
            transformA: candidate.collisionTransform,
            collider.polygons,
            transformB: shiftedTransform,
            buffer: minimumSpacing,
          ) { return false }
        }
      }
    }

    return true
  }

  /// Returns the nearest periodic offset between two positions in a wrapped tile.
  ///
  /// - Parameters:
  ///   - colliderPosition: The base position of the existing collider.
  ///   - candidatePosition: The position of the candidate symbol.
  ///   - tileSize: The size of the tile used for wrap checks.
  ///   - edgeBehavior: The edge behavior that determines wrapping rules.
  /// - Returns: The offset that brings the collider nearest to the candidate.
  private static func nearestPeriodicOffset(
    from colliderPosition: CGPoint,
    to candidatePosition: CGPoint,
    tileSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
  ) -> CGPoint {
    guard edgeBehavior == .seamlessWrapping else { return .zero }
    guard tileSize.width > 0, tileSize.height > 0 else { return .zero }

    let deltaX = candidatePosition.x - colliderPosition.x
    let deltaY = candidatePosition.y - colliderPosition.y

    let offsetX = (deltaX / tileSize.width).rounded() * tileSize.width
    let offsetY = (deltaY / tileSize.height).rounded() * tileSize.height

    return CGPoint(x: offsetX, y: offsetY)
  }
}
