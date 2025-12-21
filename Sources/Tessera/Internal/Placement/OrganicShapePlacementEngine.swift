// By Dennis Müller

import CoreGraphics
import Foundation

/// Places symbols using organic rejection sampling with spatial hashing.
enum OrganicShapePlacementEngine {
  typealias PlacementSymbolDescriptor = ShapePlacementEngine.PlacementSymbolDescriptor
  typealias PinnedSymbolDescriptor = ShapePlacementEngine.PinnedSymbolDescriptor
  typealias PlacedSymbolDescriptor = ShapePlacementEngine.PlacedSymbolDescriptor
  typealias PlacedCollider = ShapePlacementEngine.PlacedCollider
  typealias CellCoordinate = ShapePlacementEngine.CellCoordinate

  /// Generates placed symbol descriptors using the organic placement configuration.
  ///
  /// - Parameters:
  ///   - size: The size of the tile to populate with symbols.
  ///   - symbolDescriptors: The available symbols with resolved collision metadata.
  ///   - pinnedSymbolDescriptors: Symbols that must be placed at fixed positions before sampling.
  ///   - edgeBehavior: The edge behavior to apply when testing collisions.
  ///   - configuration: The organic placement configuration.
  ///   - randomGenerator: The random number generator that drives placement.
  /// - Returns: The placed symbol descriptors for the tile.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor],
    edgeBehavior: TesseraEdgeBehavior,
    configuration: TesseraPlacement.Organic,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedSymbolDescriptor] {
    let minimumSpacing = CGFloat(configuration.minimumSpacing)
    let clampedDensity = max(0, min(1, configuration.density))
    let maximumCount = max(0, configuration.maximumSymbolCount)

    let tileArea = Double(size.width * size.height)
    let approximateSymbolArea = max(Double(minimumSpacing * minimumSpacing), 1)
    let estimatedCount = Int(tileArea / approximateSymbolArea * clampedDensity)
    let targetCount = min(max(0, estimatedCount), maximumCount)
    let remainingTargetCount = min(max(0, targetCount - pinnedSymbolDescriptors.count), maximumCount)

    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: edgeBehavior)

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

        guard ShapePlacementCollision.isPlacementValid(
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
      column = ShapePlacementWrapping.wrappedIndex(rawColumn, modulus: gridColumnCount)
      row = ShapePlacementWrapping.wrappedIndex(rawRow, modulus: gridRowCount)
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
            column: ShapePlacementWrapping.wrappedIndex(neighborColumn, modulus: gridColumnCount),
            row: ShapePlacementWrapping.wrappedIndex(neighborRow, modulus: gridRowCount),
          )
        }

        guard let proposedCoordinate else { continue }
        guard visitedCoordinates.insert(proposedCoordinate).inserted else { continue }

        coordinates.append(proposedCoordinate)
      }
    }

    return coordinates
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
}
