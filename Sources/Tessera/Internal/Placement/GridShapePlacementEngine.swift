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
          let subgridSymbolCount = subgridContext.symbolDescriptors.count
          guard subgridSymbolCount > 0 else { continue }

          let resolvedSymbolIndex: Int
          switch subgridContext.symbolOrder {
          case .rowMajor, .columnMajor:
            resolvedSymbolIndex = subgridAssignment.localAssignmentIndex
          case .diagonal:
            resolvedSymbolIndex = subgridAssignment.localRowIndex + subgridAssignment.localColumnIndex
          case .snake:
            let snakeColumn = subgridAssignment.localRowIndex.isMultiple(of: 2)
              ? subgridAssignment.localColumnIndex
              : (subgridContext.area.columnCount - 1 - subgridAssignment.localColumnIndex)
            resolvedSymbolIndex = subgridAssignment.localRowIndex * subgridContext.area.columnCount + snakeColumn
          case .shuffle:
            resolvedSymbolIndex = subgridContext.shuffledSymbolIndices?[subgridAssignment.localAssignmentIndex] ??
              subgridAssignment.localAssignmentIndex
          case .randomWeightedPerCell:
            var randomGenerator = SeededGenerator(
              seed: GridSymbolAssignment.symbolSeed(
                baseSeed: subgridContext.seed,
                rowIndex: subgridAssignment.localRowIndex,
                columnIndex: subgridAssignment.localColumnIndex,
                cellIndex: subgridAssignment.localAssignmentIndex,
              ),
            )
            resolvedSymbolIndex = GridSymbolAssignment.randomWeightedSymbolIndex(
              symbolCount: subgridSymbolCount,
              cumulativeWeights: subgridContext.cumulativeWeights,
              totalWeight: subgridContext.totalWeight,
              randomGenerator: &randomGenerator,
            )
          }

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
            absoluteColumnIndex: resolvedGrid.absoluteColumnIndex(forVisibleColumnIndex: visibleColumnIndex),
            countSizedAssignmentIndex: currentRegularAssignmentIndex,
          )

          let resolvedSymbolIndex: Int
          switch configuration.symbolOrder {
          case .rowMajor, .columnMajor:
            resolvedSymbolIndex = currentRegularAssignmentIndex
          case .diagonal:
            resolvedSymbolIndex = visibleRowIndex + visibleColumnIndex
          case .snake:
            let snakeColumn = visibleRowIndex.isMultiple(of: 2)
              ? visibleColumnIndex
              : (resolvedGrid.columnCount - 1 - visibleColumnIndex)
            resolvedSymbolIndex = visibleRowIndex * resolvedGrid.columnCount + snakeColumn
          case .shuffle:
            resolvedSymbolIndex = shuffledSymbolIndices?[currentRegularAssignmentIndex] ?? currentRegularAssignmentIndex
          case .randomWeightedPerCell:
            var randomGenerator = SeededGenerator(
              seed: GridSymbolAssignment.symbolSeed(
                baseSeed: configuration.seed,
                rowIndex: absoluteRowIndex,
                columnIndex: resolvedGrid.absoluteColumnIndex(forVisibleColumnIndex: visibleColumnIndex),
                cellIndex: regularSeedCellIndex,
              ),
            )
            resolvedSymbolIndex = GridSymbolAssignment.randomWeightedSymbolIndex(
              symbolCount: regularSymbolCount,
              cumulativeWeights: cumulativeWeights,
              totalWeight: totalWeight,
              randomGenerator: &randomGenerator,
            )
          }

          selectedSymbol = regularSymbolDescriptors[resolvedSymbolIndex % regularSymbolCount]
          symbolSeedRowIndex = absoluteRowIndex
          symbolSeedColumnIndex = resolvedGrid.absoluteColumnIndex(forVisibleColumnIndex: visibleColumnIndex)
          symbolSeedCellIndex = regularSeedCellIndex
        }

        let choiceSeed = GridSymbolAssignment.choiceSeed(
          baseSeed: configuration.seed,
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
        ) else { continue }

        let baseRotationRadians = rotationRadiansForGrid(
          rangeDegrees: selectedRenderSymbol.allowedRotationRangeDegrees,
          baseSeed: configuration.seed,
          rowIndex: symbolSeedRowIndex,
          columnIndex: symbolSeedColumnIndex,
          cellIndex: symbolSeedCellIndex,
        )

        guard let selectedPolygons = polygonCache[selectedRenderSymbol.id] else { continue }

        let basePosition = gridCellCenter(
          absoluteColumnIndex: resolvedGrid.absoluteColumnIndex(forVisibleColumnIndex: visibleColumnIndex),
          absoluteRowIndex: absoluteRowIndex,
          grid: resolvedGrid,
        )
        let offset = gridOffset(
          for: configuration.offsetStrategy,
          normalizedOffset: normalizedOffset,
          absoluteColumnIndex: resolvedGrid.absoluteColumnIndex(forVisibleColumnIndex: visibleColumnIndex),
          absoluteRowIndex: absoluteRowIndex,
          cellSize: resolvedGrid.cellSize,
        )
        let phaseSymbolID = configuration.symbolPhases[selectedRenderSymbol.id] == nil
          ? selectedSymbol.id
          : selectedRenderSymbol.id
        let symbolPhaseOffset = symbolPhaseOffset(
          for: phaseSymbolID,
          symbolPhases: configuration.symbolPhases,
          cellSize: resolvedGrid.cellSize,
        )
        var position = CGPoint(
          x: placementRect.minX + basePosition.x + offset.width + symbolPhaseOffset.width,
          y: placementRect.minY + basePosition.y + offset.height + symbolPhaseOffset.height,
        )

        switch edgeBehavior {
        case .finite:
          guard (0..<size.width).contains(position.x),
                (0..<size.height).contains(position.y)
          else { continue }

        case .seamlessWrapping:
          position = ShapePlacementWrapping.wrappedPosition(position, in: size)
        }

        if let region, region.contains(position) == false {
          continue
        }

        if let maskContains, maskContains(position) == false {
          continue
        }

        let scaleMultiplier = max(
          0,
          ShapePlacementSteering.value(
            for: configuration.steering.scaleMultiplier,
            position: position,
            canvasSize: size,
            defaultValue: 1,
          ),
        )
        let baseScale = selectedRenderSymbol.resolvedScaleRange.lowerBound
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

        let candidateCollisionShape = selectedRenderSymbol.collisionShape
        let candidateTransform = CollisionTransform(
          position: position,
          rotation: CGFloat(rotationRadians),
          scale: CGFloat(scale),
        )

        if let maskContains,
           ShapePlacementMaskConstraint.isPlacementInsideMask(
             contains: maskContains,
             collisionTransform: candidateTransform,
             polygons: selectedPolygons,
             mode: maskConstraintMode,
             centerAlreadyValidated: true,
           ) == false {
          continue
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
            tileSize: size,
            edgeBehavior: edgeBehavior,
            wrapOffsets: wrapOffsets,
          )

          guard isValid else { continue }
        }

        choiceSequenceState = tentativeChoiceSequenceState
        let candidate = PlacedSymbolDescriptor(
          symbolId: selectedSymbol.id,
          renderSymbolId: selectedRenderSymbol.id,
          zIndex: selectedSymbol.zIndex,
          sourceOrder: selectedSymbol.sourceOrder,
          position: position,
          rotationRadians: rotationRadians,
          scale: CGFloat(scale),
          collisionShape: candidateCollisionShape,
        )
        placedDescriptors.append(candidate)
      }
    }

    return placedDescriptors
  }

  static func resolveAcceptedSubgridAreas(
    subgrids: [PlacementModel.Grid.Subgrid],
    grid: ResolvedGrid,
    knownSymbolIDs: Set<UUID>? = nil,
  ) -> [ResolvedSubgridArea] {
    var acceptedSubgrids: [ResolvedSubgridArea] = []

    for subgrid in subgrids {
      guard let candidateArea = resolvedSubgridArea(
        for: subgrid,
        in: grid,
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

    for subgrid in subgrids {
      let origin = subgrid.origin
      let span = subgrid.span
      // Invalid or unresolved subgrids are skipped so remaining grid placement can proceed.
      guard origin.row >= 0, origin.column >= 0, span.rows > 0, span.columns > 0 else {
        reportIgnoredSubgrid("origin and span must be non-negative and non-zero")
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
      let resolvedSeed = subgrid.seed ?? derivedSubgridSeed(
        baseSeed: baseSeed,
        acceptedSubgridIndex: acceptedSubgridIndex,
      )
      let subgridCellCount = span.rows * span.columns

      let shuffledSymbolIndices = subgrid.symbolOrder == .shuffle
        ? GridSymbolAssignment.shuffledSymbolIndices(
          symbolCount: resolvedSymbolDescriptors.count,
          totalCellCount: subgridCellCount,
          seed: resolvedSeed,
        )
        : nil
      let cumulativeWeights = subgrid.symbolOrder == .randomWeightedPerCell
        ? GridSymbolAssignment.cumulativeWeights(for: resolvedSymbolDescriptors)
        : []
      let totalWeight = cumulativeWeights.last ?? 0

      acceptedAreas.append(resolvedArea)
      contexts.append(
        ResolvedSubgridPlacementContext(
          area: resolvedArea,
          symbolOrder: subgrid.symbolOrder,
          seed: resolvedSeed,
          symbolDescriptors: resolvedSymbolDescriptors,
          shuffledSymbolIndices: shuffledSymbolIndices,
          cumulativeWeights: cumulativeWeights,
          totalWeight: totalWeight,
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
          cellAssignments[gridIndex] = ResolvedSubgridCellAssignment(
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
    acceptedSubgridIndex: Int,
    knownSymbolIDs: Set<UUID>? = nil,
  ) -> ResolvedSubgridArea? {
    let origin = subgrid.origin
    let span = subgrid.span
    guard origin.row >= 0, origin.column >= 0, span.rows > 0, span.columns > 0 else {
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
    switch configuration.sizing {
    case let .count(columns, rows):
      let normalizedOffset = normalizedOffsetAmount(from: configuration.offsetStrategy)
      let rowNeedsEven = edgeBehavior == .seamlessWrapping && normalizedOffset > 0 && rowShiftRequiresEvenRowCount(
        for: configuration.offsetStrategy,
      )
      let columnNeedsEven = edgeBehavior == .seamlessWrapping && normalizedOffset > 0 &&
        columnShiftRequiresEvenColumnCount(
          for: configuration.offsetStrategy,
        )
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
