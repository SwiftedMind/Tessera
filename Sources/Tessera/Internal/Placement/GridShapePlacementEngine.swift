// By Dennis Müller

import CoreGraphics
import Foundation

/// Places symbols in a deterministic grid using the grid placement configuration.
enum GridShapePlacementEngine {
  typealias PlacementSymbolDescriptor = ShapePlacementEngine.PlacementSymbolDescriptor
  typealias PinnedSymbolDescriptor = ShapePlacementEngine.PinnedSymbolDescriptor
  typealias PlacedSymbolDescriptor = ShapePlacementEngine.PlacedSymbolDescriptor
  typealias PlacedCollider = ShapePlacementEngine.PlacedCollider
  typealias ResolvedGrid = ShapePlacementEngine.ResolvedGrid
  static let maximumFixedVisibleCellCountPerAxis = 1024
  static let maximumFixedLatticeIndexMagnitude = 1_000_000_000

  struct ResolvedSubgridArea: Sendable {
    var sourceSubgridIndex: Int
    var acceptedSubgridIndex: Int
    var originRowIndex: Int
    var originColumnIndex: Int
    var rowCount: Int
    var columnCount: Int
    var visibleRowRange: Range<Int>
    var visibleColumnRange: Range<Int>

    var fullRowRange: Range<Int> {
      originRowIndex..<(originRowIndex + rowCount)
    }

    var fullColumnRange: Range<Int> {
      originColumnIndex..<(originColumnIndex + columnCount)
    }
  }

  private struct ResolvedSubgridCellAssignment: Sendable {
    var acceptedSubgridIndex: Int
    var localRowIndex: Int
    var localColumnIndex: Int
    var localAssignmentIndex: Int
  }

  private struct ResolvedSubgridPlacementContext: Sendable {
    var area: ResolvedSubgridArea
    var symbolOrder: PlacementModel.GridSymbolOrder
    var seed: UInt64
    var symbolDescriptors: [PlacementSymbolDescriptor]
    var shuffledSymbolIndices: [Int]?
    var cumulativeWeights: [Double]
    var totalWeight: Double
    var localGrid: ResolvedSubgridLocalGrid?
  }

  struct ResolvedSubgridLocalGrid: Sendable {
    var resolvedGrid: ResolvedGrid
    var subgridRect: CGRect
    var offsetStrategy: PlacementModel.GridOffsetStrategy
    var normalizedOffset: Double
    var firstVisibleReservedGridIndex: Int
  }

