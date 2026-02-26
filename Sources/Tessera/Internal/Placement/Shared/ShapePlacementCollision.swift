// By Dennis Müller

import CoreGraphics

/// Performs collision tests for candidate symbol placements.
enum ShapePlacementCollision {
  /// Stores precomputed candidate collision data used during validity checks.
  struct PlacementCandidate {
    var collisionShape: CollisionShape
    var collisionTransform: CollisionTransform
    var polygons: [CollisionPolygon]
    var boundingRadius: CGFloat
    var minimumSpacing: CGFloat
  }

  /// Lightweight counters for profiling collision behavior in tests/benchmarks.
  final class Diagnostics {
    var pairChecks = 0
    var circleFastPathChecks = 0
    var polygonChecks = 0
  }

  /// Returns whether a candidate placement clears all existing colliders.
  ///
  /// - Parameters:
  ///   - candidate: The candidate placement to validate.
  ///   - existingColliderIndices: The indices of colliders to test against.
  ///   - allColliders: The full collider store referenced by the indices.
  ///   - tileSize: The size of the tile used for wrap checks.
  ///   - edgeBehavior: The edge behavior that determines wrapping rules.
  ///   - wrapOffsets: The offsets used for wrap-aware collision checks.
  ///   - diagnostics: Optional counters for profiling collision-path behavior.
  /// - Returns: `true` when the candidate does not overlap any collider.
  static func isPlacementValid(
    candidate: PlacementCandidate,
    existingColliderIndices: [Int],
    allColliders: [ShapePlacementEngine.PlacedCollider],
    tileSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
    wrapOffsets: [CGPoint],
    diagnostics: Diagnostics? = nil,
  ) -> Bool {
    guard existingColliderIndices.isEmpty == false else { return true }

    let candidateTransform = candidate.collisionTransform
    let candidatePosition = candidateTransform.position
    let minimumTileHalfDimension = min(tileSize.width, tileSize.height) / 2

    // Check candidate against every already-placed symbol, accounting for wrap offsets.
    for colliderIndex in existingColliderIndices {
      diagnostics?.pairChecks += 1
      let collider = allColliders[colliderIndex]
      let pairMinimumSpacing = max(candidate.minimumSpacing, collider.minimumSpacing)
      let combinedRadius = candidate.boundingRadius + collider.boundingRadius
      let bufferedDistance = combinedRadius + pairMinimumSpacing
      let bufferedDistanceSquared = bufferedDistance * bufferedDistance

      let shouldUseNearestPeriodicImage = switch edgeBehavior {
      case .finite:
        false
      case .seamlessWrapping:
        bufferedDistance < minimumTileHalfDimension
      }

      if edgeBehavior == .finite {
        guard isWithinBufferedDistance(
          candidatePosition: candidatePosition,
          colliderPosition: collider.collisionTransform.position,
          bufferedDistanceSquared: bufferedDistanceSquared,
        ) else { continue }

        if intersects(
          candidate: candidate,
          candidateTransform: candidateTransform,
          collider: collider,
          colliderTransform: collider.collisionTransform,
          pairMinimumSpacing: pairMinimumSpacing,
          diagnostics: diagnostics,
        ) {
          return false
        }
      } else if shouldUseNearestPeriodicImage {
        let offset = nearestPeriodicOffset(
          from: collider.collisionTransform.position,
          to: candidatePosition,
          tileSize: tileSize,
        )
        let shiftedTransform = shiftedTransform(for: collider.collisionTransform, offset: offset)

        // If centers are farther apart than the buffered radii, spacing is satisfied.
        guard isWithinBufferedDistance(
          candidatePosition: candidatePosition,
          colliderPosition: shiftedTransform.position,
          bufferedDistanceSquared: bufferedDistanceSquared,
        ) else { continue }

        if intersects(
          candidate: candidate,
          candidateTransform: candidateTransform,
          collider: collider,
          colliderTransform: shiftedTransform,
          pairMinimumSpacing: pairMinimumSpacing,
          diagnostics: diagnostics,
        ) {
          return false
        }
      } else {
        for offset in wrapOffsets {
          let shiftedTransform = shiftedTransform(for: collider.collisionTransform, offset: offset)

          // If centers are farther apart than the buffered radii, spacing is satisfied.
          guard isWithinBufferedDistance(
            candidatePosition: candidatePosition,
            colliderPosition: shiftedTransform.position,
            bufferedDistanceSquared: bufferedDistanceSquared,
          ) else { continue }

          if intersects(
            candidate: candidate,
            candidateTransform: candidateTransform,
            collider: collider,
            colliderTransform: shiftedTransform,
            pairMinimumSpacing: pairMinimumSpacing,
            diagnostics: diagnostics,
          ) {
            return false
          }
        }
      }
    }

    return true
  }

