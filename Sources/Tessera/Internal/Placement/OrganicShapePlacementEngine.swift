// By Dennis Müller

import CoreGraphics
import Foundation

/// Places symbols using organic rejection sampling with spatial hashing.
enum OrganicShapePlacementEngine {
  typealias PlacementSymbolDescriptor = ShapePlacementEngine.PlacementSymbolDescriptor
  typealias PinnedSymbolDescriptor = ShapePlacementEngine.PinnedSymbolDescriptor
  typealias PlacedSymbolDescriptor = ShapePlacementEngine.PlacedSymbolDescriptor
  typealias PlacedCollider = ShapePlacementEngine.PlacedCollider

  /// Generates placed symbol descriptors using the organic placement configuration.
  ///
  /// - Parameters:
  ///   - size: The size of the tile to populate with symbols.
  ///   - symbolDescriptors: The available symbols with resolved collision metadata.
  ///   - pinnedSymbolDescriptors: Symbols that must be placed at fixed positions before sampling.
  ///   - edgeBehavior: The edge behavior to apply when testing collisions.
  ///   - configuration: The organic placement configuration.
  ///   - region: Optional polygon region in tile space used to constrain placement.
  ///   - alphaMask: Optional alpha mask used to constrain placement.
  ///   - randomGenerator: The random number generator that drives placement.
  ///   - diagnostics: Optional collision diagnostics for profiling.
  /// - Returns: The placed symbol descriptors for the tile.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor],
    edgeBehavior: TesseraEdgeBehavior,
    configuration: PlacementModel.Organic,
    region: TesseraResolvedPolygonRegion? = nil,
    alphaMask: TesseraAlphaMask? = nil,
    randomGenerator: inout some RandomNumberGenerator,
    diagnostics: ShapePlacementCollision.Diagnostics? = nil,
  ) -> [PlacedSymbolDescriptor] {
    let baseMinimumSpacing = CGFloat(max(0, configuration.minimumSpacing))
    let maximumSpacingMultiplier = max(
      0,
      ShapePlacementSteering.maximumValue(
        for: configuration.steering.minimumSpacingMultiplier,
        defaultValue: 1,
      ),
    )
    let maximumMinimumSpacing = baseMinimumSpacing * CGFloat(maximumSpacingMultiplier)
    let maximumScaleMultiplier = max(
      0,
      ShapePlacementSteering.maximumValue(
        for: configuration.steering.scaleMultiplier,
        defaultValue: 1,
      ),
    )
    let clampedDensity = max(0, min(1, configuration.density))
    let maximumCount = max(0, configuration.maximumSymbolCount)

    let tileArea = Double(size.width * size.height)
    let regionArea = region.map { Double($0.area) } ?? tileArea
    let maskArea = alphaMask.map { Double($0.filledFraction) * tileArea } ?? tileArea
    let constrainedArea = min(regionArea, maskArea)
    let approximateSymbolArea = max(Double(maximumMinimumSpacing * maximumMinimumSpacing), 1)
    let estimatedCount = Int(constrainedArea / approximateSymbolArea * clampedDensity)
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
        minimumSpacing: 0,
      )
    }

    let maximumGeneratedBoundingRadius = maximumBoundingRadius(
      for: symbolDescriptors,
      maximumScaleMultiplier: CGFloat(maximumScaleMultiplier),
    )
    let maximumFixedBoundingRadius = pinnedSymbolDescriptors
      .map { pinnedSymbol in
        pinnedSymbol.collisionShape.boundingRadius(atScale: pinnedSymbol.scale)
      }
      .max() ?? 0
    let maximumBoundingRadius = max(maximumGeneratedBoundingRadius, maximumFixedBoundingRadius)
    let maximumInteractionDistance = maximumBoundingRadius * 2 + maximumMinimumSpacing
    let cellSize = max(maximumInteractionDistance, 1)
    let gridColumnCount = max(1, Int(ceil(size.width / cellSize)))
    let gridRowCount = max(1, Int(ceil(size.height / cellSize)))

    let renderableLeafDescriptors = symbolDescriptors.flatMap(\.renderableLeafDescriptors)
    let polygonCache: [UUID: [CollisionPolygon]] = renderableLeafDescriptors.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = CollisionMath.polygons(for: symbol.collisionShape)
    }

    var colliders: [PlacedCollider] = fixedColliders
    colliders.reserveCapacity(fixedColliders.count + remainingTargetCount)

    var spatialIndex = OrganicSpatialIndex(
      gridColumnCount: gridColumnCount,
      gridRowCount: gridRowCount,
      edgeBehavior: edgeBehavior,
    )

    for colliderIndex in colliders.indices {
      spatialIndex.append(
        colliderIndex: colliderIndex,
        at: colliders[colliderIndex].collisionTransform.position,
        cellSize: cellSize,
      )
    }

    var placedDescriptors: [PlacedSymbolDescriptor] = []
    placedDescriptors.reserveCapacity(remainingTargetCount)
    var choiceSequenceState = ShapePlacementEngine.ChoiceSequenceState()
    var neighboringColliderIndices: [Int] = []
    neighboringColliderIndices.reserveCapacity(32)

    for placementAttemptIndex in 0..<remainingTargetCount {
      if Task.isCancelled { return placedDescriptors }

      guard let selectedSymbol = pickSymbol(from: symbolDescriptors, using: &randomGenerator) else { break }

      let choiceSeed = organicChoiceSeed(
        baseSeed: configuration.seed,
        placementAttemptIndex: placementAttemptIndex,
        symbolID: selectedSymbol.id,
        symbolChoiceSeed: selectedSymbol.choiceSeed,
      )
      var choiceRandomGenerator = SeededGenerator(seed: choiceSeed)
      var tentativeChoiceSequenceState = choiceSequenceState
      guard let selectedRenderSymbol = ShapePlacementEngine.resolveLeafSymbolDescriptor(
        from: selectedSymbol,
        randomGenerator: &choiceRandomGenerator,
        sequenceState: &tentativeChoiceSequenceState,
      ) else { continue }

      let baseScale = Double.random(in: selectedRenderSymbol.resolvedScaleRange, using: &randomGenerator)
      let baseRotationRadians = randomAngleRadians(
        in: selectedRenderSymbol.allowedRotationRangeDegrees,
        using: &randomGenerator,
      )

      guard let selectedPolygons = polygonCache[selectedRenderSymbol.id] else { continue }

      let maximumAttempts = 20
      var didPlaceSymbol = false

      for _ in 0..<maximumAttempts {
        if Task.isCancelled { return placedDescriptors }

        // Rejection-sample a position and reuse if it clears all collisions.
        guard let position = randomPoint(in: size, region: region, using: &randomGenerator) else { continue }

        if let alphaMask, alphaMask.contains(position) == false {
          continue
        }

        let spacingMultiplier = max(
          0,
          ShapePlacementSteering.value(
            for: configuration.steering.minimumSpacingMultiplier,
            position: position,
            canvasSize: size,
            defaultValue: 1,
          ),
        )
        let candidateMinimumSpacing = baseMinimumSpacing * CGFloat(spacingMultiplier)
        let scaleMultiplier = max(
          0,
          ShapePlacementSteering.value(
            for: configuration.steering.scaleMultiplier,
            position: position,
            canvasSize: size,
            defaultValue: 1,
          ),
        )
        let scale = max(0, baseScale * scaleMultiplier)
        let rotationMultiplier = max(
          0,
          ShapePlacementSteering.value(
            for: configuration.steering.rotationMultiplier,
            position: position,
            canvasSize: size,
            defaultValue: 1,
          ),
        )
        let rotationOffsetDegrees = ShapePlacementSteering.value(
          for: configuration.steering.rotationOffsetDegrees,
          position: position,
          canvasSize: size,
          defaultValue: 0,
        )
        let rotationOffsetRadians = rotationOffsetDegrees * Double.pi / 180
        let rotationRadians = baseRotationRadians * rotationMultiplier + rotationOffsetRadians

        let candidateTransform = CollisionTransform(
          position: position,
          rotation: CGFloat(rotationRadians),
          scale: CGFloat(scale),
        )
        let candidateCollisionShape = selectedRenderSymbol.collisionShape
        let candidateCollision = ShapePlacementCollision.PlacementCandidate(
          collisionShape: candidateCollisionShape,
          collisionTransform: candidateTransform,
          polygons: selectedPolygons,
          boundingRadius: candidateCollisionShape.boundingRadius(atScale: candidateTransform.scale),
          minimumSpacing: candidateMinimumSpacing,
        )

        let candidateCellIndex = spatialIndex.cellIndex(for: position, cellSize: cellSize)
        neighboringColliderIndices.removeAll(keepingCapacity: true)
        spatialIndex.appendNeighboringColliderIndices(
          around: candidateCellIndex,
          to: &neighboringColliderIndices,
        )

        guard ShapePlacementCollision.isPlacementValid(
          candidate: candidateCollision,
          existingColliderIndices: neighboringColliderIndices,
          allColliders: colliders,
          tileSize: size,
          edgeBehavior: edgeBehavior,
          wrapOffsets: wrapOffsets,
          diagnostics: diagnostics,
        ) else { continue }

        choiceSequenceState = tentativeChoiceSequenceState

        let candidate = PlacedSymbolDescriptor(
          symbolId: selectedSymbol.id,
          renderSymbolId: selectedRenderSymbol.id,
          position: position,
          rotationRadians: rotationRadians,
          scale: CGFloat(scale),
          collisionShape: candidateCollisionShape,
        )
        placedDescriptors.append(candidate)

        colliders.append(
          PlacedCollider(
            collisionShape: candidateCollisionShape,
            collisionTransform: candidateTransform,
            polygons: selectedPolygons,
            boundingRadius: candidateCollision.boundingRadius,
            minimumSpacing: candidateMinimumSpacing,
          ),
        )
        let newColliderIndex = colliders.count - 1
        spatialIndex.append(colliderIndex: newColliderIndex, at: position, cellSize: cellSize)

        didPlaceSymbol = true
        break
      }

      if !didPlaceSymbol {
        continue
      }
    }

    return placedDescriptors
  }

  private struct OrganicSpatialIndex {
    let gridColumnCount: Int
    let gridRowCount: Int
    let edgeBehavior: TesseraEdgeBehavior
    var colliderIndicesByCellIndex: [[Int]]
    let neighboringCellIndicesByCellIndex: [[Int]]

    init(
      gridColumnCount: Int,
      gridRowCount: Int,
      edgeBehavior: TesseraEdgeBehavior,
    ) {
      self.gridColumnCount = gridColumnCount
      self.gridRowCount = gridRowCount
      self.edgeBehavior = edgeBehavior

      let totalCellCount = gridColumnCount * gridRowCount
      colliderIndicesByCellIndex = Array(repeating: [], count: totalCellCount)
      neighboringCellIndicesByCellIndex = Self.makeNeighboringCellIndicesByCellIndex(
        gridColumnCount: gridColumnCount,
        gridRowCount: gridRowCount,
        edgeBehavior: edgeBehavior,
      )
    }

    mutating func append(
      colliderIndex: Int,
      at position: CGPoint,
      cellSize: CGFloat,
    ) {
      let index = cellIndex(for: position, cellSize: cellSize)
      colliderIndicesByCellIndex[index].append(colliderIndex)
    }

    func appendNeighboringColliderIndices(
      around cellIndex: Int,
      to output: inout [Int],
    ) {
      let neighboringCellIndices = neighboringCellIndicesByCellIndex[cellIndex]
      for neighboringCellIndex in neighboringCellIndices {
        output.append(contentsOf: colliderIndicesByCellIndex[neighboringCellIndex])
      }
    }

    func cellIndex(
      for position: CGPoint,
      cellSize: CGFloat,
    ) -> Int {
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

      return Self.cellIndex(row: row, column: column, gridColumnCount: gridColumnCount)
    }

    private static func makeNeighboringCellIndicesByCellIndex(
      gridColumnCount: Int,
      gridRowCount: Int,
      edgeBehavior: TesseraEdgeBehavior,
    ) -> [[Int]] {
      let totalCellCount = gridColumnCount * gridRowCount
      var neighboringCellIndicesByCellIndex = Array(
        repeating: [Int](),
        count: totalCellCount,
      )

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

      for row in 0..<gridRowCount {
        for column in 0..<gridColumnCount {
          var neighboringCellIndices: [Int] = []
          neighboringCellIndices.reserveCapacity(
            (offsetRange.upperBound - offsetRange.lowerBound + 1) *
              (offsetRange.upperBound - offsetRange.lowerBound + 1),
          )

          var visitedCellIndices: Set<Int> = []
          visitedCellIndices.reserveCapacity(neighboringCellIndices.capacity)

          for rowOffset in offsetRange {
            for columnOffset in offsetRange {
              let neighboringColumn = column + columnOffset
              let neighboringRow = row + rowOffset

              let resolvedColumn: Int
              let resolvedRow: Int
              switch edgeBehavior {
              case .finite:
                guard (0..<gridColumnCount).contains(neighboringColumn),
                      (0..<gridRowCount).contains(neighboringRow)
                else { continue }

                resolvedColumn = neighboringColumn
                resolvedRow = neighboringRow
              case .seamlessWrapping:
                resolvedColumn = ShapePlacementWrapping.wrappedIndex(
                  neighboringColumn,
                  modulus: gridColumnCount,
                )
                resolvedRow = ShapePlacementWrapping.wrappedIndex(
                  neighboringRow,
                  modulus: gridRowCount,
                )
              }

              let neighboringCellIndex = cellIndex(
                row: resolvedRow,
                column: resolvedColumn,
                gridColumnCount: gridColumnCount,
              )
              guard visitedCellIndices.insert(neighboringCellIndex).inserted else { continue }

              neighboringCellIndices.append(neighboringCellIndex)
            }
          }

          neighboringCellIndicesByCellIndex[cellIndex(
            row: row,
            column: column,
            gridColumnCount: gridColumnCount,
          )] = neighboringCellIndices
        }
      }

      return neighboringCellIndicesByCellIndex
    }

    private static func cellIndex(
      row: Int,
      column: Int,
      gridColumnCount: Int,
    ) -> Int {
      row * gridColumnCount + column
    }
  }

  private static func organicChoiceSeed(
    baseSeed: UInt64,
    placementAttemptIndex: Int,
    symbolID: UUID,
    symbolChoiceSeed: UInt64?,
  ) -> UInt64 {
    let bytes = symbolID.uuid
    let upper = UInt64(bytes.0) << 56 | UInt64(bytes.1) << 48 | UInt64(bytes.2) << 40 | UInt64(bytes.3) << 32 |
      UInt64(bytes.4) << 24 | UInt64(bytes.5) << 16 | UInt64(bytes.6) << 8 | UInt64(bytes.7)
    let lower = UInt64(bytes.8) << 56 | UInt64(bytes.9) << 48 | UInt64(bytes.10) << 40 | UInt64(bytes.11) << 32 |
      UInt64(bytes.12) << 24 | UInt64(bytes.13) << 16 | UInt64(bytes.14) << 8 | UInt64(bytes.15)

    var seed = baseSeed &* 0xA076_1D64_78BD_642F
    seed ^= UInt64(truncatingIfNeeded: placementAttemptIndex) &* 0x94D0_49BB_1331_11EB
    seed ^= upper
    seed ^= lower &* 0xE703_7ED1_A0B4_28DB
    if let symbolChoiceSeed {
      seed ^= symbolChoiceSeed &* 0xD1B5_4A32_D192_ED03
    }
    seed ^= seed >> 31
    return seed
  }

  private static func maximumBoundingRadius(
    for symbols: [PlacementSymbolDescriptor],
    maximumScaleMultiplier: CGFloat,
  ) -> CGFloat {
    var maximumRadius: CGFloat = 0
    for symbol in symbols.flatMap(\.renderableLeafDescriptors) {
      let maximumScale = max(0, symbol.resolvedScaleRange.upperBound) * Double(maximumScaleMultiplier)
      let radius = symbol.collisionShape.boundingRadius(atScale: CGFloat(maximumScale))
      maximumRadius = max(maximumRadius, radius)
    }
    return maximumRadius
  }

  private static func pickSymbol(
    from symbols: [PlacementSymbolDescriptor],
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> PlacementSymbolDescriptor? {
    // Weighted pick to preserve caller-defined symbol frequencies.
    guard symbols.isEmpty == false else { return nil }

    var totalWeight = 0.0
    for symbol in symbols {
      if symbol.weight.isFinite {
        totalWeight += max(0, symbol.weight)
      }
    }

    guard totalWeight > 0 else { return symbols.randomElement(using: &randomGenerator) }

    let randomValue = Double.random(in: 0..<totalWeight, using: &randomGenerator)
    var accumulator = 0.0

    for symbol in symbols {
      if symbol.weight.isFinite {
        accumulator += max(0, symbol.weight)
      }
      if randomValue < accumulator {
        return symbol
      }
    }

    return symbols.last
  }

  private static func randomPoint(
    in size: CGSize,
    region: TesseraResolvedPolygonRegion?,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> CGPoint? {
    guard size.width > 0, size.height > 0 else { return nil }
    guard let region else {
      return CGPoint(
        x: CGFloat.random(in: 0..<size.width, using: &randomGenerator),
        y: CGFloat.random(in: 0..<size.height, using: &randomGenerator),
      )
    }

    let bounds = region.samplingBounds
    guard bounds.isNull == false, bounds.isEmpty == false else { return nil }

    let minimumAttempts = 12

    for _ in 0..<minimumAttempts {
      let point = CGPoint(
        x: CGFloat.random(in: bounds.minX..<bounds.maxX, using: &randomGenerator),
        y: CGFloat.random(in: bounds.minY..<bounds.maxY, using: &randomGenerator),
      )

      if region.contains(point) {
        return point
      }
    }

    return nil
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
