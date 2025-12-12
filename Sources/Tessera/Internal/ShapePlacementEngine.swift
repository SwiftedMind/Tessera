// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Places tessera items while respecting their approximate collision shapes.
enum ShapePlacementEngine {
  /// Generates placed items for a single tile using rejection sampling with wrap-aware collisions.
  static func placeItems(
    in size: CGSize,
    configuration: TesseraConfiguration,
    fixedPlacements: [TesseraFixedPlacement] = [],
    edgeBehavior: TesseraCanvasEdgeBehavior = .seamlessWrapping,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedItem] {
    guard !configuration.items.isEmpty else { return [] }

    let tileArea = size.width * size.height
    let approximateItemArea = max(configuration.minimumSpacing * configuration.minimumSpacing, 1)
    let clampedDensity = max(0, min(1, configuration.density))
    let estimatedCount = Int(tileArea / approximateItemArea * clampedDensity)
    let maximumCount = max(0, configuration.maximumItemCount)
    let targetCount = min(max(0, estimatedCount), maximumCount)
    let remainingTargetCount = min(max(0, targetCount - fixedPlacements.count), maximumCount)

    // Wrap offsets cover the 3×3 lattice to maintain seamless wrapping collisions.
    let wrapOffsets: [CGPoint] = switch edgeBehavior {
    case .finite:
      [.init(x: 0, y: 0)]
    case .seamlessWrapping:
      [
        .init(x: 0, y: 0),
        .init(x: size.width, y: 0),
        .init(x: -size.width, y: 0),
        .init(x: 0, y: size.height),
        .init(x: 0, y: -size.height),
        .init(x: size.width, y: size.height),
        .init(x: size.width, y: -size.height),
        .init(x: -size.width, y: size.height),
        .init(x: -size.width, y: -size.height),
      ]
    }

    var placedItems: [PlacedItem] = []
    placedItems.reserveCapacity(remainingTargetCount)

    let fixedColliders: [PlacedCollider] = fixedPlacements.map { placement in
      PlacedCollider(
        collisionShape: placement.collisionShape,
        collisionTransform: CollisionTransform(
          position: placement.position,
          rotation: CGFloat(placement.rotation.radians),
          scale: placement.scale,
        ),
        polygon: CollisionMath.polygonPoints(for: placement.collisionShape),
      )
    }

    let polygonCache: [UUID: [CGPoint]] = configuration.items.reduce(into: [:]) { cache, item in
      cache[item.id] = CollisionMath.polygonPoints(for: item.collisionShape)
    }

    var colliders: [PlacedCollider] = fixedColliders
    colliders.reserveCapacity(fixedColliders.count + remainingTargetCount)

    for _ in 0..<remainingTargetCount {
      guard let selectedItem = pickItem(from: configuration.items, using: &randomGenerator) else { break }

      let scaleRange = selectedItem.scaleRange ?? configuration.baseScaleRange
      let scale = Double.random(in: scaleRange, using: &randomGenerator)
      let rotation = randomAngle(in: selectedItem.allowedRotationRange, using: &randomGenerator)

      guard let selectedPolygon = polygonCache[selectedItem.id] else { continue }

      let maximumAttempts = 20
      var didPlaceItem = false

      for _ in 0..<maximumAttempts {
        // Rejection-sample a position and reuse if it clears all collisions.
        let position = randomPoint(in: size, using: &randomGenerator)
        let candidate = PlacedItem(
          item: selectedItem,
          position: position,
          rotation: rotation,
          scale: scale,
        )

        guard isPlacementValid(
          candidate: candidate,
          candidatePolygon: selectedPolygon,
          existingColliders: colliders,
          wrapOffsets: wrapOffsets,
          minimumSpacing: configuration.minimumSpacing,
        ) else { continue }

        placedItems.append(candidate)
        colliders.append(
          PlacedCollider(
            collisionShape: selectedItem.collisionShape,
            collisionTransform: candidate.collisionTransform,
            polygon: selectedPolygon,
          ),
        )
        didPlaceItem = true
        break
      }

      if !didPlaceItem {
        continue
      }
    }

    return placedItems
  }

  private struct PlacedCollider {
    var collisionShape: CollisionShape
    var collisionTransform: CollisionTransform
    var polygon: [CGPoint]
  }

  private static func pickItem(
    from items: [TesseraItem],
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> TesseraItem? {
    // Weighted pick to preserve caller-defined item frequencies.
    let totalWeight = items.reduce(0) { $0 + $1.weight }
    guard totalWeight > 0 else { return items.randomElement(using: &randomGenerator) }

    let randomValue = Double.random(in: 0..<totalWeight, using: &randomGenerator)
    var accumulator = 0.0

    for item in items {
      accumulator += item.weight
      if randomValue < accumulator { return item }
    }

    return items.last
  }

  private static func randomPoint(
    in size: CGSize,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> CGPoint {
    CGPoint(
      x: CGFloat.random(in: 0..<size.width, using: &randomGenerator),
      y: CGFloat.random(in: 0..<size.height, using: &randomGenerator),
    )
  }

  private static func randomAngle(
    in range: ClosedRange<Angle>,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> Angle {
    let lower = range.lowerBound.degrees
    let upper = range.upperBound.degrees
    guard upper > lower else {
      return .degrees(lower)
    }

    return .degrees(Double.random(in: lower...upper, using: &randomGenerator))
  }

  private static func isPlacementValid(
    candidate: PlacedItem,
    candidatePolygon: [CGPoint],
    existingColliders: [PlacedCollider],
    wrapOffsets: [CGPoint],
    minimumSpacing: CGFloat,
  ) -> Bool {
    // Check candidate against every already-placed item, accounting for wrap offsets.
    for collider in existingColliders {
      for offset in wrapOffsets {
        let shiftedTransform = CollisionTransform(
          position: CGPoint(
            x: collider.collisionTransform.position.x + offset.x,
            y: collider.collisionTransform.position.y + offset.y,
          ),
          rotation: collider.collisionTransform.rotation,
          scale: collider.collisionTransform.scale,
        )

        let candidateRadius = candidate.item.collisionShape.boundingRadius(atScale: candidate.collisionTransform.scale)
        let colliderRadius = collider.collisionShape.boundingRadius(atScale: shiftedTransform.scale)
        let combinedRadius = candidateRadius + colliderRadius
        let bufferedDistance = combinedRadius + minimumSpacing
        let bufferedDistanceSquared = bufferedDistance * bufferedDistance

        let deltaX = candidate.collisionTransform.position.x - shiftedTransform.position.x
        let deltaY = candidate.collisionTransform.position.y - shiftedTransform.position.y
        let centerDistanceSquared = deltaX * deltaX + deltaY * deltaY

        // If centers are farther apart than the buffered radii, spacing is satisfied.
        guard centerDistanceSquared < bufferedDistanceSquared else { continue }

        // Within the buffered range, run the narrow-phase polygon test with spacing buffer.
        if CollisionMath.polygonsIntersect(
          candidatePolygon,
          transformA: candidate.collisionTransform,
          collider.polygon,
          transformB: shiftedTransform,
          buffer: minimumSpacing,
        ) {
          return false
        }
      }
    }

    return true
  }
}