  private static func isWithinBufferedDistance(
    candidatePosition: CGPoint,
    colliderPosition: CGPoint,
    bufferedDistanceSquared: CGFloat,
  ) -> Bool {
    let deltaX = candidatePosition.x - colliderPosition.x
    let deltaY = candidatePosition.y - colliderPosition.y
    let centerDistanceSquared = deltaX * deltaX + deltaY * deltaY
    return centerDistanceSquared < bufferedDistanceSquared
  }

  private static func shiftedTransform(
    for transform: CollisionTransform,
    offset: CGPoint,
  ) -> CollisionTransform {
    CollisionTransform(
      position: CGPoint(
        x: transform.position.x + offset.x,
        y: transform.position.y + offset.y,
      ),
      rotation: transform.rotation,
      scale: transform.scale,
    )
  }

  private static func intersects(
    candidate: PlacementCandidate,
    candidateTransform: CollisionTransform,
    collider: ShapePlacementEngine.PlacedCollider,
    colliderTransform: CollisionTransform,
    pairMinimumSpacing: CGFloat,
    diagnostics: Diagnostics?,
  ) -> Bool {
    if let circlesIntersect = circlesIntersect(
      candidate: candidate,
      candidateTransform: candidateTransform,
      collider: collider,
      colliderTransform: colliderTransform,
      pairMinimumSpacing: pairMinimumSpacing,
    ) {
      diagnostics?.circleFastPathChecks += 1
      return circlesIntersect
    }

    diagnostics?.polygonChecks += 1
    return CollisionMath.polygonsIntersect(
      candidate.polygons,
      transformA: candidateTransform,
      collider.polygons,
      transformB: colliderTransform,
      buffer: pairMinimumSpacing,
    )
  }

  private static func circlesIntersect(
    candidate: PlacementCandidate,
    candidateTransform: CollisionTransform,
    collider: ShapePlacementEngine.PlacedCollider,
    colliderTransform: CollisionTransform,
    pairMinimumSpacing: CGFloat,
  ) -> Bool? {
    guard case let .circle(candidateCenter, candidateRadius) = candidate.collisionShape,
          case let .circle(colliderCenter, colliderRadius) = collider.collisionShape
    else { return nil }

    let transformedCandidateCenter = CollisionMath.applyTransform(candidateCenter, using: candidateTransform)
    let transformedColliderCenter = CollisionMath.applyTransform(colliderCenter, using: colliderTransform)
    let candidateScaledRadius = candidateRadius * candidateTransform.scale
    let colliderScaledRadius = colliderRadius * colliderTransform.scale
    let bufferedDistance = candidateScaledRadius + colliderScaledRadius + pairMinimumSpacing
    let bufferedDistanceSquared = bufferedDistance * bufferedDistance

    return isWithinBufferedDistance(
      candidatePosition: transformedCandidateCenter,
      colliderPosition: transformedColliderCenter,
      bufferedDistanceSquared: bufferedDistanceSquared,
    )
  }

  /// Returns the nearest periodic offset between two positions in a wrapped tile.
  ///
  /// - Parameters:
  ///   - colliderPosition: The base position of the existing collider.
  ///   - candidatePosition: The position of the candidate symbol.
  ///   - tileSize: The size of the tile used for wrap checks.
  /// - Returns: The offset that brings the collider nearest to the candidate.
  private static func nearestPeriodicOffset(
    from colliderPosition: CGPoint,
    to candidatePosition: CGPoint,
    tileSize: CGSize,
  ) -> CGPoint {
    guard tileSize.width > 0, tileSize.height > 0 else { return .zero }

    let deltaX = candidatePosition.x - colliderPosition.x
    let deltaY = candidatePosition.y - colliderPosition.y

    let offsetX = (deltaX / tileSize.width).rounded() * tileSize.width
    let offsetY = (deltaY / tileSize.height).rounded() * tileSize.height

    return CGPoint(x: offsetX, y: offsetY)
  }
}
