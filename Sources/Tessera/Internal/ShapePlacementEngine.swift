// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Places tessera symbols while respecting their approximate collision shapes.
enum ShapePlacementEngine {
  /// Generates placed symbols for a single tile using rejection sampling with wrap-aware collisions.
  static func placeSymbols(
    in size: CGSize,
    configuration: TesseraConfiguration,
    pinnedSymbols: [TesseraPinnedSymbol] = [],
    edgeBehavior: TesseraEdgeBehavior = .seamlessWrapping,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedSymbol] {
    guard !configuration.symbols.isEmpty else { return [] }

    let symbolDescriptors = configuration.symbols.map { symbol in
      let scaleRange = symbol.scaleRange ?? configuration.baseScaleRange
      return PlacementSymbolDescriptor(
        id: symbol.id,
        weight: symbol.weight,
        allowedRotationRangeDegrees: symbol.allowedRotationRange.lowerBound.degrees...symbol.allowedRotationRange.upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: symbol.collisionShape,
      )
    }

    let pinnedSymbolDescriptors = pinnedSymbols.map { pinnedSymbol in
      PinnedSymbolDescriptor(
        id: pinnedSymbol.id,
        position: pinnedSymbol.resolvedPosition(in: size),
        rotationRadians: pinnedSymbol.rotation.radians,
        scale: pinnedSymbol.scale,
        collisionShape: pinnedSymbol.collisionShape,
      )
    }

    let placedDescriptors = placeSymbolDescriptors(
      in: size,
      symbolDescriptors: symbolDescriptors,
      pinnedSymbolDescriptors: pinnedSymbolDescriptors,
      edgeBehavior: edgeBehavior,
      minimumSpacing: configuration.minimumSpacing,
      density: configuration.density,
      maximumSymbolCount: configuration.maximumSymbolCount,
      randomGenerator: &randomGenerator,
    )

    let symbolLookup: [UUID: TesseraSymbol] = configuration.symbols.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = symbol
    }

