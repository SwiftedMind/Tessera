// By Dennis Müller

import CoreGraphics
import Foundation

/// Places symbols using organic rejection sampling with spatial hashing.
enum OrganicShapePlacementEngine {
  typealias PlacementSymbolDescriptor = ShapePlacementEngine.PlacementSymbolDescriptor
  typealias PinnedSymbolDescriptor = ShapePlacementEngine.PinnedSymbolDescriptor
  typealias PlacedSymbolDescriptor = ShapePlacementEngine.PlacedSymbolDescriptor
  typealias PlacedCollider = ShapePlacementEngine.PlacedCollider

  private struct DensePlacementCandidate {
    var descriptor: PlacedSymbolDescriptor
    var collider: PlacedCollider
    var choiceSequenceState: ShapePlacementEngine.ChoiceSequenceState
    var score: Double
  }

  private enum DenseFillTuning {
    static let stronglyLargerPhaseEnd = 0.08
    static let largerPhaseEnd = 0.18
    static let smallerPhaseStart = 0.42
    static let stronglySmallerPhaseStart = 0.65
    static let fillerRecoveryProgressFloor = stronglySmallerPhaseStart

    static let recoveryAttemptMinimum = 24
    static let recoveryAttemptMaximum = 160
    static let recoveryAttemptTargetDivisor = 3

    static let standardEarlyAttempts = 64
    static let standardMiddleAttempts = 72
    static let standardLateAttempts = 80
    static let standardFinalAttempts = 96
    static let rescueEarlyAttempts = 96
    static let rescueMiddleAttempts = 112
    static let rescueFinalAttempts = 128
  }

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
  ///   - maskConstraintMode: How strictly the alpha mask constrains collision geometry.
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
    alphaMask: (any PlacementMask)? = nil,
    maskConstraintMode: ShapePlacementMaskConstraint.Mode = .sampledCollisionGeometry,
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
    let resolvedMaskFilledFraction = alphaMask?.filledFraction ?? 1
    let maskArea = alphaMask.map { _ in resolvedMaskFilledFraction * tileArea } ?? tileArea
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
    let sparseMaskPointSampler = alphaMask.flatMap { alphaMask -> SparseMaskPointSampler? in
      guard let discreteMask = alphaMask as? any DiscretePlacementMask else { return nil }

      return SparseMaskPointSampler(
        mask: discreteMask,
        filledFraction: resolvedMaskFilledFraction,
      )
    }
    let maskContains = alphaMask.map { PlacementMaskContainment.containsFunction(for: $0) }

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
    let symbolBoundingRadiusByID = symbolDescriptors.reduce(into: [UUID: CGFloat]()) { radiiByID, symbol in
      radiiByID[symbol.id] = preferredBoundingRadius(
        for: symbol,
        maximumScaleMultiplier: CGFloat(maximumScaleMultiplier),
      )
    }
    let maximumBoundingRadius = max(maximumGeneratedBoundingRadius, maximumFixedBoundingRadius)
    let maximumInteractionDistance = maximumBoundingRadius * 2 + maximumMinimumSpacing
    let cellSize = max(maximumInteractionDistance, 1)
    let gridColumnCount = max(1, Int(ceil(size.width / cellSize)))
    let gridRowCount = max(1, Int(ceil(size.height / cellSize)))

