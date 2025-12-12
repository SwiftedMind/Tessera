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

    let itemDescriptors = configuration.items.map { item in
      let scaleRange = item.scaleRange ?? configuration.baseScaleRange
      return PlacementItemDescriptor(
        id: item.id,
        weight: item.weight,
        allowedRotationRangeDegrees: item.allowedRotationRange.lowerBound.degrees...item.allowedRotationRange.upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: item.collisionShape,
      )
    }

    let fixedPlacementDescriptors = fixedPlacements.map { placement in
      FixedPlacementDescriptor(
        id: placement.id,
        position: placement.position,
        rotationRadians: placement.rotation.radians,
        scale: placement.scale,
        collisionShape: placement.collisionShape,
      )
    }

    let placedDescriptors = placeItemDescriptors(
      in: size,
      itemDescriptors: itemDescriptors,
      fixedPlacementDescriptors: fixedPlacementDescriptors,
      edgeBehavior: edgeBehavior,
      minimumSpacing: configuration.minimumSpacing,
      density: configuration.density,
      maximumItemCount: configuration.maximumItemCount,
      randomGenerator: &randomGenerator,
    )

    let itemLookup: [UUID: TesseraItem] = configuration.items.reduce(into: [:]) { cache, item in
      cache[item.id] = item
    }

    return placedDescriptors.compactMap { descriptor in
      guard let item = itemLookup[descriptor.itemId] else { return nil }

      return PlacedItem(
        item: item,
        position: descriptor.position,
        rotation: .radians(descriptor.rotationRadians),
        scale: descriptor.scale,
      )
    }
  }

  /// Generates placed item descriptors without capturing SwiftUI view builders.
  ///
  /// This is safe to run on a background task and is used by `TesseraCanvas` caching.
  static func placeItemDescriptors(
    in size: CGSize,
    itemDescriptors: [PlacementItemDescriptor],
    fixedPlacementDescriptors: [FixedPlacementDescriptor] = [],
    edgeBehavior: TesseraCanvasEdgeBehavior = .seamlessWrapping,
    minimumSpacing: Double,
    density: Double,
    maximumItemCount: Int,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedItemDescriptor] {
    guard !itemDescriptors.isEmpty else { return [] }

    let minimumSpacing = CGFloat(minimumSpacing)

    let tileArea = Double(size.width * size.height)
    let approximateItemArea = max(Double(minimumSpacing * minimumSpacing), 1)
    let clampedDensity = max(0, min(1, density))
    let estimatedCount = Int(tileArea / approximateItemArea * clampedDensity)
    let maximumCount = max(0, maximumItemCount)
    let targetCount = min(max(0, estimatedCount), maximumCount)
    let remainingTargetCount = min(max(0, targetCount - fixedPlacementDescriptors.count), maximumCount)

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

    let fixedColliders: [PlacedCollider] = fixedPlacementDescriptors.map { placement in
      PlacedCollider(
        collisionShape: placement.collisionShape,
        collisionTransform: CollisionTransform(
          position: placement.position,
          rotation: CGFloat(placement.rotationRadians),
          scale: placement.scale,
        ),
        polygon: CollisionMath.polygonPoints(for: placement.collisionShape),
      )
    }

    let maximumGeneratedBoundingRadius = maximumBoundingRadius(
      for: itemDescriptors,
    )
    let maximumFixedBoundingRadius = fixedPlacementDescriptors
      .map { placement in
        placement.collisionShape.boundingRadius(atScale: placement.scale)
      }
      .max() ?? 0
    let maximumBoundingRadius = max(maximumGeneratedBoundingRadius, maximumFixedBoundingRadius)
    let maximumInteractionDistance = maximumBoundingRadius * 2 + minimumSpacing
    let cellSize = max(maximumInteractionDistance, 1)
    let gridColumnCount = max(1, Int(ceil(size.width / cellSize)))
    let gridRowCount = max(1, Int(ceil(size.height / cellSize)))

    let polygonCache: [UUID: [CGPoint]] = itemDescriptors.reduce(into: [:]) { cache, item in
      cache[item.id] = CollisionMath.polygonPoints(for: item.collisionShape)
    }

    var colliders: [PlacedCollider] = fixedColliders
    colliders.reserveCapacity(fixedColliders.count + remainingTargetCount)
    var colliderGrid: [CellCoordinate: [Int]] = [:]
    colliderGrid.reserveCapacity(fixedColliders.count + remainingTargetCount)

    for colliderIndex in colliders.indices {
      let collider = colliders[colliderIndex]
      let coordinate = cellCoordinate(
        for: collider.collisionTransform.position,
        cellSize: cellSize,
        gridColumnCount: gridColumnCount,
        gridRowCount: gridRowCount,
        edgeBehavior: edgeBehavior,
      )
      colliderGrid[coordinate, default: []].append(colliderIndex)
    }

    var placedDescriptors: [PlacedItemDescriptor] = []
    placedDescriptors.reserveCapacity(remainingTargetCount)

    for _ in 0..<remainingTargetCount {
      if Task.isCancelled { return placedDescriptors }

      guard let selectedItem = pickItem(from: itemDescriptors, using: &randomGenerator) else { break }

      let scale = Double.random(in: selectedItem.resolvedScaleRange, using: &randomGenerator)
      let rotationRadians = randomAngleRadians(
        in: selectedItem.allowedRotationRangeDegrees,
        using: &randomGenerator,
      )

      guard let selectedPolygon = polygonCache[selectedItem.id] else { continue }

      let maximumAttempts = 20
      var didPlaceItem = false

      for _ in 0..<maximumAttempts {
        if Task.isCancelled { return placedDescriptors }

        // Rejection-sample a position and reuse if it clears all collisions.
        let position = randomPoint(in: size, using: &randomGenerator)
        let candidate = PlacedItemDescriptor(
          itemId: selectedItem.id,
          position: position,
          rotationRadians: rotationRadians,
          scale: CGFloat(scale),
          collisionShape: selectedItem.collisionShape,
        )

        let candidateCoordinate = cellCoordinate(
          for: position,
          cellSize: cellSize,
          gridColumnCount: gridColumnCount,
          gridRowCount: gridRowCount,
          edgeBehavior: edgeBehavior,
        )
        let neighboringCoordinates = neighboringCellCoordinates(
          around: candidateCoordinate,
          gridColumnCount: gridColumnCount,
          gridRowCount: gridRowCount,
          edgeBehavior: edgeBehavior,
        )

        var neighboringColliderIndices: [Int] = []
        neighboringColliderIndices.reserveCapacity(32)
        for coordinate in neighboringCoordinates {
          if let indices = colliderGrid[coordinate] {
            neighboringColliderIndices.append(contentsOf: indices)
          }
        }

        guard isPlacementValid(
          candidate: candidate,
          candidatePolygon: selectedPolygon,
          existingColliderIndices: neighboringColliderIndices,
          allColliders: colliders,
          wrapOffsets: wrapOffsets,
          minimumSpacing: minimumSpacing,
        ) else { continue }

        placedDescriptors.append(candidate)
        colliders.append(
          PlacedCollider(
            collisionShape: selectedItem.collisionShape,
            collisionTransform: candidate.collisionTransform,
            polygon: selectedPolygon,
          ),
        )
        let newColliderIndex = colliders.count - 1
        let newColliderCoordinate = cellCoordinate(
          for: position,
          cellSize: cellSize,
          gridColumnCount: gridColumnCount,
          gridRowCount: gridRowCount,
          edgeBehavior: edgeBehavior,
        )
        colliderGrid[newColliderCoordinate, default: []].append(newColliderIndex)
        didPlaceItem = true
        break
      }

      if !didPlaceItem {
        continue
      }
    }

    return placedDescriptors
  }

  struct PlacementItemDescriptor: Sendable {
    var id: UUID
    var weight: Double
    var allowedRotationRangeDegrees: ClosedRange<Double>
    var resolvedScaleRange: ClosedRange<Double>
    var collisionShape: CollisionShape
  }

  struct FixedPlacementDescriptor: Sendable {
    var id: UUID
    var position: CGPoint
    var rotationRadians: Double
    var scale: CGFloat
    var collisionShape: CollisionShape
  }

  struct PlacedItemDescriptor: Sendable {
    var itemId: UUID
    var position: CGPoint
    var rotationRadians: Double
    var scale: CGFloat
    var collisionShape: CollisionShape

    var collisionTransform: CollisionTransform {
      CollisionTransform(
        position: position,
        rotation: CGFloat(rotationRadians),
        scale: scale,
      )
    }
  }

  private struct PlacedCollider: Sendable {
    var collisionShape: CollisionShape
    var collisionTransform: CollisionTransform
    var polygon: [CGPoint]
  }

  private struct CellCoordinate: Hashable, Sendable {
    var column: Int
    var row: Int
  }

  private static func maximumBoundingRadius(
    for items: [PlacementItemDescriptor],
  ) -> CGFloat {
    var maximumRadius: CGFloat = 0
    for item in items {
      let maximumScale = item.resolvedScaleRange.upperBound
      let radius = item.collisionShape.boundingRadius(atScale: CGFloat(maximumScale))
      maximumRadius = max(maximumRadius, radius)
    }
    return maximumRadius
  }

  private static func cellCoordinate(
    for position: CGPoint,
    cellSize: CGFloat,
    gridColumnCount: Int,
    gridRowCount: Int,
    edgeBehavior: TesseraCanvasEdgeBehavior,
  ) -> CellCoordinate {
    let rawColumn = Int(floor(position.x / cellSize))
    let rawRow = Int(floor(position.y / cellSize))

    let column: Int
    let row: Int
    switch edgeBehavior {
    case .finite:
      column = max(0, min(gridColumnCount - 1, rawColumn))
      row = max(0, min(gridRowCount - 1, rawRow))
    case .seamlessWrapping:
      column = wrappedIndex(rawColumn, modulus: gridColumnCount)
      row = wrappedIndex(rawRow, modulus: gridRowCount)
    }

    return CellCoordinate(column: column, row: row)
  }

  private static func neighboringCellCoordinates(
    around coordinate: CellCoordinate,
    gridColumnCount: Int,
    gridRowCount: Int,
    edgeBehavior: TesseraCanvasEdgeBehavior,
  ) -> [CellCoordinate] {
    var coordinates: [CellCoordinate] = []
    coordinates.reserveCapacity(9)

    for rowOffset in -1...1 {
      for columnOffset in -1...1 {
        let neighborColumn = coordinate.column + columnOffset
        let neighborRow = coordinate.row + rowOffset

        switch edgeBehavior {
        case .finite:
          guard (0..<gridColumnCount).contains(neighborColumn),
                (0..<gridRowCount).contains(neighborRow)
          else { continue }

          coordinates.append(CellCoordinate(column: neighborColumn, row: neighborRow))
        case .seamlessWrapping:
          coordinates.append(
            CellCoordinate(
              column: wrappedIndex(neighborColumn, modulus: gridColumnCount),
              row: wrappedIndex(neighborRow, modulus: gridRowCount),
            ),
          )
        }
      }
    }

    return coordinates
  }

  private static func wrappedIndex(_ index: Int, modulus: Int) -> Int {
    guard modulus > 0 else { return 0 }

    let remainder = index % modulus
    return remainder >= 0 ? remainder : remainder + modulus
  }

  private static func pickItem(
    from items: [PlacementItemDescriptor],
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> PlacementItemDescriptor? {
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

  private static func randomAngleRadians(
    in rangeDegrees: ClosedRange<Double>,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> Double {
    let lower = rangeDegrees.lowerBound
    let upper = rangeDegrees.upperBound
    guard upper > lower else {
      return lower * Double.pi / 180
    }

    let degrees = Double.random(in: lower...upper, using: &randomGenerator)
    return degrees * Double.pi / 180
  }

  private static func isPlacementValid(
    candidate: PlacedItemDescriptor,
    candidatePolygon: [CGPoint],
    existingColliderIndices: [Int],
    allColliders: [PlacedCollider],
    wrapOffsets: [CGPoint],
    minimumSpacing: CGFloat,
  ) -> Bool {
    // Check candidate against every already-placed item, accounting for wrap offsets.
    for colliderIndex in existingColliderIndices {
      let collider = allColliders[colliderIndex]
      for offset in wrapOffsets {
        let shiftedTransform = CollisionTransform(
          position: CGPoint(
            x: collider.collisionTransform.position.x + offset.x,
            y: collider.collisionTransform.position.y + offset.y,
          ),
          rotation: collider.collisionTransform.rotation,
          scale: collider.collisionTransform.scale,
        )

        let candidateRadius = candidate.collisionShape.boundingRadius(atScale: candidate.collisionTransform.scale)
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