  /// Generates placed symbol descriptors using the grid placement configuration.
  ///
  /// - Parameters:
  ///   - size: The size of the tile to populate with symbols.
  ///   - symbolDescriptors: The available symbols with resolved collision metadata.
  ///   - pinnedSymbolDescriptors: Symbols that must be placed at fixed positions before sampling.
  ///   - edgeBehavior: The edge behavior to apply when testing collisions.
  ///   - configuration: The grid placement configuration.
  ///   - region: Optional polygon region in tile space used to constrain placement.
  ///   - alphaMask: Optional alpha mask used to constrain placement.
  ///   - placementBounds: Optional canvas-space bounds used to resolve grid cell size and centers.
  ///   - maskConstraintMode: How strictly the alpha mask constrains collision geometry.
  /// - Returns: The placed symbol descriptors for the tile.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor],
    edgeBehavior: TesseraEdgeBehavior,
    configuration: PlacementModel.Grid,
    region: TesseraResolvedPolygonRegion? = nil,
    alphaMask: (any PlacementMask)? = nil,
    placementBounds: CGRect? = nil,
    maskConstraintMode: ShapePlacementMaskConstraint.Mode = .sampledCollisionGeometry,
  ) -> [PlacedSymbolDescriptor] {
    guard size.width > 0, size.height > 0 else { return [] }

    let symbolCount = symbolDescriptors.count
    guard symbolCount > 0 else { return [] }

    let placementRect = resolvedPlacementRect(
      in: size,
      placementBounds: placementBounds,
    )
    let resolvedGrid = resolveGrid(
      for: placementRect.size,
      configuration: configuration,
      edgeBehavior: edgeBehavior,
    )
    guard let totalCellCount = resolvedGrid.safeTotalCellCount else { return [] }

    let renderableLeafDescriptors = symbolDescriptors.flatMap(\.renderableLeafDescriptors)
    let topLevelSymbolDescriptorsByID: [UUID: PlacementSymbolDescriptor] = symbolDescriptors.reduce(into: [:]) {
      cache,
        descriptor in
      cache[descriptor.id] = descriptor
    }
    let leafSymbolDescriptorsByID: [UUID: PlacementSymbolDescriptor] = renderableLeafDescriptors.reduce(into: [:]) {
      cache,
        descriptor in
      guard cache[descriptor.id] == nil else { return }

      cache[descriptor.id] = PlacementSymbolDescriptor(
        id: descriptor.id,
        weight: 1,
        allowedRotationRangeDegrees: descriptor.allowedRotationRangeDegrees,
        resolvedScaleRange: descriptor.resolvedScaleRange,
        collisionShape: descriptor.collisionShape,
      )
    }

    let subgridResolution = resolveSubgridPlacementContexts(
      subgrids: configuration.subgrids,
      grid: resolvedGrid,
      baseSeed: configuration.seed,
      topLevelSymbolDescriptorsByID: topLevelSymbolDescriptorsByID,
      leafSymbolDescriptorsByID: leafSymbolDescriptorsByID,
    )
    let subgridContexts = subgridResolution.contexts
    let subgridCellAssignments = subgridResolution.cellAssignments
    let reservedGridIndices = subgridResolution.reservedGridIndices

    let dedicatedSubgridSymbolIDs = Set(configuration.subgrids.flatMap { subgrid in
      resolveSubgridSymbolDescriptors(
        symbolIDs: subgrid.symbolIDs,
        topLevelSymbolDescriptorsByID: topLevelSymbolDescriptorsByID,
        leafSymbolDescriptorsByID: leafSymbolDescriptorsByID,
      ).map(\.id)
    })
    let regularSymbolDescriptors = symbolDescriptors.filter { descriptor in
      guard dedicatedSubgridSymbolIDs.contains(descriptor.id) == false else {
        return false
      }

      return descriptor.renderableLeafDescriptors.contains(where: { leafDescriptor in
        dedicatedSubgridSymbolIDs.contains(leafDescriptor.id)
      }) == false
    }
    let regularSymbolCount = regularSymbolDescriptors.count
    let regularCellCount = max(0, totalCellCount - reservedGridIndices.count)

    let columnMajorRegularAssignmentIndicesByGridIndex = configuration.symbolOrder == .columnMajor
      ? makeColumnMajorRegularAssignmentIndicesByGridIndex(
        rowCount: resolvedGrid.rowCount,
        columnCount: resolvedGrid.columnCount,
        reservedGridIndices: reservedGridIndices,
      )
      : [:]

    let shuffledSymbolIndices = configuration.symbolOrder == .shuffle && regularSymbolCount > 0
      ? GridSymbolAssignment.shuffledSymbolIndices(
        symbolCount: regularSymbolCount,
        totalCellCount: regularCellCount,
        seed: configuration.seed,
      )
      : nil

    let cumulativeWeights = configuration.symbolOrder == .randomWeightedPerCell
      ? GridSymbolAssignment.cumulativeWeights(for: regularSymbolDescriptors)
      : []
    let totalWeight = cumulativeWeights.last ?? 0

    let normalizedOffset = normalizedOffsetAmount(from: configuration.offsetStrategy)
    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: edgeBehavior)
    let maskContains = alphaMask.map { PlacementMaskContainment.containsFunction(for: $0) }
    let finiteCanvasRect = edgeBehavior == .finite
      ? CGRect(origin: .zero, size: size)
      : nil
    let finiteCanvasPolygons = finiteCanvasRect.map {
      CollisionMath.polygons(for: .rectangle(center: .zero, size: $0.size))
    }
    let finiteCanvasTransform = finiteCanvasRect.map {
      CollisionTransform(
        position: CGPoint(x: $0.midX, y: $0.midY),
        rotation: 0,
        scale: 1,
      )
    }

    let pinnedColliders: [PlacedCollider] = pinnedSymbolDescriptors.map { pinnedSymbol in
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
    let pinnedIndices = Array(pinnedColliders.indices)

    let polygonCache: [UUID: [CollisionPolygon]] = renderableLeafDescriptors.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = CollisionMath.polygons(for: symbol.collisionShape)
    }

    var placedDescriptors: [PlacedSymbolDescriptor] = []
    placedDescriptors.reserveCapacity(totalCellCount)
    var choiceSequenceState = ShapePlacementEngine.ChoiceSequenceState()
    var regularAssignmentIndex = 0

    for visibleRowIndex in 0..<resolvedGrid.rowCount {
      let absoluteRowIndex = resolvedGrid.absoluteRowIndex(forVisibleRowIndex: visibleRowIndex)

      for visibleColumnIndex in 0..<resolvedGrid.columnCount {
        if Task.isCancelled { return placedDescriptors }

        let absoluteColumnIndex = resolvedGrid.absoluteColumnIndex(forVisibleColumnIndex: visibleColumnIndex)
        let gridIndex = cellIndexInGrid(
          row: visibleRowIndex,
          column: visibleColumnIndex,
          columnCount: resolvedGrid.columnCount,
        )

        let selectedSymbol: PlacementSymbolDescriptor
        let symbolSeedRowIndex: Int
        let symbolSeedColumnIndex: Int
        let symbolSeedCellIndex: Int

        if let subgridAssignment = subgridCellAssignments[gridIndex] {
          let subgridContext = subgridContexts[subgridAssignment.acceptedSubgridIndex]
          if let localGrid = subgridContext.localGrid {
            guard localGrid.firstVisibleReservedGridIndex == gridIndex else {
              continue
            }

            placedDescriptors.append(contentsOf: generateLocalSubgridPlacements(
              context: subgridContext,
              configuration: configuration,
              canvasSize: size,
              placementRect: placementRect,
              edgeBehavior: edgeBehavior,
              region: region,
              maskContains: maskContains,
              maskConstraintMode: maskConstraintMode,
              finiteCanvasRect: finiteCanvasRect,
              finiteCanvasPolygons: finiteCanvasPolygons,
              finiteCanvasTransform: finiteCanvasTransform,
              pinnedColliders: pinnedColliders,
              pinnedIndices: pinnedIndices,
              wrapOffsets: wrapOffsets,
              polygonCache: polygonCache,
              choiceSequenceState: &choiceSequenceState,
            ))
            continue
          }

          let subgridSymbolCount = subgridContext.symbolDescriptors.count
          guard subgridSymbolCount > 0 else { continue }

          let resolvedSymbolIndex = resolvedSymbolIndex(
            symbolOrder: subgridContext.symbolOrder,
            assignmentIndex: subgridAssignment.localAssignmentIndex,
            orderRowIndex: subgridAssignment.localRowIndex,
            orderColumnIndex: subgridAssignment.localColumnIndex,
            orderColumnCount: subgridContext.area.columnCount,
            shuffledSymbolIndices: subgridContext.shuffledSymbolIndices,
            randomSeedBase: subgridContext.seed,
            randomSeedRowIndex: subgridAssignment.localRowIndex,
            randomSeedColumnIndex: subgridAssignment.localColumnIndex,
            randomSeedCellIndex: subgridAssignment.localAssignmentIndex,
            symbolCount: subgridSymbolCount,
            cumulativeWeights: subgridContext.cumulativeWeights,
            totalWeight: subgridContext.totalWeight,
          )

          selectedSymbol = subgridContext.symbolDescriptors[resolvedSymbolIndex % subgridSymbolCount]
          symbolSeedRowIndex = subgridAssignment.localRowIndex
          symbolSeedColumnIndex = subgridAssignment.localColumnIndex
          symbolSeedCellIndex = subgridAssignment.localAssignmentIndex
        } else {
          guard regularSymbolCount > 0 else { continue }

          let currentRegularAssignmentIndex: Int
          if configuration.symbolOrder == .columnMajor {
            guard let columnMajorIndex = columnMajorRegularAssignmentIndicesByGridIndex[gridIndex] else {
              preconditionFailure("Missing column-major assignment index for regular grid index \(gridIndex)")
            }

            currentRegularAssignmentIndex = columnMajorIndex
          } else {
            currentRegularAssignmentIndex = regularAssignmentIndex
          }
          regularAssignmentIndex += 1
          let regularSeedCellIndex = regularGridSeedCellIndex(
            for: resolvedGrid,
            absoluteRowIndex: absoluteRowIndex,
            absoluteColumnIndex: absoluteColumnIndex,
            countSizedAssignmentIndex: currentRegularAssignmentIndex,
          )

          let resolvedSymbolIndex = resolvedSymbolIndex(
            symbolOrder: configuration.symbolOrder,
            assignmentIndex: currentRegularAssignmentIndex,
            orderRowIndex: visibleRowIndex,
            orderColumnIndex: visibleColumnIndex,
            orderColumnCount: resolvedGrid.columnCount,
            shuffledSymbolIndices: shuffledSymbolIndices,
            randomSeedBase: configuration.seed,
            randomSeedRowIndex: absoluteRowIndex,
            randomSeedColumnIndex: absoluteColumnIndex,
            randomSeedCellIndex: regularSeedCellIndex,
            symbolCount: regularSymbolCount,
            cumulativeWeights: cumulativeWeights,
            totalWeight: totalWeight,
          )

          selectedSymbol = regularSymbolDescriptors[resolvedSymbolIndex % regularSymbolCount]
          symbolSeedRowIndex = absoluteRowIndex
          symbolSeedColumnIndex = absoluteColumnIndex
          symbolSeedCellIndex = regularSeedCellIndex
        }

        let basePosition = gridCellCenter(
          absoluteColumnIndex: absoluteColumnIndex,
          absoluteRowIndex: absoluteRowIndex,
          grid: resolvedGrid,
        )
        let offset = gridOffset(
          for: configuration.offsetStrategy,
          normalizedOffset: normalizedOffset,
          absoluteColumnIndex: absoluteColumnIndex,
          absoluteRowIndex: absoluteRowIndex,
          cellSize: resolvedGrid.cellSize,
        )
        guard let candidate = resolvePlacedSymbolDescriptor(
          selectedSymbol: selectedSymbol,
          baseSeed: configuration.seed,
          symbolSeedRowIndex: symbolSeedRowIndex,
          symbolSeedColumnIndex: symbolSeedColumnIndex,
          symbolSeedCellIndex: symbolSeedCellIndex,
          basePosition: basePosition,
          gridOffset: offset,
          symbolPhases: configuration.symbolPhases,
          phaseCellSize: resolvedGrid.cellSize,
          positionOrigin: placementRect.origin,
          steering: configuration.steering,
          canvasSize: size,
          edgeBehavior: edgeBehavior,
          region: region,
          maskContains: maskContains,
          maskConstraintMode: maskConstraintMode,
          finiteCanvasRect: finiteCanvasRect,
          finiteCanvasPolygons: finiteCanvasPolygons,
          finiteCanvasTransform: finiteCanvasTransform,
          pinnedColliders: pinnedColliders,
          pinnedIndices: pinnedIndices,
          wrapOffsets: wrapOffsets,
          polygonCache: polygonCache,
          choiceSequenceState: &choiceSequenceState,
        ) else {
          continue
        }

        placedDescriptors.append(candidate)
      }
    }

    return placedDescriptors
  }

  private static func generateLocalSubgridPlacements(
    context: ResolvedSubgridPlacementContext,
    configuration: PlacementModel.Grid,
    canvasSize: CGSize,
    placementRect: CGRect,
    edgeBehavior: TesseraEdgeBehavior,
    region: TesseraResolvedPolygonRegion?,
    maskContains: ((CGPoint) -> Bool)?,
    maskConstraintMode: ShapePlacementMaskConstraint.Mode,
    finiteCanvasRect: CGRect?,
    finiteCanvasPolygons: [CollisionPolygon]?,
    finiteCanvasTransform: CollisionTransform?,
    pinnedColliders: [PlacedCollider],
    pinnedIndices: [Int],
    wrapOffsets: [CGPoint],
    polygonCache: [UUID: [CollisionPolygon]],
    choiceSequenceState: inout ShapePlacementEngine.ChoiceSequenceState,
  ) -> [PlacedSymbolDescriptor] {
    guard let localGrid = context.localGrid else { return [] }

    let localResolvedGrid = localGrid.resolvedGrid
    guard let totalCellCount = localResolvedGrid.safeTotalCellCount, totalCellCount > 0 else {
      return []
    }

    let localPositionOrigin = CGPoint(
      x: placementRect.minX + localGrid.subgridRect.minX,
      y: placementRect.minY + localGrid.subgridRect.minY,
    )
    var descriptors: [PlacedSymbolDescriptor] = []
    descriptors.reserveCapacity(totalCellCount)

    for visibleRowIndex in 0..<localResolvedGrid.rowCount {
      let absoluteRowIndex = localResolvedGrid.absoluteRowIndex(forVisibleRowIndex: visibleRowIndex)

      for visibleColumnIndex in 0..<localResolvedGrid.columnCount {
        let absoluteColumnIndex = localResolvedGrid.absoluteColumnIndex(forVisibleColumnIndex: visibleColumnIndex)
        let gridIndex = cellIndexInGrid(
          row: visibleRowIndex,
          column: visibleColumnIndex,
          columnCount: localResolvedGrid.columnCount,
        )
        let currentAssignmentIndex = context.symbolOrder == .columnMajor
          ? cellIndexInGrid(
            row: visibleColumnIndex,
            column: visibleRowIndex,
            columnCount: localResolvedGrid.rowCount,
          )
          : gridIndex

        let symbolCount = context.symbolDescriptors.count
        guard symbolCount > 0 else { continue }

        let seedCellIndex = regularGridSeedCellIndex(
          for: localResolvedGrid,
          absoluteRowIndex: absoluteRowIndex,
          absoluteColumnIndex: absoluteColumnIndex,
          countSizedAssignmentIndex: currentAssignmentIndex,
        )
        let resolvedSymbolIndex = resolvedSymbolIndex(
          symbolOrder: context.symbolOrder,
          assignmentIndex: currentAssignmentIndex,
          orderRowIndex: visibleRowIndex,
          orderColumnIndex: visibleColumnIndex,
          orderColumnCount: localResolvedGrid.columnCount,
          shuffledSymbolIndices: context.shuffledSymbolIndices,
          randomSeedBase: context.seed,
          randomSeedRowIndex: absoluteRowIndex,
          randomSeedColumnIndex: absoluteColumnIndex,
          randomSeedCellIndex: seedCellIndex,
          symbolCount: symbolCount,
          cumulativeWeights: context.cumulativeWeights,
          totalWeight: context.totalWeight,
        )

        let selectedSymbol = context.symbolDescriptors[resolvedSymbolIndex % symbolCount]
        let basePosition = gridCellCenter(
          absoluteColumnIndex: absoluteColumnIndex,
          absoluteRowIndex: absoluteRowIndex,
          grid: localResolvedGrid,
        )
        let offset = localSubgridGridOffset(
          for: localGrid.offsetStrategy,
          normalizedOffset: localGrid.normalizedOffset,
          absoluteColumnIndex: absoluteColumnIndex,
          absoluteRowIndex: absoluteRowIndex,
          cellSize: localResolvedGrid.cellSize,
          rowCount: localResolvedGrid.rowCount,
          columnCount: localResolvedGrid.columnCount,
        )

        guard let candidate = resolvePlacedSymbolDescriptor(
          selectedSymbol: selectedSymbol,
          baseSeed: configuration.seed,
          symbolSeedRowIndex: absoluteRowIndex,
          symbolSeedColumnIndex: absoluteColumnIndex,
          symbolSeedCellIndex: seedCellIndex,
          basePosition: basePosition,
          gridOffset: offset,
          symbolPhases: configuration.symbolPhases,
          phaseCellSize: localResolvedGrid.cellSize,
          positionOrigin: localPositionOrigin,
          steering: configuration.steering,
          canvasSize: canvasSize,
          edgeBehavior: edgeBehavior,
          region: region,
          maskContains: maskContains,
          maskConstraintMode: maskConstraintMode,
          finiteCanvasRect: finiteCanvasRect,
          finiteCanvasPolygons: finiteCanvasPolygons,
          finiteCanvasTransform: finiteCanvasTransform,
          pinnedColliders: pinnedColliders,
          pinnedIndices: pinnedIndices,
          wrapOffsets: wrapOffsets,
          polygonCache: polygonCache,
          choiceSequenceState: &choiceSequenceState,
        ) else {
          continue
        }

        descriptors.append(candidate)
      }
    }

    return descriptors
  }

  private static func resolvePlacedSymbolDescriptor(
    selectedSymbol: PlacementSymbolDescriptor,
    baseSeed: UInt64,
    symbolSeedRowIndex: Int,
    symbolSeedColumnIndex: Int,
    symbolSeedCellIndex: Int,
    basePosition: CGPoint,
    gridOffset: CGSize,
    symbolPhases: [UUID: PlacementModel.Grid.SymbolPhase],
    phaseCellSize: CGSize,
    positionOrigin: CGPoint,
    steering: PlacementModel.GridSteering,
    canvasSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
    region: TesseraResolvedPolygonRegion?,
    maskContains: ((CGPoint) -> Bool)?,
    maskConstraintMode: ShapePlacementMaskConstraint.Mode,
    finiteCanvasRect: CGRect?,
    finiteCanvasPolygons: [CollisionPolygon]?,
    finiteCanvasTransform: CollisionTransform?,
    pinnedColliders: [PlacedCollider],
    pinnedIndices: [Int],
    wrapOffsets: [CGPoint],
    polygonCache: [UUID: [CollisionPolygon]],
    choiceSequenceState: inout ShapePlacementEngine.ChoiceSequenceState,
  ) -> PlacedSymbolDescriptor? {
    let choiceSeed = GridSymbolAssignment.choiceSeed(
      baseSeed: baseSeed,
      rowIndex: symbolSeedRowIndex,
      columnIndex: symbolSeedColumnIndex,
      cellIndex: symbolSeedCellIndex,
      symbolID: selectedSymbol.id,
      symbolChoiceSeed: selectedSymbol.choiceSeed,
    )
    var choiceRandomGenerator = SeededGenerator(seed: choiceSeed)
    var tentativeChoiceSequenceState = choiceSequenceState
    guard let selectedRenderSymbol = ShapePlacementEngine.resolveLeafSymbolDescriptor(
      from: selectedSymbol,
      randomGenerator: &choiceRandomGenerator,
      sequenceState: &tentativeChoiceSequenceState,
    ) else {
      return nil
    }

    let baseRotationRadians = rotationRadiansForGrid(
      rangeDegrees: selectedRenderSymbol.allowedRotationRangeDegrees,
      baseSeed: baseSeed,
      rowIndex: symbolSeedRowIndex,
      columnIndex: symbolSeedColumnIndex,
      cellIndex: symbolSeedCellIndex,
    )

    guard let selectedPolygons = polygonCache[selectedRenderSymbol.id] else {
      return nil
    }

    let phaseSymbolID = symbolPhases[selectedRenderSymbol.id] == nil
      ? selectedSymbol.id
      : selectedRenderSymbol.id
    let symbolPhaseOffset = symbolPhaseOffset(
      for: phaseSymbolID,
      symbolPhases: symbolPhases,
      cellSize: phaseCellSize,
    )
    var position = CGPoint(
      x: positionOrigin.x + basePosition.x + gridOffset.width + symbolPhaseOffset.width,
      y: positionOrigin.y + basePosition.y + gridOffset.height + symbolPhaseOffset.height,
    )

    switch edgeBehavior {
    case .finite:
      break
    case .seamlessWrapping:
      position = ShapePlacementWrapping.wrappedPosition(position, in: canvasSize)
    }

    if let region, region.contains(position) == false {
      return nil
    }

    if let maskContains, maskContains(position) == false {
      return nil
    }

    let scaleMultiplier = max(
      0,
      ShapePlacementSteering.value(
        for: steering.scaleMultiplier,
        position: position,
        canvasSize: canvasSize,
        defaultValue: 1,
      ),
    )
    let baseScale = selectedRenderSymbol.resolvedScaleRange.lowerBound
    let scale = max(0, baseScale * scaleMultiplier)
    let rotationMultiplier = max(
      0,
      ShapePlacementSteering.value(
        for: steering.rotationMultiplier,
        position: position,
        canvasSize: canvasSize,
        defaultValue: 1,
      ),
    )
    let rotationOffsetDegrees = ShapePlacementSteering.value(
      for: steering.rotationOffsetDegrees,
      position: position,
      canvasSize: canvasSize,
      defaultValue: 0,
    )
    let rotationOffsetRadians = rotationOffsetDegrees * Double.pi / 180
    let rotationRadians = baseRotationRadians * rotationMultiplier + rotationOffsetRadians

    let candidateCollisionShape = selectedRenderSymbol.collisionShape
    let candidateTransform = CollisionTransform(
      position: position,
      rotation: CGFloat(rotationRadians),
      scale: CGFloat(scale),
    )

    if let finiteCanvasRect,
       let finiteCanvasPolygons,
       let finiteCanvasTransform,
       placementIntersectsFiniteCanvas(
         polygons: selectedPolygons,
         collisionTransform: candidateTransform,
         boundingRadius: candidateCollisionShape.boundingRadius(atScale: candidateTransform.scale),
         finiteCanvasRect: finiteCanvasRect,
         finiteCanvasPolygons: finiteCanvasPolygons,
         finiteCanvasTransform: finiteCanvasTransform,
       ) == false {
      return nil
    }

    if let maskContains,
       ShapePlacementMaskConstraint.isPlacementInsideMask(
         contains: maskContains,
         collisionTransform: candidateTransform,
         polygons: selectedPolygons,
         mode: maskConstraintMode,
         centerAlreadyValidated: true,
       ) == false {
      return nil
    }

    let candidateCollision = ShapePlacementCollision.PlacementCandidate(
      collisionShape: candidateCollisionShape,
      collisionTransform: candidateTransform,
      polygons: selectedPolygons,
      boundingRadius: candidateCollisionShape.boundingRadius(atScale: candidateTransform.scale),
      minimumSpacing: 0,
    )

    if pinnedColliders.isEmpty == false {
      let isValid = ShapePlacementCollision.isPlacementValid(
        candidate: candidateCollision,
        existingColliderIndices: pinnedIndices,
        allColliders: pinnedColliders,
        tileSize: canvasSize,
        edgeBehavior: edgeBehavior,
        wrapOffsets: wrapOffsets,
      )

      guard isValid else { return nil }
    }

    choiceSequenceState = tentativeChoiceSequenceState
    return PlacedSymbolDescriptor(
      symbolId: selectedSymbol.id,
      renderSymbolId: selectedRenderSymbol.id,
      zIndex: selectedSymbol.zIndex,
      sourceOrder: selectedSymbol.sourceOrder,
      position: position,
      rotationRadians: rotationRadians,
      scale: CGFloat(scale),
      collisionShape: candidateCollisionShape,
    )
  }

  static func resolveAcceptedSubgridAreas(
    subgrids: [PlacementModel.Grid.Subgrid],
    grid: ResolvedGrid,
    knownSymbolIDs: Set<UUID>? = nil,
  ) -> [ResolvedSubgridArea] {
    var acceptedSubgrids: [ResolvedSubgridArea] = []

    for (sourceSubgridIndex, subgrid) in subgrids.enumerated() {
      guard let candidateArea = resolvedSubgridArea(
        for: subgrid,
        in: grid,
        sourceSubgridIndex: sourceSubgridIndex,
        acceptedSubgridIndex: acceptedSubgrids.count,
        knownSymbolIDs: knownSymbolIDs,
      ) else {
        continue
      }
      guard acceptedSubgrids.contains(where: { subgridAreasOverlap($0, candidateArea) }) == false else {
        continue
      }

      acceptedSubgrids.append(candidateArea)
    }

    return acceptedSubgrids
  }

  private static func resolveSubgridPlacementContexts(
    subgrids: [PlacementModel.Grid.Subgrid],
    grid: ResolvedGrid,
    baseSeed: UInt64,
    topLevelSymbolDescriptorsByID: [UUID: PlacementSymbolDescriptor],
    leafSymbolDescriptorsByID: [UUID: PlacementSymbolDescriptor],
  ) -> (
    contexts: [ResolvedSubgridPlacementContext],
    cellAssignments: [ResolvedSubgridCellAssignment?],
    reservedGridIndices: Set<Int>,
  ) {
    guard let totalCellCount = grid.safeTotalCellCount else {
      return ([], [], [])
    }

    var reservedGridIndices: Set<Int> = []
    reservedGridIndices.reserveCapacity(totalCellCount)

    var acceptedAreas: [ResolvedSubgridArea] = []
    var contexts: [ResolvedSubgridPlacementContext] = []
    var cellAssignments = [ResolvedSubgridCellAssignment?](repeating: nil, count: totalCellCount)

    for (sourceSubgridIndex, subgrid) in subgrids.enumerated() {
      let origin = subgrid.origin
      let span = subgrid.span
      // Fixed-cell grids can expose negative lattice indices when the origin is offset into the canvas,
      // so only zero-sized spans are invalid here.
      guard span.rows > 0, span.columns > 0 else {
        reportIgnoredSubgrid("span must be non-zero")
        continue
      }
      guard subgrid.symbolIDs.isEmpty == false else {
        reportIgnoredSubgrid("symbolIDs must not be empty")
        continue
      }

      if grid.sizingSource == .count,
         origin.row + span.rows > grid.rowRange.upperBound || origin.column + span.columns > grid.columnRange
         .upperBound {
        reportIgnoredSubgrid("subgrid exceeds resolved grid bounds")
        continue
      }
      guard let resolvedArea = resolvedSubgridArea(
        for: subgrid,
        in: grid,
        sourceSubgridIndex: sourceSubgridIndex,
        acceptedSubgridIndex: contexts.count,
      ) else {
        reportIgnoredSubgrid("subgrid does not intersect the resolved grid")
        continue
      }
      guard acceptedAreas.contains(where: { subgridAreasOverlap($0, resolvedArea) }) == false else {
        reportIgnoredSubgrid("subgrid overlaps an earlier accepted subgrid")
        continue
      }

      let resolvedSymbolDescriptors = resolveSubgridSymbolDescriptors(
        symbolIDs: subgrid.symbolIDs,
        topLevelSymbolDescriptorsByID: topLevelSymbolDescriptorsByID,
        leafSymbolDescriptorsByID: leafSymbolDescriptorsByID,
      )
      guard resolvedSymbolDescriptors.isEmpty == false else {
        reportIgnoredSubgrid("no symbol IDs resolved to known symbols")
        continue
      }

      let acceptedSubgridIndex = contexts.count
      let derivedSeed = derivedSubgridSeed(
        baseSeed: baseSeed,
        acceptedSubgridIndex: acceptedSubgridIndex,
      )
      let resolvedSubgridSeed = subgrid.seed ?? derivedSeed
      let localGrid = subgrid.grid.flatMap {
        resolvedLocalSubgridGrid(
          for: $0,
          area: resolvedArea,
          in: grid,
        )
      }
      let resolvedSeed = if localGrid == nil {
        resolvedSubgridSeed
      } else {
        subgrid.grid?.seed ?? derivedSeed
      }
      let resolvedSymbolOrder = subgrid.grid?.symbolOrder ?? subgrid.symbolOrder
      let subgridCellCount: Int
      if let localGrid {
        guard let localCellCount = localGrid.resolvedGrid.safeTotalCellCount, localCellCount > 0 else {
          reportIgnoredSubgrid("local subgrid grid did not resolve any visible cells")
          continue
        }

        subgridCellCount = localCellCount
      } else {
        subgridCellCount = span.rows * span.columns
      }

      let shuffledSymbolIndices = resolvedSymbolOrder == .shuffle
        ? GridSymbolAssignment.shuffledSymbolIndices(
          symbolCount: resolvedSymbolDescriptors.count,
          totalCellCount: subgridCellCount,
          seed: resolvedSeed,
        )
        : nil
      let cumulativeWeights = resolvedSymbolOrder == .randomWeightedPerCell
        ? GridSymbolAssignment.cumulativeWeights(for: resolvedSymbolDescriptors)
        : []
      let totalWeight = cumulativeWeights.last ?? 0

      acceptedAreas.append(resolvedArea)
      contexts.append(
        ResolvedSubgridPlacementContext(
          area: resolvedArea,
          symbolOrder: resolvedSymbolOrder,
          seed: resolvedSeed,
          symbolDescriptors: resolvedSymbolDescriptors,
          shuffledSymbolIndices: shuffledSymbolIndices,
          cumulativeWeights: cumulativeWeights,
          totalWeight: totalWeight,
          localGrid: localGrid,
        ),
      )

      for absoluteRowIndex in resolvedArea.visibleRowRange {
        let visibleRowIndex = absoluteRowIndex - grid.rowRange.lowerBound
        let localRowIndex = absoluteRowIndex - origin.row

        for absoluteColumnIndex in resolvedArea.visibleColumnRange {
          let visibleColumnIndex = absoluteColumnIndex - grid.columnRange.lowerBound
          let localColumnIndex = absoluteColumnIndex - origin.column
          let gridIndex = cellIndexInGrid(
            row: visibleRowIndex,
            column: visibleColumnIndex,
            columnCount: grid.columnCount,
          )

          reservedGridIndices.insert(gridIndex)
          let cellAssignment = if localGrid == nil {
            ResolvedSubgridCellAssignment(
              acceptedSubgridIndex: acceptedSubgridIndex,
              localRowIndex: localRowIndex,
              localColumnIndex: localColumnIndex,
              localAssignmentIndex: subgridAssignmentIndex(
                for: subgrid.symbolOrder,
                rowIndex: localRowIndex,
                columnIndex: localColumnIndex,
                rowCount: span.rows,
                columnCount: span.columns,
              ),
            )
          } else {
            ResolvedSubgridCellAssignment(
              acceptedSubgridIndex: acceptedSubgridIndex,
              localRowIndex: 0,
              localColumnIndex: 0,
              localAssignmentIndex: 0,
            )
          }
          cellAssignments[gridIndex] = cellAssignment
        }
      }
    }

    return (
      contexts: contexts,
      cellAssignments: cellAssignments,
      reservedGridIndices: reservedGridIndices,
    )
  }

  private static func resolvedSubgridArea(
    for subgrid: PlacementModel.Grid.Subgrid,
    in grid: ResolvedGrid,
    sourceSubgridIndex: Int,
    acceptedSubgridIndex: Int,
    knownSymbolIDs: Set<UUID>? = nil,
  ) -> ResolvedSubgridArea? {
    let origin = subgrid.origin
    let span = subgrid.span
    guard span.rows > 0, span.columns > 0 else {
      return nil
    }
    guard subgrid.symbolIDs.isEmpty == false else {
      return nil
    }

    if let knownSymbolIDs {
      guard subgrid.symbolIDs.contains(where: { knownSymbolIDs.contains($0) }) else {
        return nil
      }
    }

    let fullRowRange = origin.row..<(origin.row + span.rows)
    let fullColumnRange = origin.column..<(origin.column + span.columns)
    if grid.sizingSource == .count {
      guard fullRowRange.lowerBound >= grid.rowRange.lowerBound,
            fullRowRange.upperBound <= grid.rowRange.upperBound,
            fullColumnRange.lowerBound >= grid.columnRange.lowerBound,
            fullColumnRange.upperBound <= grid.columnRange.upperBound
      else {
        return nil
      }
    }
    guard let visibleRowRange = intersectingRange(fullRowRange, grid.rowRange),
          let visibleColumnRange = intersectingRange(fullColumnRange, grid.columnRange)
    else {
      return nil
    }

    return ResolvedSubgridArea(
      sourceSubgridIndex: sourceSubgridIndex,
      acceptedSubgridIndex: acceptedSubgridIndex,
      originRowIndex: origin.row,
      originColumnIndex: origin.column,
      rowCount: span.rows,
      columnCount: span.columns,
      visibleRowRange: visibleRowRange,
      visibleColumnRange: visibleColumnRange,
    )
  }

  private static func intersectingRange(
    _ lhs: Range<Int>,
    _ rhs: Range<Int>,
  ) -> Range<Int>? {
    let lowerBound = max(lhs.lowerBound, rhs.lowerBound)
    let upperBound = min(lhs.upperBound, rhs.upperBound)
    guard lowerBound < upperBound else { return nil }

    return lowerBound..<upperBound
  }

  private static func subgridAreasOverlap(
    _ lhs: ResolvedSubgridArea,
    _ rhs: ResolvedSubgridArea,
  ) -> Bool {
    intersectingRange(lhs.fullRowRange, rhs.fullRowRange) != nil &&
      intersectingRange(lhs.fullColumnRange, rhs.fullColumnRange) != nil
  }

  private static func resolveSubgridSymbolDescriptors(
    symbolIDs: [UUID],
    topLevelSymbolDescriptorsByID: [UUID: PlacementSymbolDescriptor],
    leafSymbolDescriptorsByID: [UUID: PlacementSymbolDescriptor],
  ) -> [PlacementSymbolDescriptor] {
    var resolvedSymbolDescriptors: [PlacementSymbolDescriptor] = []
    var seenSymbolIDs: Set<UUID> = []

    for symbolID in symbolIDs where seenSymbolIDs.insert(symbolID).inserted {
      if let symbolDescriptor = topLevelSymbolDescriptorsByID[symbolID] ?? leafSymbolDescriptorsByID[symbolID] {
        resolvedSymbolDescriptors.append(symbolDescriptor)
      }
    }

    return resolvedSymbolDescriptors
  }

  private static func subgridAssignmentIndex(
    for symbolOrder: PlacementModel.GridSymbolOrder,
    rowIndex: Int,
    columnIndex: Int,
    rowCount: Int,
    columnCount: Int,
  ) -> Int {
    switch symbolOrder {
    case .rowMajor, .shuffle, .randomWeightedPerCell:
      return rowIndex * columnCount + columnIndex
    case .columnMajor:
      return columnIndex * rowCount + rowIndex
    case .diagonal:
      return rowIndex + columnIndex
    case .snake:
      let snakeColumn = rowIndex.isMultiple(of: 2) ? columnIndex : (columnCount - 1 - columnIndex)
      return rowIndex * columnCount + snakeColumn
    }
  }

  private static func resolvedSymbolIndex(
    symbolOrder: PlacementModel.GridSymbolOrder,
    assignmentIndex: Int,
    orderRowIndex: Int,
    orderColumnIndex: Int,
    orderColumnCount: Int,
    shuffledSymbolIndices: [Int]?,
    randomSeedBase: UInt64,
    randomSeedRowIndex: Int,
    randomSeedColumnIndex: Int,
    randomSeedCellIndex: Int,
    symbolCount: Int,
    cumulativeWeights: [Double],
    totalWeight: Double,
  ) -> Int {
    switch symbolOrder {
    case .rowMajor, .columnMajor:
      return assignmentIndex
    case .diagonal:
      return orderRowIndex + orderColumnIndex
    case .snake:
      let snakeColumn = orderRowIndex.isMultiple(of: 2)
        ? orderColumnIndex
        : (orderColumnCount - 1 - orderColumnIndex)
      return orderRowIndex * orderColumnCount + snakeColumn
    case .shuffle:
      return shuffledSymbolIndices?[assignmentIndex] ?? assignmentIndex
    case .randomWeightedPerCell:
      var randomGenerator = SeededGenerator(
        seed: GridSymbolAssignment.symbolSeed(
          baseSeed: randomSeedBase,
          rowIndex: randomSeedRowIndex,
          columnIndex: randomSeedColumnIndex,
          cellIndex: randomSeedCellIndex,
        ),
      )
      return GridSymbolAssignment.randomWeightedSymbolIndex(
        symbolCount: symbolCount,
        cumulativeWeights: cumulativeWeights,
        totalWeight: totalWeight,
        randomGenerator: &randomGenerator,
      )
    }
  }

  private static func derivedSubgridSeed(
    baseSeed: UInt64,
    acceptedSubgridIndex: Int,
  ) -> UInt64 {
    var seed = baseSeed ^ 0xD6E8_FEB8_6659_FD93
    seed ^= UInt64(truncatingIfNeeded: acceptedSubgridIndex) &* 0xA076_1D64_78BD_642F
    seed ^= seed >> 29
    return seed
  }

  private static func rotationRadiansForGrid(
    rangeDegrees: ClosedRange<Double>,
    baseSeed: UInt64,
    rowIndex: Int,
    columnIndex: Int,
    cellIndex: Int,
  ) -> Double {
    let lower = rangeDegrees.lowerBound
    let upper = rangeDegrees.upperBound
    guard upper > lower else {
      return lower * Double.pi / 180
    }

    let seed = gridRotationSeed(
      baseSeed: baseSeed,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      cellIndex: cellIndex,
    )
    var randomGenerator = SeededGenerator(seed: seed)
    let degrees = Double.random(in: lower...upper, using: &randomGenerator)
    return degrees * Double.pi / 180
  }

  private static func gridRotationSeed(
    baseSeed: UInt64,
    rowIndex: Int,
    columnIndex: Int,
    cellIndex: Int,
  ) -> UInt64 {
    var seed = baseSeed &* 0xD6E8_FEB8_6659_FD93
    seed ^= UInt64(truncatingIfNeeded: rowIndex) &* 0x9E37_79B9_7F4A_7C15
    seed ^= UInt64(truncatingIfNeeded: columnIndex) &* 0xBF58_476D_1CE4_E5B9
    seed ^= UInt64(truncatingIfNeeded: cellIndex) &* 0x94D0_49BB_1331_11EB
    seed ^= seed >> 29
    return seed
  }

  static func resolveGrid(
    for size: CGSize,
    configuration: PlacementModel.Grid,
    edgeBehavior: TesseraEdgeBehavior,
  ) -> ResolvedGrid {
    resolveGrid(
      for: size,
      sizing: configuration.sizing,
      offsetStrategy: configuration.offsetStrategy,
      edgeBehavior: edgeBehavior,
      adjustsCountSizingForSeamlessOffsets: true,
    )
  }

  private static func resolveGrid(
    for size: CGSize,
    sizing: PlacementModel.Grid.Sizing,
    offsetStrategy: PlacementModel.GridOffsetStrategy,
    edgeBehavior: TesseraEdgeBehavior,
    adjustsCountSizingForSeamlessOffsets: Bool,
  ) -> ResolvedGrid {
    switch sizing {
    case let .count(columns, rows):
      let normalizedOffset = normalizedOffsetAmount(from: offsetStrategy)
      let rowNeedsEven = adjustsCountSizingForSeamlessOffsets &&
        edgeBehavior == .seamlessWrapping &&
        normalizedOffset > 0 &&
        rowShiftRequiresEvenRowCount(for: offsetStrategy)
      let columnNeedsEven = adjustsCountSizingForSeamlessOffsets &&
        edgeBehavior == .seamlessWrapping &&
        normalizedOffset > 0 &&
        columnShiftRequiresEvenColumnCount(for: offsetStrategy)
      let columnCount = adjustedCountForOffsetRequirement(
        baseCount: columns,
        requiresEven: columnNeedsEven,
      )
      let rowCount = adjustedCountForOffsetRequirement(
        baseCount: rows,
        requiresEven: rowNeedsEven,
      )
      let resolvedCellSize = CGSize(
        width: size.width / CGFloat(columnCount),
        height: size.height / CGFloat(rowCount),
      )
      return ResolvedGrid(
        sizingSource: .count,
        columnRange: 0..<columnCount,
        rowRange: 0..<rowCount,
        cellSize: resolvedCellSize,
        origin: .zero,
      )

    case let .fixed(cellSize, origin):
      return ResolvedGrid(
        sizingSource: .fixed,
        columnRange: visibleLatticeRange(
          axisExtent: size.width,
          origin: origin.x,
          cellDimension: cellSize.width,
        ),
        rowRange: visibleLatticeRange(
          axisExtent: size.height,
          origin: origin.y,
          cellDimension: cellSize.height,
        ),
        cellSize: cellSize,
        origin: origin,
      )
    }
  }

  static func resolvedSubgridRect(
    for area: ResolvedSubgridArea,
    in grid: ResolvedGrid,
  ) -> CGRect {
    CGRect(
      x: grid.x(forLatticeColumn: area.originColumnIndex),
      y: grid.y(forLatticeRow: area.originRowIndex),
      width: CGFloat(area.columnCount) * grid.cellSize.width,
      height: CGFloat(area.rowCount) * grid.cellSize.height,
    )
  }

  private static func resolvedPlacementRect(
    in canvasSize: CGSize,
    placementBounds: CGRect?,
  ) -> CGRect {
    let canvasBounds = CGRect(origin: .zero, size: canvasSize)
    guard let placementBounds else { return canvasBounds }

    let clampedBounds = placementBounds.standardized.intersection(canvasBounds)
    guard clampedBounds.isNull == false, clampedBounds.isEmpty == false else {
      return canvasBounds
    }

    return clampedBounds
  }

  private static func visibleLatticeRange(
    axisExtent: CGFloat,
    origin: CGFloat,
    cellDimension: CGFloat,
  ) -> Range<Int> {
    let rawLowerBound = floor(-origin / cellDimension)
    let rawUpperBound = ceil((axisExtent - origin) / cellDimension)
    return boundedLatticeRange(
      rawLowerBound: rawLowerBound,
      rawUpperBound: rawUpperBound,
    )
  }

  private static func boundedLatticeRange(
    rawLowerBound: Double,
    rawUpperBound: Double,
  ) -> Range<Int> {
    let minimumIndex = -maximumFixedLatticeIndexMagnitude
    let maximumIndex = maximumFixedLatticeIndexMagnitude

    var lowerBound = clampedLatticeIndex(rawLowerBound)
    var upperBound = clampedLatticeIndex(rawUpperBound)
    if upperBound <= lowerBound {
      upperBound = min(maximumIndex, lowerBound + 1)
      if upperBound <= lowerBound {
        lowerBound = max(minimumIndex, upperBound - 1)
      }
    }

    let visibleCellCount = upperBound - lowerBound
    guard visibleCellCount > maximumFixedVisibleCellCountPerAxis else {
      return lowerBound..<upperBound
    }

    let midpoint = (rawLowerBound + rawUpperBound) * 0.5
    let halfWindow = Double(maximumFixedVisibleCellCountPerAxis) * 0.5
    lowerBound = clampedLatticeIndex(midpoint - halfWindow)
    upperBound = min(maximumIndex, lowerBound + maximumFixedVisibleCellCountPerAxis)
    if upperBound - lowerBound < maximumFixedVisibleCellCountPerAxis {
      lowerBound = max(minimumIndex, upperBound - maximumFixedVisibleCellCountPerAxis)
    }

    return lowerBound..<max(lowerBound + 1, upperBound)
  }

  private static func clampedLatticeIndex(_ value: Double) -> Int {
    guard value.isFinite else {
      return value.sign == .minus ? -maximumFixedLatticeIndexMagnitude : maximumFixedLatticeIndexMagnitude
    }

    let minimumIndex = Double(-maximumFixedLatticeIndexMagnitude)
    let maximumIndex = Double(maximumFixedLatticeIndexMagnitude)
    let clamped = min(maximumIndex, max(minimumIndex, value))
    return Int(clamped)
  }

  private static func makeColumnMajorRegularAssignmentIndicesByGridIndex(
    rowCount: Int,
    columnCount: Int,
    reservedGridIndices: Set<Int>,
  ) -> [Int: Int] {
    var indicesByGridIndex: [Int: Int] = [:]
    let (totalGridCellCount, overflow) = rowCount.multipliedReportingOverflow(by: columnCount)
    if overflow == false {
      indicesByGridIndex.reserveCapacity(max(0, totalGridCellCount - reservedGridIndices.count))
    }
    var regularAssignmentIndex = 0

    for column in 0..<columnCount {
      for row in 0..<rowCount {
        let gridIndex = cellIndexInGrid(row: row, column: column, columnCount: columnCount)
        guard reservedGridIndices.contains(gridIndex) == false else { continue }

        indicesByGridIndex[gridIndex] = regularAssignmentIndex
        regularAssignmentIndex += 1
      }
    }

    return indicesByGridIndex
  }

  private static func cellIndexInGrid(
    row: Int,
    column: Int,
    columnCount: Int,
  ) -> Int {
    row * columnCount + column
  }

  private static func regularGridSeedCellIndex(
    for grid: ResolvedGrid,
    absoluteRowIndex: Int,
    absoluteColumnIndex: Int,
    countSizedAssignmentIndex: Int,
  ) -> Int {
    switch grid.sizingSource {
    case .count:
      return countSizedAssignmentIndex
    case .fixed:
      var seed = UInt64(bitPattern: Int64(absoluteRowIndex)) &* 0x9E37_79B9_7F4A_7C15
      seed ^= UInt64(bitPattern: Int64(absoluteColumnIndex)) &* 0xBF58_476D_1CE4_E5B9
      seed ^= seed >> 29
      return Int(truncatingIfNeeded: seed)
    }
  }

  private static func placementIntersectsFiniteCanvas(
    polygons: [CollisionPolygon],
    collisionTransform: CollisionTransform,
    boundingRadius: CGFloat,
    finiteCanvasRect: CGRect,
    finiteCanvasPolygons: [CollisionPolygon],
    finiteCanvasTransform: CollisionTransform,
  ) -> Bool {
    let nearestCanvasPoint = CGPoint(
      x: min(max(collisionTransform.position.x, finiteCanvasRect.minX), finiteCanvasRect.maxX),
      y: min(max(collisionTransform.position.y, finiteCanvasRect.minY), finiteCanvasRect.maxY),
    )
    let deltaX = collisionTransform.position.x - nearestCanvasPoint.x
    let deltaY = collisionTransform.position.y - nearestCanvasPoint.y
    let distanceSquared = deltaX * deltaX + deltaY * deltaY
    guard distanceSquared <= boundingRadius * boundingRadius else {
      return false
    }

    return CollisionMath.polygonsIntersect(
      polygons,
      transformA: collisionTransform,
      finiteCanvasPolygons,
      transformB: finiteCanvasTransform,
    )
  }

  static func resolvedLocalSubgridGrid(
    for localGrid: PlacementModel.Grid.Subgrid.LocalGrid,
    area: ResolvedSubgridArea,
    in parentGrid: ResolvedGrid,
  ) -> ResolvedSubgridLocalGrid? {
    let subgridRect = resolvedSubgridRect(
      for: area,
      in: parentGrid,
    )
    let resolvedGrid = resolveGrid(
      for: subgridRect.size,
      sizing: localGrid.sizing,
      offsetStrategy: localGrid.offsetStrategy,
      edgeBehavior: .finite,
      adjustsCountSizingForSeamlessOffsets: false,
    )
    let visibleRowIndex = area.visibleRowRange.lowerBound - parentGrid.rowRange.lowerBound
    let visibleColumnIndex = area.visibleColumnRange.lowerBound - parentGrid.columnRange.lowerBound
    let firstVisibleReservedGridIndex = cellIndexInGrid(
      row: visibleRowIndex,
      column: visibleColumnIndex,
      columnCount: parentGrid.columnCount,
    )

    return ResolvedSubgridLocalGrid(
      resolvedGrid: resolvedGrid,
      subgridRect: subgridRect,
      offsetStrategy: localGrid.offsetStrategy,
      normalizedOffset: normalizedOffsetAmount(from: localGrid.offsetStrategy),
      firstVisibleReservedGridIndex: firstVisibleReservedGridIndex,
    )
  }

  private static func adjustedCountForOffsetRequirement(
    baseCount: Int,
    requiresEven: Bool,
  ) -> Int {
    guard requiresEven, baseCount.isMultiple(of: 2) == false else {
      return max(1, baseCount)
    }

    // Round up to the next even count to preserve seamless offsets.
    return max(2, baseCount + 1)
  }

  private static func localSubgridGridOffset(
    for strategy: PlacementModel.GridOffsetStrategy,
    normalizedOffset: Double,
    absoluteColumnIndex: Int,
    absoluteRowIndex: Int,
    cellSize: CGSize,
    rowCount: Int,
    columnCount: Int,
  ) -> CGSize {
    switch strategy {
    case .none:
      .zero
    case .rowShift where rowCount < 2:
      .zero
    case .columnShift where columnCount < 2:
      .zero
    case .checkerShift where rowCount < 2 || columnCount < 2:
      .zero
    case .rowShift, .columnShift, .checkerShift:
      gridOffset(
        for: strategy,
        normalizedOffset: normalizedOffset,
        absoluteColumnIndex: absoluteColumnIndex,
        absoluteRowIndex: absoluteRowIndex,
        cellSize: cellSize,
      )
    }
  }

  private static func rowShiftRequiresEvenRowCount(
    for strategy: PlacementModel.GridOffsetStrategy,
  ) -> Bool {
    switch strategy {
    case .rowShift, .checkerShift:
      true
    case .none, .columnShift:
      false
    }
  }

  private static func columnShiftRequiresEvenColumnCount(
    for strategy: PlacementModel.GridOffsetStrategy,
  ) -> Bool {
    switch strategy {
    case .columnShift, .checkerShift:
      true
    case .none, .rowShift:
      false
    }
  }

  private static func normalizedOffsetAmount(from strategy: PlacementModel.GridOffsetStrategy) -> Double {
    let offset: Double = switch strategy {
    case .none:
      0
    case let .rowShift(fraction),
         let .columnShift(fraction),
         let .checkerShift(fraction):
      fraction
    }

    guard offset.isFinite else { return 0 }

    return max(0, offset)
  }

  private static func reportIgnoredSubgrid(_ reason: String) {
    #if DEBUG
    NSLog("Tessera grid ignored subgrid: %@", reason)
    #endif
  }

  private static func gridCellCenter(
    absoluteColumnIndex: Int,
    absoluteRowIndex: Int,
    grid: ResolvedGrid,
  ) -> CGPoint {
    CGPoint(
      x: grid.x(forLatticeColumn: absoluteColumnIndex) + 0.5 * grid.cellSize.width,
      y: grid.y(forLatticeRow: absoluteRowIndex) + 0.5 * grid.cellSize.height,
    )
  }

  private static func gridOffset(
    for strategy: PlacementModel.GridOffsetStrategy,
    normalizedOffset: Double,
    absoluteColumnIndex: Int,
    absoluteRowIndex: Int,
    cellSize: CGSize,
  ) -> CGSize {
    guard normalizedOffset > 0 else { return .zero }

    let offsetX = CGFloat(normalizedOffset) * cellSize.width
    let offsetY = CGFloat(normalizedOffset) * cellSize.height

    return switch strategy {
    case .none:
      .zero
    case .rowShift:
      absoluteRowIndex.isMultiple(of: 2) ? .zero : CGSize(width: offsetX, height: 0)
    case .columnShift:
      absoluteColumnIndex.isMultiple(of: 2) ? .zero : CGSize(width: 0, height: offsetY)
    case .checkerShift:
      (absoluteRowIndex + absoluteColumnIndex).isMultiple(of: 2) ? .zero : CGSize(width: offsetX, height: offsetY)
    }
  }

  private static func symbolPhaseOffset(
    for symbolID: UUID,
    symbolPhases: [UUID: PlacementModel.Grid.SymbolPhase],
    cellSize: CGSize,
  ) -> CGSize {
    guard let phase = symbolPhases[symbolID] else { return .zero }

    let x = phase.x.isFinite ? phase.x : 0
    let y = phase.y.isFinite ? phase.y : 0
    return CGSize(
      width: CGFloat(x) * cellSize.width,
      height: CGFloat(y) * cellSize.height,
    )
  }
}