    return placedDescriptors.compactMap { descriptor in
      guard let symbol = symbolLookup[descriptor.symbolId] else { return nil }

      return PlacedSymbol(
        symbol: symbol,
        position: descriptor.position,
        rotation: .radians(descriptor.rotationRadians),
        scale: descriptor.scale,
      )
    }
  }

  /// Generates placed symbol descriptors without capturing SwiftUI view builders.
  ///
  /// This is safe to run on a background task and is used by `TesseraCanvas` caching.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor] = [],
    edgeBehavior: TesseraEdgeBehavior = .seamlessWrapping,
    minimumSpacing: Double,
    density: Double,
    maximumSymbolCount: Int,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedSymbolDescriptor] {
    guard !symbolDescriptors.isEmpty else { return [] }

    let minimumSpacing = CGFloat(minimumSpacing)

    let tileArea = Double(size.width * size.height)
    let approximateSymbolArea = max(Double(minimumSpacing * minimumSpacing), 1)
    let clampedDensity = max(0, min(1, density))
    let estimatedCount = Int(tileArea / approximateSymbolArea * clampedDensity)
    let maximumCount = max(0, maximumSymbolCount)
    let targetCount = min(max(0, estimatedCount), maximumCount)
    let remainingTargetCount = min(max(0, targetCount - pinnedSymbolDescriptors.count), maximumCount)

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

    let fixedColliders: [PlacedCollider] = pinnedSymbolDescriptors.map { pinnedSymbol in
      let collisionTransform = CollisionTransform(
        position: pinnedSymbol.position,
        rotation: CGFloat(pinnedSymbol.rotationRadians),
        scale: pinnedSymbol.scale,
      )
      return PlacedCollider(
        collisionShape: pinnedSymbol.collisionShape,
        collisionTransform: collisionTransform,
        polygons: CollisionMath.polygons(for: pinnedSymbol.collisionShape),
        boundingRadius: pinnedSymbol.collisionShape.boundingRadius(atScale: collisionTransform.scale),
      )
    }

    let maximumGeneratedBoundingRadius = maximumBoundingRadius(
      for: symbolDescriptors,
    )
    let maximumFixedBoundingRadius = pinnedSymbolDescriptors
      .map { pinnedSymbol in
        pinnedSymbol.collisionShape.boundingRadius(atScale: pinnedSymbol.scale)
      }
      .max() ?? 0
    let maximumBoundingRadius = max(maximumGeneratedBoundingRadius, maximumFixedBoundingRadius)
    let maximumInteractionDistance = maximumBoundingRadius * 2 + minimumSpacing
    let cellSize = max(maximumInteractionDistance, 1)
    let gridColumnCount = max(1, Int(ceil(size.width / cellSize)))
    let gridRowCount = max(1, Int(ceil(size.height / cellSize)))

    let polygonCache: [UUID: [CollisionPolygon]] = symbolDescriptors.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = CollisionMath.polygons(for: symbol.collisionShape)
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

    var placedDescriptors: [PlacedSymbolDescriptor] = []
    placedDescriptors.reserveCapacity(remainingTargetCount)

    for _ in 0..<remainingTargetCount {
      if Task.isCancelled { return placedDescriptors }

      guard let selectedSymbol = pickSymbol(from: symbolDescriptors, using: &randomGenerator) else { break }

      let scale = Double.random(in: selectedSymbol.resolvedScaleRange, using: &randomGenerator)
      let rotationRadians = randomAngleRadians(
        in: selectedSymbol.allowedRotationRangeDegrees,
        using: &randomGenerator,
      )

      guard let selectedPolygons = polygonCache[selectedSymbol.id] else { continue }

      let maximumAttempts = 20
      var didPlaceSymbol = false

      for _ in 0..<maximumAttempts {
        if Task.isCancelled { return placedDescriptors }

        // Rejection-sample a position and reuse if it clears all collisions.
        let position = randomPoint(in: size, using: &randomGenerator)
        let candidate = PlacedSymbolDescriptor(
          symbolId: selectedSymbol.id,
          position: position,
          rotationRadians: rotationRadians,
          scale: CGFloat(scale),
          collisionShape: selectedSymbol.collisionShape,
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
          candidatePolygons: selectedPolygons,
          existingColliderIndices: neighboringColliderIndices,
          allColliders: colliders,
          tileSize: size,
          edgeBehavior: edgeBehavior,
          wrapOffsets: wrapOffsets,
          minimumSpacing: minimumSpacing,
        ) else { continue }

        placedDescriptors.append(candidate)
        let candidateTransform = candidate.collisionTransform
        colliders.append(
          PlacedCollider(
            collisionShape: selectedSymbol.collisionShape,
            collisionTransform: candidateTransform,
            polygons: selectedPolygons,
            boundingRadius: selectedSymbol.collisionShape.boundingRadius(atScale: candidateTransform.scale),
          ),
        )
        let newColliderIndex = colliders.count - 1
        colliderGrid[candidateCoordinate, default: []].append(newColliderIndex)
        didPlaceSymbol = true
        break
      }

      if !didPlaceSymbol {
        continue
      }
    }

    return placedDescriptors
  }

  struct PlacementSymbolDescriptor: Sendable {
    var id: UUID
    var weight: Double
    var allowedRotationRangeDegrees: ClosedRange<Double>
    var resolvedScaleRange: ClosedRange<Double>
    var collisionShape: CollisionShape
  }

  struct PinnedSymbolDescriptor: Sendable {
    var id: UUID
    var position: CGPoint
    var rotationRadians: Double
    var scale: CGFloat
    var collisionShape: CollisionShape
  }

  struct PlacedSymbolDescriptor: Sendable {
    var symbolId: UUID
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
    var polygons: [CollisionPolygon]
    var boundingRadius: CGFloat
  }

  private struct CellCoordinate: Hashable, Sendable {
    var column: Int
    var row: Int
  }

  private static func maximumBoundingRadius(
    for symbols: [PlacementSymbolDescriptor],
  ) -> CGFloat {
    var maximumRadius: CGFloat = 0
    for symbol in symbols {
      let maximumScale = symbol.resolvedScaleRange.upperBound
      let radius = symbol.collisionShape.boundingRadius(atScale: CGFloat(maximumScale))
      maximumRadius = max(maximumRadius, radius)
    }
    return maximumRadius
  }

  private static func cellCoordinate(
    for position: CGPoint,
    cellSize: CGFloat,
    gridColumnCount: Int,
    gridRowCount: Int,
    edgeBehavior: TesseraEdgeBehavior,
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
    edgeBehavior: TesseraEdgeBehavior,
  ) -> [CellCoordinate] {
    let offsetRange: ClosedRange<Int> = switch edgeBehavior {
    case .finite:
      -1...1
    case .seamlessWrapping:
      // In seamless wrapping mode, colliders can interact across tile boundaries (toroidal distance).
      // When the tile size is not an exact multiple of `cellSize`, the band within one `cellSize` of an edge can span
      // two grid columns/rows. Expanding the neighbor range to 5×5 ensures we do not miss wrap-adjacent colliders
      // that end up in the second-to-last column/row.
      -2...2
    }

    var coordinates: [CellCoordinate] = []
    coordinates
      .reserveCapacity((offsetRange.upperBound - offsetRange.lowerBound + 1) *
        (offsetRange.upperBound - offsetRange.lowerBound + 1))

    var visitedCoordinates: Set<CellCoordinate> = []
    visitedCoordinates.reserveCapacity(coordinates.capacity)

    for rowOffset in offsetRange {
      for columnOffset in offsetRange {
        let neighborColumn = coordinate.column + columnOffset
        let neighborRow = coordinate.row + rowOffset

        let proposedCoordinate: CellCoordinate? = switch edgeBehavior {
        case .finite:
          if (0..<gridColumnCount).contains(neighborColumn),
             (0..<gridRowCount).contains(neighborRow) {
            CellCoordinate(column: neighborColumn, row: neighborRow)
          } else {
            nil
          }
        case .seamlessWrapping:
          CellCoordinate(
            column: wrappedIndex(neighborColumn, modulus: gridColumnCount),
            row: wrappedIndex(neighborRow, modulus: gridRowCount),
          )
        }

        guard let proposedCoordinate else { continue }
        guard visitedCoordinates.insert(proposedCoordinate).inserted else { continue }

        coordinates.append(proposedCoordinate)
      }
    }

    return coordinates
  }

  private static func wrappedIndex(_ index: Int, modulus: Int) -> Int {
    guard modulus > 0 else { return 0 }

    let remainder = index % modulus
    return remainder >= 0 ? remainder : remainder + modulus
  }

  private static func pickSymbol(
    from symbols: [PlacementSymbolDescriptor],
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> PlacementSymbolDescriptor? {
    // Weighted pick to preserve caller-defined symbol frequencies.
    let totalWeight = symbols.reduce(0) { $0 + $1.weight }
    guard totalWeight > 0 else { return symbols.randomElement(using: &randomGenerator) }

    let randomValue = Double.random(in: 0..<totalWeight, using: &randomGenerator)
    var accumulator = 0.0

    for symbol in symbols {
      accumulator += symbol.weight
      if randomValue < accumulator { return symbol }
    }

    return symbols.last
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
    candidate: PlacedSymbolDescriptor,
    candidatePolygons: [CollisionPolygon],
    existingColliderIndices: [Int],
    allColliders: [PlacedCollider],
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
