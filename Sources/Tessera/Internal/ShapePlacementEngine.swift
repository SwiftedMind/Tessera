// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Places tessera items while respecting their approximate collision shapes.
enum ShapePlacementEngine {
  /// Generates placed items for a single tile using rejection sampling with wrap-aware collisions.
  @MainActor
  static func placeItems(
    in size: CGSize,
    tessera: Tessera,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedItem] {
    guard !tessera.items.isEmpty else { return [] }

    let tileArea = size.width * size.height
    let approximateItemArea = max(tessera.minimumSpacing * tessera.minimumSpacing, 1)
    let clampedDensity = max(0, min(1, tessera.density))
    let estimatedCount = Int(tileArea / approximateItemArea * clampedDensity)
    let maximumCount = 512
    let targetCount = min(max(0, estimatedCount), maximumCount)

    // Wrap offsets cover the 3×3 lattice to maintain seamless wrapping collisions.
    let wrapOffsets: [CGPoint] = [
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

    var placedItems: [PlacedItem] = []
    placedItems.reserveCapacity(targetCount)

    let polygonCache: [UUID: [CGPoint]] = tessera.items.reduce(into: [:]) { cache, item in
      cache[item.id] = CollisionMath.polygonPoints(for: item.collisionShape)
    }

    for _ in 0..<targetCount {
      guard let selectedItem = pickItem(from: tessera.items, using: &randomGenerator) else { break }

      let scaleRange = selectedItem.scaleRange ?? tessera.baseScaleRange
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
          existingItems: placedItems,
          polygonCache: polygonCache,
          wrapOffsets: wrapOffsets,
          minimumSpacing: tessera.minimumSpacing,
        ) else { continue }

        placedItems.append(candidate)
        didPlaceItem = true
        break
      }

      if !didPlaceItem {
        continue
      }
    }

    return placedItems
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
    return .degrees(Double.random(in: lower..<upper, using: &randomGenerator))
  }

  private static func isPlacementValid(
    candidate: PlacedItem,
    candidatePolygon: [CGPoint],
    existingItems: [PlacedItem],
    polygonCache: [UUID: [CGPoint]],
    wrapOffsets: [CGPoint],
    minimumSpacing: CGFloat,
  ) -> Bool {
    // Check candidate against every already-placed item, accounting for wrap offsets.
    for placedItem in existingItems {
      guard let placedPolygon = polygonCache[placedItem.item.id] else { continue }

      for offset in wrapOffsets {
        let shiftedTransform = CollisionTransform(
          position: CGPoint(
            x: placedItem.collisionTransform.position.x + offset.x,
            y: placedItem.collisionTransform.position.y + offset.y,
          ),
          rotation: placedItem.collisionTransform.rotation,
          scale: placedItem.collisionTransform.scale,
        )

        let candidateRadius = candidate.item.collisionShape.boundingRadius(atScale: candidate.collisionTransform.scale)
        let placedRadius = placedItem.item.collisionShape.boundingRadius(atScale: shiftedTransform.scale)
        let combinedRadius = candidateRadius + placedRadius
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
          placedPolygon,
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
