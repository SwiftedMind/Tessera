// By Dennis Müller

import CoreGraphics

/// Performs collision tests for candidate symbol placements.
enum ShapePlacementCollision {
  /// Stores transformed circle geometry for fast circle-circle narrow phase.
  private struct TransformedCircle {
    var center: CGPoint
    var radius: CGFloat
  }

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
    var broadPhaseRejects = 0
    var circleFastPathChecks = 0
    var polygonChecks = 0
    var placementOuterAttempts = 0
    var placementSuccesses = 0
    var placementSuccessesUsingRescue = 0
    var placementFailures = 0
    var terminatedForSaturation = false
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
    let candidateCircle = transformedCircle(
      for: candidate.collisionShape,
      transform: candidateTransform,
    )
    let minimumTileHalfDimension = min(tileSize.width, tileSize.height) / 2

    // Check candidate against every already-placed symbol, accounting for wrap offsets.
    for colliderIndex in existingColliderIndices {
      diagnostics?.pairChecks += 1
      let collider = allColliders[colliderIndex]
      let colliderPosition = collider.collisionTransform.position
      let colliderCircle = transformedCircle(
        for: collider.collisionShape,
        transform: collider.collisionTransform,
      )
      let pairMinimumSpacing = max(candidate.minimumSpacing, collider.minimumSpacing)
      let combinedRadius = abs(candidate.boundingRadius) + abs(collider.boundingRadius)
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
          colliderPosition: colliderPosition,
          bufferedDistanceSquared: bufferedDistanceSquared,
        ) else {
          diagnostics?.broadPhaseRejects += 1
          continue
        }

        if intersects(
          candidate: candidate,
          candidateTransform: candidateTransform,
          candidateCircle: candidateCircle,
          collider: collider,
          colliderTransform: collider.collisionTransform,
          colliderCircle: colliderCircle,
          colliderOffset: .zero,
          pairMinimumSpacing: pairMinimumSpacing,
          diagnostics: diagnostics,
        ) {
          return false
        }
      } else if shouldUseNearestPeriodicImage {
        let offset = nearestPeriodicOffset(
          from: colliderPosition,
          to: candidatePosition,
          tileSize: tileSize,
        )
        let shiftedPosition = CGPoint(
          x: colliderPosition.x + offset.x,
          y: colliderPosition.y + offset.y,
        )

        // If centers are farther apart than the buffered radii, spacing is satisfied.
        guard isWithinBufferedDistance(
          candidatePosition: candidatePosition,
          colliderPosition: shiftedPosition,
          bufferedDistanceSquared: bufferedDistanceSquared,
        ) else {
          diagnostics?.broadPhaseRejects += 1
          continue
        }

        if intersects(
          candidate: candidate,
          candidateTransform: candidateTransform,
          candidateCircle: candidateCircle,
          collider: collider,
          colliderTransform: collider.collisionTransform,
          colliderCircle: colliderCircle,
          colliderOffset: offset,
          pairMinimumSpacing: pairMinimumSpacing,
          diagnostics: diagnostics,
        ) {
          return false
        }
      } else {
        for offset in wrapOffsets {
          let shiftedPosition = CGPoint(
            x: colliderPosition.x + offset.x,
            y: colliderPosition.y + offset.y,
          )

          // If centers are farther apart than the buffered radii, spacing is satisfied.
          guard isWithinBufferedDistance(
            candidatePosition: candidatePosition,
            colliderPosition: shiftedPosition,
            bufferedDistanceSquared: bufferedDistanceSquared,
          ) else {
            diagnostics?.broadPhaseRejects += 1
            continue
          }

          if intersects(
            candidate: candidate,
            candidateTransform: candidateTransform,
            candidateCircle: candidateCircle,
            collider: collider,
            colliderTransform: collider.collisionTransform,
            colliderCircle: colliderCircle,
            colliderOffset: offset,
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
    candidateCircle: TransformedCircle?,
    collider: ShapePlacementEngine.PlacedCollider,
    colliderTransform: CollisionTransform,
    colliderCircle: TransformedCircle?,
    colliderOffset: CGPoint,
    pairMinimumSpacing: CGFloat,
    diagnostics: Diagnostics?,
  ) -> Bool {
    if let circlesIntersect = circlesIntersect(
      candidateCircle: candidateCircle,
      colliderCircle: colliderCircle,
      colliderOffset: colliderOffset,
      pairMinimumSpacing: pairMinimumSpacing,
    ) {
      diagnostics?.circleFastPathChecks += 1
      return circlesIntersect
    }

    diagnostics?.polygonChecks += 1
    let shiftedColliderTransform: CollisionTransform = if colliderOffset == .zero {
      colliderTransform
    } else {
      shiftedTransform(for: colliderTransform, offset: colliderOffset)
    }
    return CollisionMath.polygonsIntersect(
      candidate.polygons,
      transformA: candidateTransform,
      collider.polygons,
      transformB: shiftedColliderTransform,
      buffer: pairMinimumSpacing,
    )
  }

  private static func transformedCircle(
    for collisionShape: CollisionShape,
    transform: CollisionTransform,
  ) -> TransformedCircle? {
    guard case let .circle(center, radius) = collisionShape else { return nil }

    return TransformedCircle(
      center: CollisionMath.applyTransform(center, using: transform),
      radius: radius * abs(transform.scale),
    )
  }

  private static func circlesIntersect(
    candidateCircle: TransformedCircle?,
    colliderCircle: TransformedCircle?,
    colliderOffset: CGPoint,
    pairMinimumSpacing: CGFloat,
  ) -> Bool? {
    guard let candidateCircle, let colliderCircle else { return nil }

    let shiftedColliderCenter = CGPoint(
      x: colliderCircle.center.x + colliderOffset.x,
      y: colliderCircle.center.y + colliderOffset.y,
    )
    let bufferedDistance = candidateCircle.radius + colliderCircle.radius + pairMinimumSpacing
    let bufferedDistanceSquared = bufferedDistance * bufferedDistance

    return isWithinBufferedDistance(
      candidatePosition: candidateCircle.center,
      colliderPosition: shiftedColliderCenter,
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
