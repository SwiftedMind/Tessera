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

  struct ResolvedSubgridArea: Sendable {
    var acceptedSubgridIndex: Int
    var rowIndex: Int
    var columnIndex: Int
    var rowCount: Int
    var columnCount: Int
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
  /// - Returns: The placed symbol descriptors for the tile.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor],
    edgeBehavior: TesseraEdgeBehavior,
    configuration: PlacementModel.Grid,
    region: TesseraResolvedPolygonRegion? = nil,
    alphaMask: TesseraAlphaMask? = nil,
  ) -> [PlacedSymbolDescriptor] {
    guard size.width > 0, size.height > 0 else { return [] }

    let symbolCount = symbolDescriptors.count
    guard symbolCount > 0 else { return [] }

    let resolvedGrid = resolveGrid(
      for: size,
      configuration: configuration,
      edgeBehavior: edgeBehavior,
    )
    let totalCellCount = resolvedGrid.totalCellCount

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

    let subgridSymbolIDs = Set(subgridContexts.flatMap { context in
      context.symbolDescriptors.map(\.id)
    })
    let regularSymbolDescriptors = symbolDescriptors.filter { descriptor in
      subgridSymbolIDs.contains(descriptor.id) == false
    }
    let regularSymbolCount = regularSymbolDescriptors.count
    let regularCellCount = max(0, totalCellCount - reservedGridIndices.count)
    if regularCellCount > 0, regularSymbolCount == 0 {
      assertionFailure("Regular grid cells remain but no regular symbols are available after subgrid reservations")
    }

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

    for rowIndex in 0..<resolvedGrid.rowCount {
      for columnIndex in 0..<resolvedGrid.columnCount {
        if Task.isCancelled { return placedDescriptors }

        let gridIndex = cellIndexInGrid(
          row: rowIndex,
          column: columnIndex,
          columnCount: resolvedGrid.columnCount,
        )

        let selectedSymbol: PlacementSymbolDescriptor
        let symbolAssignmentIndex: Int
        let symbolSeedRowIndex: Int
        let symbolSeedColumnIndex: Int

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
          symbolAssignmentIndex = subgridAssignment.localAssignmentIndex
          symbolSeedRowIndex = subgridAssignment.localRowIndex
          symbolSeedColumnIndex = subgridAssignment.localColumnIndex
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

          let resolvedSymbolIndex: Int
          switch configuration.symbolOrder {
          case .rowMajor, .columnMajor:
            resolvedSymbolIndex = currentRegularAssignmentIndex
          case .diagonal:
            resolvedSymbolIndex = rowIndex + columnIndex
          case .snake:
            let snakeColumn = rowIndex.isMultiple(of: 2) ? columnIndex : (resolvedGrid.columnCount - 1 - columnIndex)
            resolvedSymbolIndex = rowIndex * resolvedGrid.columnCount + snakeColumn
          case .shuffle:
            resolvedSymbolIndex = shuffledSymbolIndices?[currentRegularAssignmentIndex] ?? currentRegularAssignmentIndex
          case .randomWeightedPerCell:
            var randomGenerator = SeededGenerator(
              seed: GridSymbolAssignment.symbolSeed(
                baseSeed: configuration.seed,
                rowIndex: rowIndex,
                columnIndex: columnIndex,
                cellIndex: currentRegularAssignmentIndex,
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
          symbolAssignmentIndex = currentRegularAssignmentIndex
          symbolSeedRowIndex = rowIndex
          symbolSeedColumnIndex = columnIndex
        }

        let choiceSeed = GridSymbolAssignment.choiceSeed(
          baseSeed: configuration.seed,
          rowIndex: symbolSeedRowIndex,
          columnIndex: symbolSeedColumnIndex,
          cellIndex: symbolAssignmentIndex,
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
          cellIndex: symbolAssignmentIndex,
        )

        guard let selectedPolygons = polygonCache[selectedRenderSymbol.id] else { continue }

        let basePosition = gridCellCenter(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
          cellSize: resolvedGrid.cellSize,
        )
        let offset = gridOffset(
          for: configuration.offsetStrategy,
          normalizedOffset: normalizedOffset,
          columnIndex: columnIndex,
          rowIndex: rowIndex,
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
          x: basePosition.x + offset.width + symbolPhaseOffset.width,
          y: basePosition.y + offset.height + symbolPhaseOffset.height,
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

        if let alphaMask, alphaMask.contains(position) == false {
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
    let columnCount = grid.columnCount
    let rowCount = grid.rowCount
    guard columnCount > 0, rowCount > 0 else { return [] }

    var occupied = Array(repeating: false, count: rowCount * columnCount)
    var acceptedSubgrids: [ResolvedSubgridArea] = []

    for subgrid in subgrids {
      let origin = subgrid.origin
      let span = subgrid.span
      guard origin.row >= 0, origin.column >= 0, span.rows > 0, span.columns > 0 else {
        continue
      }
      guard subgrid.symbolIDs.isEmpty == false else {
        continue
      }

      if let knownSymbolIDs {
        guard subgrid.symbolIDs.contains(where: { knownSymbolIDs.contains($0) }) else {
          continue
        }
      }
      guard origin.row + span.rows <= rowCount, origin.column + span.columns <= columnCount else {
        continue
      }

      var overlapsExistingSubgrid = false
      for row in origin.row..<(origin.row + span.rows) {
        for column in origin.column..<(origin.column + span.columns) {
          if occupied[cellIndexInGrid(row: row, column: column, columnCount: columnCount)] {
            overlapsExistingSubgrid = true
            break
          }
        }
        if overlapsExistingSubgrid {
          break
        }
      }

      guard overlapsExistingSubgrid == false else { continue }

      for row in origin.row..<(origin.row + span.rows) {
        for column in origin.column..<(origin.column + span.columns) {
          occupied[cellIndexInGrid(row: row, column: column, columnCount: columnCount)] = true
        }
      }

      acceptedSubgrids.append(
        ResolvedSubgridArea(
          acceptedSubgridIndex: acceptedSubgrids.count,
          rowIndex: origin.row,
          columnIndex: origin.column,
          rowCount: span.rows,
          columnCount: span.columns,
        ),
      )
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
    let totalCellCount = grid.totalCellCount
    var occupied = Array(repeating: false, count: totalCellCount)
    var reservedGridIndices: Set<Int> = []
    reservedGridIndices.reserveCapacity(totalCellCount)

    var contexts: [ResolvedSubgridPlacementContext] = []
    var cellAssignments = [ResolvedSubgridCellAssignment?](repeating: nil, count: totalCellCount)

    for subgrid in subgrids {
      let origin = subgrid.origin
      let span = subgrid.span
      guard origin.row >= 0, origin.column >= 0, span.rows > 0, span.columns > 0 else {
        assertionFailure("Subgrid ignored: origin and span must be non-negative and non-zero")
        continue
      }
      guard subgrid.symbolIDs.isEmpty == false else {
        assertionFailure("Subgrid ignored: symbolIDs must not be empty")
        continue
      }
      guard origin.row + span.rows <= grid.rowCount, origin.column + span.columns <= grid.columnCount else {
        assertionFailure("Subgrid ignored: subgrid exceeds resolved grid bounds")
        continue
      }

      var overlapsExistingSubgrid = false
      for row in origin.row..<(origin.row + span.rows) {
        for column in origin.column..<(origin.column + span.columns) {
          if occupied[cellIndexInGrid(row: row, column: column, columnCount: grid.columnCount)] {
            overlapsExistingSubgrid = true
            break
          }
        }
        if overlapsExistingSubgrid {
          break
        }
      }

      guard overlapsExistingSubgrid == false else {
        assertionFailure("Subgrid ignored: overlapping subgrids are not supported, first valid subgrid wins")
        continue
      }

      let resolvedSymbolDescriptors = resolveSubgridSymbolDescriptors(
        symbolIDs: subgrid.symbolIDs,
        topLevelSymbolDescriptorsByID: topLevelSymbolDescriptorsByID,
        leafSymbolDescriptorsByID: leafSymbolDescriptorsByID,
      )
      guard resolvedSymbolDescriptors.isEmpty == false else {
        assertionFailure("Subgrid ignored: no symbol IDs resolved to known symbols")
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

      let resolvedArea = ResolvedSubgridArea(
        acceptedSubgridIndex: acceptedSubgridIndex,
        rowIndex: origin.row,
        columnIndex: origin.column,
        rowCount: span.rows,
        columnCount: span.columns,
      )
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

      for localRowIndex in 0..<span.rows {
        for localColumnIndex in 0..<span.columns {
          let rowIndex = origin.row + localRowIndex
          let columnIndex = origin.column + localColumnIndex
          let gridIndex = cellIndexInGrid(row: rowIndex, column: columnIndex, columnCount: grid.columnCount)

          occupied[gridIndex] = true
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
    let baseColumnCount = max(1, configuration.columnCount)
    let baseRowCount = max(1, configuration.rowCount)
    let normalizedOffset = normalizedOffsetAmount(from: configuration.offsetStrategy)
    let rowNeedsEven = edgeBehavior == .seamlessWrapping && normalizedOffset > 0 && rowShiftRequiresEvenRowCount(
      for: configuration.offsetStrategy,
    )
    let columnNeedsEven = edgeBehavior == .seamlessWrapping && normalizedOffset > 0 &&
      columnShiftRequiresEvenColumnCount(
        for: configuration.offsetStrategy,
      )
    let columnCount = adjustedCountForOffsetRequirement(
      baseCount: baseColumnCount,
      requiresEven: columnNeedsEven,
    )
    let rowCount = adjustedCountForOffsetRequirement(
      baseCount: baseRowCount,
      requiresEven: rowNeedsEven,
    )
    let resolvedCellSize = CGSize(
      width: size.width / CGFloat(columnCount),
      height: size.height / CGFloat(rowCount),
    )
    return ResolvedGrid(
      columnCount: columnCount,
      rowCount: rowCount,
      cellSize: resolvedCellSize,
    )
  }

  private static func makeColumnMajorRegularAssignmentIndicesByGridIndex(
    rowCount: Int,
    columnCount: Int,
    reservedGridIndices: Set<Int>,
  ) -> [Int: Int] {
    var indicesByGridIndex: [Int: Int] = [:]
    indicesByGridIndex.reserveCapacity(max(0, rowCount * columnCount - reservedGridIndices.count))
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

  private static func gridCellCenter(
    columnIndex: Int,
    rowIndex: Int,
    cellSize: CGSize,
  ) -> CGPoint {
    CGPoint(
      x: (CGFloat(columnIndex) + 0.5) * cellSize.width,
      y: (CGFloat(rowIndex) + 0.5) * cellSize.height,
    )
  }

  private static func gridOffset(
    for strategy: PlacementModel.GridOffsetStrategy,
    normalizedOffset: Double,
    columnIndex: Int,
    rowIndex: Int,
    cellSize: CGSize,
  ) -> CGSize {
    guard normalizedOffset > 0 else { return .zero }

    let offsetX = CGFloat(normalizedOffset) * cellSize.width
    let offsetY = CGFloat(normalizedOffset) * cellSize.height

    return switch strategy {
    case .none:
      .zero
    case .rowShift:
      rowIndex.isMultiple(of: 2) ? .zero : CGSize(width: offsetX, height: 0)
    case .columnShift:
      columnIndex.isMultiple(of: 2) ? .zero : CGSize(width: 0, height: offsetY)
    case .checkerShift:
      (rowIndex + columnIndex).isMultiple(of: 2) ? .zero : CGSize(width: offsetX, height: offsetY)
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
