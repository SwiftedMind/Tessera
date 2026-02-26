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
    let minimumSpacingMultiplierEvaluator = ShapePlacementSteering.evaluator(
      for: configuration.steering.minimumSpacingMultiplier,
      canvasSize: size,
      defaultValue: 1,
    )
    let scaleMultiplierEvaluator = ShapePlacementSteering.evaluator(
      for: configuration.steering.scaleMultiplier,
      canvasSize: size,
      defaultValue: 1,
    )
    let rotationMultiplierEvaluator = ShapePlacementSteering.evaluator(
      for: configuration.steering.rotationMultiplier,
      canvasSize: size,
      defaultValue: 1,
    )
    let rotationOffsetDegreesEvaluator = ShapePlacementSteering.evaluator(
      for: configuration.steering.rotationOffsetDegrees,
      canvasSize: size,
      defaultValue: 0,
    )
    let regionPointSampler = region.flatMap { RegionPointSampler(region: $0) }
    let sparseMaskPointSampler = alphaMask.flatMap { SparseMaskPointSampler(alphaMask: $0) }

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

        guard let position = samplePosition(
          in: size,
          region: region,
          regionPointSampler: regionPointSampler,
          alphaMask: alphaMask,
          sparseMaskPointSampler: sparseMaskPointSampler,
          using: &randomGenerator,
        ) else { continue }

        let spacingMultiplier = max(
          0,
          minimumSpacingMultiplierEvaluator?.value(at: position) ?? 1,
        )
        let candidateMinimumSpacing = baseMinimumSpacing * CGFloat(spacingMultiplier)
        let scaleMultiplier = max(
          0,
          scaleMultiplierEvaluator?.value(at: position) ?? 1,
        )
        let scale = max(0, baseScale * scaleMultiplier)
        let rotationMultiplier = max(
          0,
          rotationMultiplierEvaluator?.value(at: position) ?? 1,
        )
        let rotationOffsetDegrees = rotationOffsetDegreesEvaluator?.value(at: position) ?? 0
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

  private static func samplePosition(
    in size: CGSize,
    region: TesseraResolvedPolygonRegion?,
    regionPointSampler: RegionPointSampler?,
    alphaMask: TesseraAlphaMask?,
    sparseMaskPointSampler: SparseMaskPointSampler?,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> CGPoint? {
    guard size.width > 0, size.height > 0 else { return nil }

    if let sparseMaskPointSampler {
      let maximumAttempts = 12
      for _ in 0..<maximumAttempts {
        guard let point = sparseMaskPointSampler.sample(using: &randomGenerator) else { break }

        if let region, region.contains(point) == false {
          continue
        }
        if let alphaMask, alphaMask.contains(point) == false {
          continue
        }
        return point
      }
      return nil
    }

    guard let point = randomPoint(
      in: size,
      region: region,
      regionPointSampler: regionPointSampler,
      using: &randomGenerator,
    ) else { return nil }

    if let alphaMask, alphaMask.contains(point) == false {
      return nil
    }

    return point
  }

  private static func randomPoint(
    in size: CGSize,
    region: TesseraResolvedPolygonRegion?,
    regionPointSampler: RegionPointSampler?,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> CGPoint? {
    guard size.width > 0, size.height > 0 else { return nil }
    guard let region else {
      return CGPoint(
        x: CGFloat.random(in: 0..<size.width, using: &randomGenerator),
        y: CGFloat.random(in: 0..<size.height, using: &randomGenerator),
      )
    }

    if let regionPointSampler {
      return regionPointSampler.sample(using: &randomGenerator)
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

  private struct SparseMaskPointSampler {
    var pointSize: CGSize
    var pixelsWide: Int
    var pixelsHigh: Int
    var acceptedPixelIndices: [Int]

    init?(
      alphaMask: TesseraAlphaMask,
      maximumFilledFraction: Double = 0.35,
      minimumAcceptedPixelCount: Int = 32,
    ) {
      guard alphaMask.filledFraction > 0, alphaMask.filledFraction <= maximumFilledFraction else { return nil }

      var acceptedPixelIndices: [Int] = []
      acceptedPixelIndices.reserveCapacity(max(minimumAcceptedPixelCount, alphaMask.alphaBytes.count / 10))

      for (index, value) in alphaMask.alphaBytes.enumerated() {
        let visible = value >= alphaMask.thresholdByte
        let included = alphaMask.invert ? !visible : visible
        if included {
          acceptedPixelIndices.append(index)
        }
      }

      guard acceptedPixelIndices.count >= minimumAcceptedPixelCount else { return nil }

      pointSize = alphaMask.size
      pixelsWide = alphaMask.pixelsWide
      pixelsHigh = alphaMask.pixelsHigh
      self.acceptedPixelIndices = acceptedPixelIndices
    }

    func sample(
      using randomGenerator: inout some RandomNumberGenerator,
    ) -> CGPoint? {
      guard acceptedPixelIndices.isEmpty == false else { return nil }
      guard pixelsWide > 0, pixelsHigh > 0 else { return nil }

      let sampleIndex = Int.random(in: 0..<acceptedPixelIndices.count, using: &randomGenerator)
      let pixelIndex = acceptedPixelIndices[sampleIndex]
      let pixelX = pixelIndex % pixelsWide
      let pixelY = pixelIndex / pixelsWide

      let jitterX = CGFloat.random(in: 0..<1, using: &randomGenerator)
      let jitterY = CGFloat.random(in: 0..<1, using: &randomGenerator)

      let x = (CGFloat(pixelX) + jitterX) / CGFloat(pixelsWide) * pointSize.width
      let y = (CGFloat(pixelY) + jitterY) / CGFloat(pixelsHigh) * pointSize.height
      return CGPoint(x: x, y: y)
    }
  }

  private struct RegionPointSampler {
    private struct Triangle {
      var a: CGPoint
      var b: CGPoint
      var c: CGPoint
      var area: Double
    }

    private let triangles: [Triangle]
    private let cumulativeAreas: [Double]
    private let totalArea: Double

    init?(region: TesseraResolvedPolygonRegion) {
      let points = region.points
      guard points.count >= 3 else { return nil }
      guard let triangles = Self.triangulate(points), triangles.isEmpty == false else {
        return nil
      }

      var cumulativeAreas: [Double] = []
      cumulativeAreas.reserveCapacity(triangles.count)

      var runningArea = 0.0
      for triangle in triangles {
        runningArea += triangle.area
        cumulativeAreas.append(runningArea)
      }

      guard runningArea > Self.epsilon else { return nil }

      self.triangles = triangles
      self.cumulativeAreas = cumulativeAreas
      totalArea = runningArea
    }

    func sample(
      using randomGenerator: inout some RandomNumberGenerator,
    ) -> CGPoint? {
      guard triangles.isEmpty == false, totalArea > Self.epsilon else { return nil }

      let randomValue = Double.random(in: 0..<totalArea, using: &randomGenerator)
      let triangleIndex = triangleIndex(for: randomValue)
      let triangle = triangles[triangleIndex]

      // Uniform random sample inside a triangle using barycentric coordinates.
      let r1 = sqrt(Double.random(in: 0...1, using: &randomGenerator))
      let r2 = Double.random(in: 0...1, using: &randomGenerator)
      let weightA = 1 - r1
      let weightB = r1 * (1 - r2)
      let weightC = r1 * r2

      return CGPoint(
        x: triangle.a.x * weightA + triangle.b.x * weightB + triangle.c.x * weightC,
        y: triangle.a.y * weightA + triangle.b.y * weightB + triangle.c.y * weightC,
      )
    }

    private func triangleIndex(for value: Double) -> Int {
      var lowerBound = 0
      var upperBound = cumulativeAreas.count - 1

      while lowerBound < upperBound {
        let mid = (lowerBound + upperBound) / 2
        if value < cumulativeAreas[mid] {
          upperBound = mid
        } else {
          lowerBound = mid + 1
        }
      }

      return lowerBound
    }

    private static let epsilon = 0.000_001

    private static func triangulate(_ points: [CGPoint]) -> [Triangle]? {
      guard points.count >= 3 else { return nil }

      var remainingPoints = points
      var triangles: [Triangle] = []
      let isCounterClockwise = signedArea(remainingPoints) > 0
      let maximumIterations = remainingPoints.count * remainingPoints.count
      var iteration = 0

      while remainingPoints.count > 3, iteration < maximumIterations {
        iteration += 1
        var didFindEar = false
        let count = remainingPoints.count

        for index in 0..<count {
          let previousIndex = (index - 1 + count) % count
          let nextIndex = (index + 1) % count

          let previousPoint = remainingPoints[previousIndex]
          let currentPoint = remainingPoints[index]
          let nextPoint = remainingPoints[nextIndex]

          guard isConvexVertex(
            previousPoint,
            currentPoint,
            nextPoint,
            isCounterClockwise: isCounterClockwise,
          ) else { continue }

          let trianglePoints = [previousPoint, currentPoint, nextPoint]
          if triangleContainsAnyPoint(
            trianglePoints,
            in: remainingPoints,
            excludingIndices: [previousIndex, index, nextIndex],
            isCounterClockwise: isCounterClockwise,
          ) {
            continue
          }

          if let triangle = makeTriangle(from: trianglePoints) {
            triangles.append(triangle)
          }
          remainingPoints.remove(at: index)
          didFindEar = true
          break
        }

        if didFindEar == false {
          return nil
        }
      }

      if remainingPoints.count == 3, let triangle = makeTriangle(from: remainingPoints) {
        triangles.append(triangle)
      }

      return triangles.isEmpty ? nil : triangles
    }

    private static func makeTriangle(from points: [CGPoint]) -> Triangle? {
      guard points.count == 3 else { return nil }

      let area = abs(signedArea(points))
      guard area > epsilon else { return nil }

      return Triangle(
        a: points[0],
        b: points[1],
        c: points[2],
        area: Double(area),
      )
    }

    private static func isConvexVertex(
      _ previousPoint: CGPoint,
      _ currentPoint: CGPoint,
      _ nextPoint: CGPoint,
      isCounterClockwise: Bool,
    ) -> Bool {
      let cross = cornerCross(previous: previousPoint, current: currentPoint, next: nextPoint)
      guard abs(cross) > epsilon else { return false }

      return isCounterClockwise ? cross > 0 : cross < 0
    }

    private static func triangleContainsAnyPoint(
      _ triangle: [CGPoint],
      in points: [CGPoint],
      excludingIndices: [Int],
      isCounterClockwise: Bool,
    ) -> Bool {
      let excludedSet = Set(excludingIndices)

      for (index, point) in points.enumerated() where excludedSet.contains(index) == false {
        if pointIsInsideTriangle(
          point,
          triangle: triangle,
          isCounterClockwise: isCounterClockwise,
        ) {
          return true
        }
      }

      return false
    }

    private static func pointIsInsideTriangle(
      _ point: CGPoint,
      triangle: [CGPoint],
      isCounterClockwise: Bool,
    ) -> Bool {
      guard triangle.count == 3 else { return false }

      let pointA = triangle[0]
      let pointB = triangle[1]
      let pointC = triangle[2]

      let cross1 = crossProduct(pointA, pointB, point)
      let cross2 = crossProduct(pointB, pointC, point)
      let cross3 = crossProduct(pointC, pointA, point)

      if isCounterClockwise {
        return cross1 >= -epsilon && cross2 >= -epsilon && cross3 >= -epsilon
      }

      return cross1 <= epsilon && cross2 <= epsilon && cross3 <= epsilon
    }

    private static func signedArea(_ points: [CGPoint]) -> CGFloat {
      guard points.count >= 3 else { return 0 }

      var area: CGFloat = 0
      for index in points.indices {
        let pointA = points[index]
        let pointB = points[(index + 1) % points.count]
        area += pointA.x * pointB.y - pointB.x * pointA.y
      }

      return area / 2
    }

    private static func cornerCross(
      previous: CGPoint,
      current: CGPoint,
      next: CGPoint,
    ) -> CGFloat {
      let vectorA = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
      let vectorB = CGPoint(x: next.x - current.x, y: next.y - current.y)
      return vectorA.x * vectorB.y - vectorA.y * vectorB.x
    }

    private static func crossProduct(
      _ pointA: CGPoint,
      _ pointB: CGPoint,
      _ pointC: CGPoint,
    ) -> CGFloat {
      let vectorA = CGPoint(x: pointB.x - pointA.x, y: pointB.y - pointA.y)
      let vectorB = CGPoint(x: pointC.x - pointA.x, y: pointC.y - pointA.y)
      return vectorA.x * vectorB.y - vectorA.y * vectorB.x
    }
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