    let renderableLeafDescriptors = symbolDescriptors.flatMap(\.renderableLeafDescriptors)
    let polygonCache: [UUID: [CollisionPolygon]] = renderableLeafDescriptors.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = CollisionMath.polygons(for: symbol.collisionShape)
    }
    let collisionAreaByID: [UUID: CGFloat] = if configuration.fillStrategy == .dense {
      renderableLeafDescriptors.reduce(into: [:]) { cache, symbol in
        guard let polygons = polygonCache[symbol.id] else { return }

        cache[symbol.id] = collisionAreaEstimate(
          for: symbol.collisionShape,
          polygons: polygons,
          scale: 1,
        )
      }
    } else {
      [:]
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
    var saturationStopState = SaturationStopState(remainingTargetCount: remainingTargetCount)

    diagnostics?.placementOuterAttempts = 0
    diagnostics?.placementSuccesses = 0
    diagnostics?.placementSuccessesUsingRescue = 0
    diagnostics?.placementFailures = 0
    diagnostics?.terminatedForSaturation = false

    let maximumPlacementAttemptCount = maximumPlacementAttemptCount(
      fillStrategy: configuration.fillStrategy,
      targetCount: remainingTargetCount,
    )
    var placementAttemptIndex = 0

    while placementAttemptIndex < maximumPlacementAttemptCount,
          placedDescriptors.count < remainingTargetCount {
      if Task.isCancelled { return placedDescriptors }

      let usesDenseFillerRecovery = configuration.fillStrategy == .dense &&
        placementAttemptIndex >= remainingTargetCount
      let symbolSelectionMode = symbolSelectionMode(
        fillStrategy: configuration.fillStrategy,
        placedCount: placedDescriptors.count,
        targetCount: remainingTargetCount,
        saturationStopState: saturationStopState,
        usesFillerRecovery: usesDenseFillerRecovery,
      )
      let placedProgress = placementProgress(
        placedCount: placedDescriptors.count,
        targetCount: remainingTargetCount,
      )
      let placementSearchProgress = usesDenseFillerRecovery ?
        max(placedProgress, DenseFillTuning.fillerRecoveryProgressFloor) :
        placedProgress

      guard let selectedSymbol = pickSymbol(
        from: symbolDescriptors,
        symbolBoundingRadiusByID: symbolBoundingRadiusByID,
        selectionMode: symbolSelectionMode,
        using: &randomGenerator,
      ) else { break }

      let choiceSeed = organicChoiceSeed(
        baseSeed: configuration.seed,
        placementAttemptIndex: placementAttemptIndex,
        symbolID: selectedSymbol.id,
        symbolChoiceSeed: selectedSymbol.choiceSeed,
      )
      var choiceRandomGenerator = SeededGenerator(seed: choiceSeed)
      var tentativeChoiceSequenceState = choiceSequenceState
      var didPlaceSymbol = false
      var didUseRescueSearch = false
      if let selectedRenderSymbol = ShapePlacementEngine.resolveLeafSymbolDescriptor(
        from: selectedSymbol,
        randomGenerator: &choiceRandomGenerator,
        sequenceState: &tentativeChoiceSequenceState,
      ), let selectedPolygons = polygonCache[selectedRenderSymbol.id] {
        let shouldUseRescueSearch = saturationStopState.shouldUseCandidateRescue || usesDenseFillerRecovery
        didUseRescueSearch = shouldUseRescueSearch
        let attemptPolicy = CandidateAttemptPolicy.make(
          for: selectedRenderSymbol,
          fillStrategy: configuration.fillStrategy,
          usesRescueSearch: shouldUseRescueSearch,
          placedProgress: placementSearchProgress,
          using: &randomGenerator,
        )
        let selectedCollisionArea: CGFloat? = if configuration.fillStrategy == .dense {
          collisionAreaByID[selectedRenderSymbol.id] ?? collisionAreaEstimate(
            for: selectedRenderSymbol.collisionShape,
            polygons: selectedPolygons,
            scale: 1,
          )
        } else {
          nil
        }
        var bestDenseCandidate: DensePlacementCandidate?

        for attemptIndex in 0..<attemptPolicy.maximumAttempts {
          if Task.isCancelled { return placedDescriptors }

          guard let position = samplePosition(
            in: size,
            region: region,
            regionPointSampler: regionPointSampler,
            alphaMaskContains: maskContains,
            sparseMaskPointSampler: sparseMaskPointSampler,
            spatialIndex: spatialIndex,
            cellSize: cellSize,
            prefersOpenCells: saturationStopState.shouldPreferOpenCells,
            fillStrategy: configuration.fillStrategy,
            placedProgress: placementSearchProgress,
            diagnostics: diagnostics,
            using: &randomGenerator,
          ) else { continue }

          let candidateBaseParameters = attemptPolicy.baseParameters(
            for: attemptIndex,
            using: &randomGenerator,
          )

          let spacingMultiplier = max(
            0,
            minimumSpacingMultiplierEvaluator?.value(at: position) ?? 1,
          )
          let candidateMinimumSpacing = baseMinimumSpacing * CGFloat(spacingMultiplier)
          let scaleMultiplier = max(
            0,
            scaleMultiplierEvaluator?.value(at: position) ?? 1,
          )
          let scale = max(0, candidateBaseParameters.scale * scaleMultiplier)
          let rotationMultiplier = max(
            0,
            rotationMultiplierEvaluator?.value(at: position) ?? 1,
          )
          let rotationOffsetDegrees = rotationOffsetDegreesEvaluator?.value(at: position) ?? 0
          let rotationOffsetRadians = rotationOffsetDegrees * Double.pi / 180
          let rotationRadians = candidateBaseParameters.rotationRadians * rotationMultiplier + rotationOffsetRadians

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

          if let alphaMask {
            let maskValidation = ShapePlacementMaskConstraint.validationResult(
              alphaMask,
              collisionTransform: candidateTransform,
              polygons: selectedPolygons,
              mode: maskConstraintMode,
              centerAlreadyValidated: true,
              boundingRadius: candidateCollision.boundingRadius,
            )
            switch maskValidation {
            case .accepted:
              break
            case .rejectedAtCenterPoint:
              diagnostics?.centerPointMaskRejects += 1
              continue
            case .rejectedAtSampledGeometry:
              diagnostics?.sampledGeometryMaskRejects += 1
              continue
            }
          }

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
          ) else {
            diagnostics?.symbolCollisionRejects += 1
            continue
          }

          if configuration.fillStrategy == .dense {
            guard let selectedCollisionArea else { continue }

            let score = denseCandidateScore(
              candidate: candidateCollision,
              unscaledCollisionArea: selectedCollisionArea,
              neighboringColliderIndices: neighboringColliderIndices,
              allColliders: colliders,
              tileSize: size,
              edgeBehavior: edgeBehavior,
              maximumInteractionDistance: maximumInteractionDistance,
              placedProgress: placementSearchProgress,
              selectionMode: symbolSelectionMode,
            )
            if let currentBestDenseCandidate = bestDenseCandidate,
               score <= currentBestDenseCandidate.score {
              continue
            } else {
              let candidate = PlacedSymbolDescriptor(
                symbolId: selectedSymbol.id,
                renderSymbolId: selectedRenderSymbol.id,
                zIndex: selectedSymbol.zIndex,
                sourceOrder: selectedSymbol.sourceOrder,
                position: position,
                rotationRadians: rotationRadians,
                scale: CGFloat(scale),
                clipRect: nil,
                collisionShape: candidateCollisionShape,
              )
              let collider = PlacedCollider(
                collisionShape: candidateCollisionShape,
                collisionTransform: candidateTransform,
                polygons: selectedPolygons,
                boundingRadius: candidateCollision.boundingRadius,
                minimumSpacing: candidateMinimumSpacing,
              )
              bestDenseCandidate = DensePlacementCandidate(
                descriptor: candidate,
                collider: collider,
                choiceSequenceState: tentativeChoiceSequenceState,
                score: score,
              )
            }
            continue
          }

          let candidate = PlacedSymbolDescriptor(
            symbolId: selectedSymbol.id,
            renderSymbolId: selectedRenderSymbol.id,
            zIndex: selectedSymbol.zIndex,
            sourceOrder: selectedSymbol.sourceOrder,
            position: position,
            rotationRadians: rotationRadians,
            scale: CGFloat(scale),
            clipRect: nil,
            collisionShape: candidateCollisionShape,
          )
          let collider = PlacedCollider(
            collisionShape: candidateCollisionShape,
            collisionTransform: candidateTransform,
            polygons: selectedPolygons,
            boundingRadius: candidateCollision.boundingRadius,
            minimumSpacing: candidateMinimumSpacing,
          )

          choiceSequenceState = tentativeChoiceSequenceState
          placedDescriptors.append(candidate)

          colliders.append(collider)
          let newColliderIndex = colliders.count - 1
          spatialIndex.append(colliderIndex: newColliderIndex, at: position, cellSize: cellSize)

          didPlaceSymbol = true
          break
        }

        if let bestDenseCandidate {
          choiceSequenceState = bestDenseCandidate.choiceSequenceState
          placedDescriptors.append(bestDenseCandidate.descriptor)

          colliders.append(bestDenseCandidate.collider)
          let newColliderIndex = colliders.count - 1
          spatialIndex.append(
            colliderIndex: newColliderIndex,
            at: bestDenseCandidate.descriptor.position,
            cellSize: cellSize,
          )

          didPlaceSymbol = true
        }
      }

      if didPlaceSymbol {
        diagnostics?.placementSuccesses += 1
        if didUseRescueSearch {
          diagnostics?.placementSuccessesUsingRescue += 1
        }
      } else {
        diagnostics?.placementFailures += 1
      }
      let reachedSaturationLimit = saturationStopState.recordAttempt(didPlaceSymbol: didPlaceSymbol)
      diagnostics?.placementOuterAttempts = saturationStopState.outerAttempts
      placementAttemptIndex += 1

      if reachedSaturationLimit {
        diagnostics?.terminatedForSaturation = true
        break
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

    func neighboringOccupancy(around cellIndex: Int) -> Int {
      guard cellIndex >= 0, cellIndex < neighboringCellIndicesByCellIndex.count else { return 0 }

      let neighboringCellIndices = neighboringCellIndicesByCellIndex[cellIndex]
      var occupancy = 0
      for neighboringCellIndex in neighboringCellIndices where neighboringCellIndex != cellIndex {
        occupancy += colliderIndicesByCellIndex[neighboringCellIndex].count
      }
      return occupancy
    }

    func randomPoint(
      inCellAt cellIndex: Int,
      cellSize: CGFloat,
      tileSize: CGSize,
      using randomGenerator: inout some RandomNumberGenerator,
    ) -> CGPoint? {
      guard cellIndex >= 0, cellIndex < colliderIndicesByCellIndex.count else { return nil }
      guard cellSize > 0 else { return nil }

      let row = cellIndex / gridColumnCount
      let column = cellIndex % gridColumnCount
      let minX = CGFloat(column) * cellSize
      let minY = CGFloat(row) * cellSize
      let maxX = min(tileSize.width, minX + cellSize)
      let maxY = min(tileSize.height, minY + cellSize)
      guard maxX > minX, maxY > minY else { return nil }

      return CGPoint(
        x: CGFloat.random(in: minX..<maxX, using: &randomGenerator),
        y: CGFloat.random(in: minY..<maxY, using: &randomGenerator),
      )
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

  private static func maximumPlacementAttemptCount(
    fillStrategy: PlacementModel.OrganicFillStrategy,
    targetCount: Int,
  ) -> Int {
    guard fillStrategy == .dense, targetCount > 0 else { return targetCount }

    let recoveryAttemptCount = min(
      max(DenseFillTuning.recoveryAttemptMinimum, targetCount / DenseFillTuning.recoveryAttemptTargetDivisor),
      DenseFillTuning.recoveryAttemptMaximum,
    )
    return targetCount + recoveryAttemptCount
  }

  private static func denseCandidateScore(
    candidate: ShapePlacementCollision.PlacementCandidate,
    unscaledCollisionArea: CGFloat,
    neighboringColliderIndices: [Int],
    allColliders: [PlacedCollider],
    tileSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
    maximumInteractionDistance: CGFloat,
    placedProgress: Double,
    selectionMode: SymbolSelectionMode,
  ) -> Double {
    let area = unscaledCollisionArea * candidate.collisionTransform.scale * candidate.collisionTransform.scale
    let contact = denseContactScore(
      candidate: candidate,
      neighboringColliderIndices: neighboringColliderIndices,
      allColliders: allColliders,
      tileSize: tileSize,
      edgeBehavior: edgeBehavior,
      maximumInteractionDistance: maximumInteractionDistance,
    )
    let normalizedProgress = min(1, max(0, placedProgress))
    let areaExponent: Double = switch selectionMode {
    case .stronglyPrefersSmallerSymbols:
      0.35
    case .prefersSmallerSymbols:
      0.5
    case .defaultWeights:
      0.7
    case .prefersLargerSymbols:
      0.9
    case .stronglyPrefersLargerSymbols:
      1
    }
    let areaScore = pow(max(Double(area), 1), areaExponent)
    let contactMultiplier = 0.25 + normalizedProgress * 0.9
    return areaScore * (1 + contact * contactMultiplier)
  }

  private static func denseContactScore(
    candidate: ShapePlacementCollision.PlacementCandidate,
    neighboringColliderIndices: [Int],
    allColliders: [PlacedCollider],
    tileSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
    maximumInteractionDistance: CGFloat,
  ) -> Double {
    guard neighboringColliderIndices.isEmpty == false else { return 0 }

    var minimumSurfaceGap = CGFloat.greatestFiniteMagnitude
    for colliderIndex in neighboringColliderIndices {
      let collider = allColliders[colliderIndex]
      let distance = centerDistance(
        from: candidate.collisionTransform.position,
        to: collider.collisionTransform.position,
        tileSize: tileSize,
        edgeBehavior: edgeBehavior,
      )
      let surfaceGap = max(0, distance - abs(candidate.boundingRadius) - abs(collider.boundingRadius))
      minimumSurfaceGap = min(minimumSurfaceGap, surfaceGap)
    }

    guard minimumSurfaceGap.isFinite else { return 0 }

    let normalizedGap = Double(minimumSurfaceGap / max(maximumInteractionDistance, 1))
    return 1 / (1 + normalizedGap)
  }

  private static func centerDistance(
    from first: CGPoint,
    to second: CGPoint,
    tileSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
  ) -> CGFloat {
    var deltaX = first.x - second.x
    var deltaY = first.y - second.y

    if edgeBehavior == .seamlessWrapping {
      if tileSize.width > 0 {
        deltaX -= (deltaX / tileSize.width).rounded() * tileSize.width
      }
      if tileSize.height > 0 {
        deltaY -= (deltaY / tileSize.height).rounded() * tileSize.height
      }
    }

    return hypot(deltaX, deltaY)
  }

  private static func collisionAreaEstimate(
    for collisionShape: CollisionShape,
    polygons: [CollisionPolygon],
    scale: CGFloat,
  ) -> CGFloat {
    let scaleArea = scale * scale
    switch collisionShape {
    case let .circle(_, radius):
      return .pi * radius * radius * scaleArea
    case let .rectangle(_, size):
      return abs(size.width * size.height) * scaleArea
    default:
      let polygonArea = polygons.reduce(CGFloat(0)) { total, polygon in
        total + abs(signedArea(of: polygon.points))
      }
      if polygonArea > 0 {
        return polygonArea * scaleArea
      }

      let radius = collisionShape.boundingRadius(atScale: scale)
      return .pi * radius * radius
    }
  }

  private static func signedArea(of points: [CGPoint]) -> CGFloat {
    guard points.count >= 3 else { return 0 }

    var area: CGFloat = 0
    for index in points.indices {
      let pointA = points[index]
      let pointB = points[(index + 1) % points.count]
      area += pointA.x * pointB.y - pointB.x * pointA.y
    }

    return area / 2
  }

  private struct SaturationStopState {
    private let windowSize = 128
    private let minimumAttemptsBeforeEarlyStop = 128
    private let missStreakLimit: Int
    private let zeroSuccessWindowLimit = 2
    private let openCellMissStreakThreshold = 4
    private let rescueMissStreakThreshold = 8
    private let rescueWindowMinimumSamples = 16
    private let rescueWindowMinimumSuccessRate = 0.35

    private var consecutiveMisses = 0
    private var windowOutcomes: [Bool]
    private var windowOutcomeCount = 0
    private var windowInsertIndex = 0
    private var windowSuccessCount = 0
    private var consecutiveZeroSuccessWindows = 0

    var outerAttempts = 0
    var shouldPreferOpenCells: Bool {
      consecutiveMisses >= openCellMissStreakThreshold || consecutiveZeroSuccessWindows > 0
    }

    var shouldUseCandidateRescue: Bool {
      consecutiveMisses >= rescueMissStreakThreshold || isRecentSuccessRateLow || consecutiveZeroSuccessWindows > 0
    }

    init(remainingTargetCount: Int) {
      missStreakLimit = min(512, max(128, remainingTargetCount / 10))
      windowOutcomes = Array(repeating: false, count: windowSize)
    }

    mutating func recordAttempt(didPlaceSymbol: Bool) -> Bool {
      outerAttempts += 1

      if didPlaceSymbol {
        consecutiveMisses = 0
      } else {
        consecutiveMisses += 1
      }

      if windowOutcomeCount < windowSize {
        windowOutcomeCount += 1
      } else if windowOutcomes[windowInsertIndex] {
        windowSuccessCount -= 1
      }

      windowOutcomes[windowInsertIndex] = didPlaceSymbol
      if didPlaceSymbol {
        windowSuccessCount += 1
      }
      windowInsertIndex = (windowInsertIndex + 1) % windowSize

      if windowOutcomeCount == windowSize {
        if windowSuccessCount == 0 {
          consecutiveZeroSuccessWindows += 1
        } else {
          consecutiveZeroSuccessWindows = 0
        }
      }

      guard outerAttempts >= minimumAttemptsBeforeEarlyStop else { return false }

      return consecutiveMisses >= missStreakLimit || consecutiveZeroSuccessWindows >= zeroSuccessWindowLimit
    }

    private var isRecentSuccessRateLow: Bool {
      guard windowOutcomeCount >= rescueWindowMinimumSamples else { return false }

      let successRate = Double(windowSuccessCount) / Double(windowOutcomeCount)
      return successRate <= rescueWindowMinimumSuccessRate
    }
  }

  private struct CandidateAttemptPolicy {
    struct BaseParameters {
      var scale: Double
      var rotationRadians: Double
    }

    private let stableAttemptCount = 20
    private let rotationRescueAttemptCount = 6

    let maximumAttempts: Int
    let baseScale: Double
    let baseRotationRadians: Double
    let scaleRange: ClosedRange<Double>
    let rotationRangeDegrees: ClosedRange<Double>

    static func make(
      for renderSymbol: PlacementSymbolDescriptor.RenderDescriptor,
      fillStrategy: PlacementModel.OrganicFillStrategy,
      usesRescueSearch: Bool,
      placedProgress: Double,
      using randomGenerator: inout some RandomNumberGenerator,
    ) -> Self {
      let canRescueRotation = renderSymbol.allowedRotationRangeDegrees.lowerBound !=
        renderSymbol.allowedRotationRangeDegrees.upperBound
      let canRescueScale = renderSymbol.resolvedScaleRange.lowerBound != renderSymbol.resolvedScaleRange.upperBound
      let usesRescueSearch = usesRescueSearch && (canRescueRotation || canRescueScale)
      let maximumAttempts = switch fillStrategy {
      case .rejection:
        usesRescueSearch ? 32 : 20
      case .dense:
        denseAttemptCount(placedProgress: placedProgress, usesRescueSearch: usesRescueSearch)
      }
      return Self(
        maximumAttempts: maximumAttempts,
        baseScale: Double.random(in: renderSymbol.resolvedScaleRange, using: &randomGenerator),
        baseRotationRadians: randomAngleRadians(
          in: renderSymbol.allowedRotationRangeDegrees,
          using: &randomGenerator,
        ),
        scaleRange: renderSymbol.resolvedScaleRange,
        rotationRangeDegrees: renderSymbol.allowedRotationRangeDegrees,
      )
    }

    private static func denseAttemptCount(
      placedProgress: Double,
      usesRescueSearch: Bool,
    ) -> Int {
      let progress = min(1, max(0, placedProgress))
      if usesRescueSearch {
        if progress < DenseFillTuning.smallerPhaseStart {
          return DenseFillTuning.rescueEarlyAttempts
        }
        if progress < DenseFillTuning.stronglySmallerPhaseStart {
          return DenseFillTuning.rescueMiddleAttempts
        }
        return DenseFillTuning.rescueFinalAttempts
      }

      if progress < DenseFillTuning.largerPhaseEnd {
        return DenseFillTuning.standardEarlyAttempts
      }
      if progress < DenseFillTuning.smallerPhaseStart {
        return DenseFillTuning.standardMiddleAttempts
      }
      if progress < DenseFillTuning.stronglySmallerPhaseStart {
        return DenseFillTuning.standardLateAttempts
      }
      return DenseFillTuning.standardFinalAttempts
    }

    func baseParameters(
      for attemptIndex: Int,
      using randomGenerator: inout some RandomNumberGenerator,
    ) -> BaseParameters {
      let resolvedStableAttemptCount = min(stableAttemptCount, maximumAttempts)
      // Keep the original sample stable first, then widen rotation and scale
      // exploration only after the symbol has already struggled to fit.
      if attemptIndex < resolvedStableAttemptCount {
        return BaseParameters(
          scale: baseScale,
          rotationRadians: baseRotationRadians,
        )
      }

      let rescueAttemptIndex = attemptIndex - resolvedStableAttemptCount
      let resolvedRotationRescueAttemptCount = min(
        rotationRescueAttemptCount,
        max(0, maximumAttempts - resolvedStableAttemptCount),
      )
      let rescueRotationRadians = randomAngleRadians(
        in: rotationRangeDegrees,
        using: &randomGenerator,
      )
      if rescueAttemptIndex < resolvedRotationRescueAttemptCount {
        return BaseParameters(
          scale: baseScale,
          rotationRadians: rescueRotationRadians,
        )
      }

      return BaseParameters(
        scale: rescueScale(
          for: rescueAttemptIndex - resolvedRotationRescueAttemptCount,
          using: &randomGenerator,
        ),
        rotationRadians: rescueRotationRadians,
      )
    }

    private func rescueScale(
      for attemptIndex: Int,
      using randomGenerator: inout some RandomNumberGenerator,
    ) -> Double {
      let lowerBound = max(0, scaleRange.lowerBound)
      let upperBound = max(lowerBound, max(0, scaleRange.upperBound))
      guard upperBound > lowerBound else { return lowerBound }

      let rescueScaleAttemptCount = max(1, maximumAttempts - stableAttemptCount - rotationRescueAttemptCount)
      if attemptIndex >= rescueScaleAttemptCount - 1 {
        return lowerBound
      }

      let progress = Double(attemptIndex + 1) / Double(rescueScaleAttemptCount)
      let sampledUnit = Double.random(in: 0...1, using: &randomGenerator)
      let lowerBiasedUnit = pow(sampledUnit, 1 + progress * 2)
      return lowerBound + (upperBound - lowerBound) * lowerBiasedUnit
    }
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

  private static func preferredBoundingRadius(
    for symbol: PlacementSymbolDescriptor,
    maximumScaleMultiplier: CGFloat,
  ) -> CGFloat {
    var maximumRadius: CGFloat = 0
    for renderSymbol in symbol.renderableLeafDescriptors {
      let maximumScale = max(0, renderSymbol.resolvedScaleRange.upperBound) * Double(maximumScaleMultiplier)
      let radius = renderSymbol.collisionShape.boundingRadius(atScale: CGFloat(maximumScale))
      maximumRadius = max(maximumRadius, radius)
    }
    return maximumRadius
  }

  private enum SymbolSelectionMode {
    case defaultWeights
    case prefersLargerSymbols
    case stronglyPrefersLargerSymbols
    case prefersSmallerSymbols
    case stronglyPrefersSmallerSymbols

    var biasRange: ClosedRange<Double> {
      switch self {
      case .defaultWeights:
        1...1
      case .prefersLargerSymbols:
        1...2
      case .stronglyPrefersLargerSymbols:
        1...3
      case .prefersSmallerSymbols:
        1...2
      case .stronglyPrefersSmallerSymbols:
        1...3
      }
    }
  }

  private static func symbolSelectionMode(
    fillStrategy: PlacementModel.OrganicFillStrategy,
    placedCount: Int,
    targetCount: Int,
    saturationStopState: SaturationStopState,
    usesFillerRecovery: Bool = false,
  ) -> SymbolSelectionMode {
    if usesFillerRecovery {
      return .stronglyPrefersSmallerSymbols
    }
    if saturationStopState.shouldUseCandidateRescue {
      return .stronglyPrefersSmallerSymbols
    }
    if saturationStopState.shouldPreferOpenCells {
      return .prefersSmallerSymbols
    }

    guard fillStrategy == .dense, targetCount > 0 else { return .defaultWeights }

    let progress = Double(placedCount) / Double(targetCount)
    if progress >= DenseFillTuning.stronglySmallerPhaseStart {
      return .stronglyPrefersSmallerSymbols
    }
    if progress >= DenseFillTuning.smallerPhaseStart {
      return .prefersSmallerSymbols
    }
    if progress < DenseFillTuning.stronglyLargerPhaseEnd {
      return .stronglyPrefersLargerSymbols
    }
    if progress < DenseFillTuning.largerPhaseEnd {
      return .prefersLargerSymbols
    }

    return .defaultWeights
  }

  private static func placementProgress(
    placedCount: Int,
    targetCount: Int,
  ) -> Double {
    guard targetCount > 0 else { return 1 }

    return min(1, max(0, Double(placedCount) / Double(targetCount)))
  }

  private static func pickSymbol(
    from symbols: [PlacementSymbolDescriptor],
    symbolBoundingRadiusByID: [UUID: CGFloat],
    selectionMode: SymbolSelectionMode,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> PlacementSymbolDescriptor? {
    // Weighted pick to preserve caller-defined symbol frequencies.
    guard symbols.isEmpty == false else { return nil }

    let knownRadii = symbolBoundingRadiusByID.values
    let minimumRadius = knownRadii.min() ?? 0
    let maximumRadius = knownRadii.max() ?? minimumRadius

    var totalWeight = 0.0
    for symbol in symbols {
      let selectionWeight = effectiveSelectionWeight(
        for: symbol,
        symbolBoundingRadiusByID: symbolBoundingRadiusByID,
        minimumRadius: minimumRadius,
        maximumRadius: maximumRadius,
        selectionMode: selectionMode,
      )
      if selectionWeight.isFinite {
        totalWeight += max(0, selectionWeight)
      }
    }

    guard totalWeight > 0 else { return symbols.randomElement(using: &randomGenerator) }

    let randomValue = Double.random(in: 0..<totalWeight, using: &randomGenerator)
    var accumulator = 0.0

    for symbol in symbols {
      let selectionWeight = effectiveSelectionWeight(
        for: symbol,
        symbolBoundingRadiusByID: symbolBoundingRadiusByID,
        minimumRadius: minimumRadius,
        maximumRadius: maximumRadius,
        selectionMode: selectionMode,
      )
      if selectionWeight.isFinite {
        accumulator += max(0, selectionWeight)
      }
      if randomValue < accumulator {
        return symbol
      }
    }

    return symbols.last
  }

  private static func effectiveSelectionWeight(
    for symbol: PlacementSymbolDescriptor,
    symbolBoundingRadiusByID: [UUID: CGFloat],
    minimumRadius: CGFloat,
    maximumRadius: CGFloat,
    selectionMode: SymbolSelectionMode,
  ) -> Double {
    let baseWeight = max(0, symbol.weight)
    guard baseWeight > 0 else { return 0 }
    guard selectionMode != .defaultWeights else { return baseWeight }

    let radius = symbolBoundingRadiusByID[symbol.id] ?? maximumRadius
    let radiusSpan = maximumRadius - minimumRadius
    let normalizedRadius = radiusSpan > 0 ? (radius - minimumRadius) / radiusSpan : 1
    let sizeScore = switch selectionMode {
    case .defaultWeights:
      CGFloat(0)
    case .prefersLargerSymbols, .stronglyPrefersLargerSymbols:
      min(1, max(0, normalizedRadius))
    case .prefersSmallerSymbols, .stronglyPrefersSmallerSymbols:
      1 - min(1, max(0, normalizedRadius))
    }
    let biasRange = selectionMode.biasRange
    let biasFactor = biasRange.lowerBound + (biasRange.upperBound - biasRange.lowerBound) * Double(sizeScore)
    return baseWeight * biasFactor
  }

  private static func samplePosition(
    in size: CGSize,
    region: TesseraResolvedPolygonRegion?,
    regionPointSampler: RegionPointSampler?,
    alphaMaskContains: ((CGPoint) -> Bool)?,
    sparseMaskPointSampler: SparseMaskPointSampler?,
    spatialIndex: OrganicSpatialIndex,
    cellSize: CGFloat,
    prefersOpenCells: Bool,
    fillStrategy: PlacementModel.OrganicFillStrategy,
    placedProgress: Double,
    diagnostics: ShapePlacementCollision.Diagnostics?,
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
        if let alphaMaskContains, alphaMaskContains(point) == false {
          diagnostics?.centerPointMaskRejects += 1
          continue
        }
        return point
      }
      return nil
    }

    if fillStrategy == .dense,
       placedProgress >= 0.35,
       let point = gapBiasedPoint(
         in: size,
         region: region,
         alphaMaskContains: alphaMaskContains,
         spatialIndex: spatialIndex,
         cellSize: cellSize,
         placedProgress: placedProgress,
         diagnostics: diagnostics,
         using: &randomGenerator,
       ) {
      return point
    }

    if prefersOpenCells,
       let point = occupancyBiasedPoint(
         in: size,
         region: region,
         alphaMaskContains: alphaMaskContains,
         spatialIndex: spatialIndex,
         cellSize: cellSize,
         diagnostics: diagnostics,
         using: &randomGenerator,
       ) {
      return point
    }

    guard let point = randomPoint(
      in: size,
      region: region,
      regionPointSampler: regionPointSampler,
      using: &randomGenerator,
    ) else { return nil }

    if let alphaMaskContains, alphaMaskContains(point) == false {
      diagnostics?.centerPointMaskRejects += 1
      return nil
    }

    return point
  }

  private static func gapBiasedPoint(
    in size: CGSize,
    region: TesseraResolvedPolygonRegion?,
    alphaMaskContains: ((CGPoint) -> Bool)?,
    spatialIndex: OrganicSpatialIndex,
    cellSize: CGFloat,
    placedProgress: Double,
    diagnostics: ShapePlacementCollision.Diagnostics?,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> CGPoint? {
    let totalCellCount = spatialIndex.colliderIndicesByCellIndex.count
    guard totalCellCount > 0 else { return nil }

    let candidateCellCount = min(12, totalCellCount)
    let maximumPointAttempts = placedProgress >= 0.55 ? 8 : 5

    for _ in 0..<maximumPointAttempts {
      var preferredCellIndex: Int?
      var preferredCellScore = -Double.greatestFiniteMagnitude

      for _ in 0..<candidateCellCount {
        let candidateCellIndex = Int.random(in: 0..<totalCellCount, using: &randomGenerator)
        let occupancy = spatialIndex.colliderIndicesByCellIndex[candidateCellIndex].count
        let neighboringOccupancy = spatialIndex.neighboringOccupancy(around: candidateCellIndex)

        guard neighboringOccupancy > 0 else { continue }

        let openScore = 1 / Double(occupancy + 1)
        let pocketScore = min(Double(neighboringOccupancy), 8) / 8
        let lateOpenPocketWeight = 0.45 + min(1, max(0, placedProgress)) * 0.55
        let jitter = Double.random(in: 0..<0.08, using: &randomGenerator)
        let score = openScore * lateOpenPocketWeight + pocketScore * (1 - lateOpenPocketWeight) + jitter

        if score > preferredCellScore {
          preferredCellIndex = candidateCellIndex
          preferredCellScore = score
        }
      }

      guard let preferredCellIndex,
            let point = spatialIndex.randomPoint(
              inCellAt: preferredCellIndex,
              cellSize: cellSize,
              tileSize: size,
              using: &randomGenerator,
            )
      else { continue }

      if let region, region.contains(point) == false {
        continue
      }
      if let alphaMaskContains, alphaMaskContains(point) == false {
        diagnostics?.centerPointMaskRejects += 1
        continue
      }
      return point
    }

    return nil
  }

  private static func occupancyBiasedPoint(
    in size: CGSize,
    region: TesseraResolvedPolygonRegion?,
    alphaMaskContains: ((CGPoint) -> Bool)?,
    spatialIndex: OrganicSpatialIndex,
    cellSize: CGFloat,
    diagnostics: ShapePlacementCollision.Diagnostics?,
    using randomGenerator: inout some RandomNumberGenerator,
  ) -> CGPoint? {
    let candidateCellCount = min(4, spatialIndex.colliderIndicesByCellIndex.count)
    guard candidateCellCount > 0 else { return nil }

    for _ in 0..<4 {
      var preferredCellIndex: Int?
      var preferredCellOccupancy = Int.max

      for _ in 0..<candidateCellCount {
        let candidateCellIndex = Int.random(
          in: 0..<spatialIndex.colliderIndicesByCellIndex.count,
          using: &randomGenerator,
        )
        let occupancy = spatialIndex.colliderIndicesByCellIndex[candidateCellIndex].count
        if occupancy < preferredCellOccupancy {
          preferredCellIndex = candidateCellIndex
          preferredCellOccupancy = occupancy
        }
      }

      guard let preferredCellIndex,
            let point = spatialIndex.randomPoint(
              inCellAt: preferredCellIndex,
              cellSize: cellSize,
              tileSize: size,
              using: &randomGenerator,
            )
      else { continue }

      if let region, region.contains(point) == false {
        continue
      }
      if let alphaMaskContains, alphaMaskContains(point) == false {
        diagnostics?.centerPointMaskRejects += 1
        continue
      }
      return point
    }

    return nil
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
      mask: any DiscretePlacementMask,
      filledFraction: Double,
      maximumFilledFraction: Double = 0.35,
      minimumAcceptedPixelCount: Int = 32,
    ) {
      guard mask.sampling == .nearest else { return nil }
      guard filledFraction > 0, filledFraction <= maximumFilledFraction else { return nil }

      var acceptedPixelIndices: [Int] = []
      acceptedPixelIndices.reserveCapacity(
        max(minimumAcceptedPixelCount, max(mask.rasterPixelsWide * mask.rasterPixelsHigh, 1) / 10),
      )

      mask.forEachRasterSample { index, value in
        let visible = value >= mask.thresholdByte
        let included = mask.invert ? !visible : visible
        if included {
          acceptedPixelIndices.append(index)
        }
      }

      guard acceptedPixelIndices.count >= minimumAcceptedPixelCount else { return nil }

      pointSize = mask.rasterSize
      pixelsWide = mask.rasterPixelsWide
      pixelsHigh = mask.rasterPixelsHigh
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
      let isCounterClockwise = OrganicShapePlacementEngine.signedArea(of: remainingPoints) > 0
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

      let area = abs(OrganicShapePlacementEngine.signedArea(of: points))
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
