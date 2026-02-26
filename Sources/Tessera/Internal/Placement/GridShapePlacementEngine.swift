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

  struct ResolvedPlacementCell: Sendable {
    var rowIndex: Int
    var columnIndex: Int
    var rowSpan: Int
    var columnSpan: Int
    var placementIndex: Int
    var mergeSymbolID: UUID?
    var mergeSymbolSizing: PlacementModel.Grid.MergedCellSymbolSizing
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
    let resolvedPlacementCells = resolvePlacementCells(
      mergedCells: configuration.mergedCells,
      grid: resolvedGrid,
    )
    let totalPlacementCount = resolvedPlacementCells.count
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
    let fixedSymbolsByPlacementIndex: [Int: PlacementSymbolDescriptor] = resolvedPlacementCells.reduce(into: [:]) {
      cache,
        cell in
      guard let mergeSymbolID = cell.mergeSymbolID else { return }

      if let descriptor = topLevelSymbolDescriptorsByID[mergeSymbolID] ?? leafSymbolDescriptorsByID[mergeSymbolID] {
        cache[cell.placementIndex] = descriptor
      }
    }
    let regularSymbolDescriptors: [PlacementSymbolDescriptor] = {
      guard configuration.excludeMergedSymbolsFromRegularCells else { return symbolDescriptors }

      let fixedMergeSymbolIDs = Set(resolvedPlacementCells.compactMap(\.mergeSymbolID))
      let filteredDescriptors = symbolDescriptors.filter { fixedMergeSymbolIDs.contains($0.id) == false }
      return filteredDescriptors.isEmpty ? symbolDescriptors : filteredDescriptors
    }()
    let regularSymbolCount = regularSymbolDescriptors.count
    let regularPlacementCount = max(0, totalPlacementCount - fixedSymbolsByPlacementIndex.count)
    let columnMajorRegularAssignmentIndicesByPlacementIndex = configuration.symbolOrder == .columnMajor
      ? makeColumnMajorRegularAssignmentIndicesByPlacementIndex(
        resolvedPlacementCells: resolvedPlacementCells,
        fixedPlacementIndices: Set(fixedSymbolsByPlacementIndex.keys),
        rowCount: resolvedGrid.rowCount,
        columnCount: resolvedGrid.columnCount,
      )
      : [:]
    let normalizedOffset = normalizedOffsetAmount(from: configuration.offsetStrategy)
    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: edgeBehavior)
    let shuffledSymbolIndices = configuration.symbolOrder == .shuffle
      ? GridSymbolAssignment.shuffledSymbolIndices(
        symbolCount: regularSymbolCount,
        totalCellCount: regularPlacementCount,
        seed: configuration.seed,
      )
      : nil

    let cumulativeWeights = configuration.symbolOrder == .randomWeightedPerCell
      ? GridSymbolAssignment.cumulativeWeights(for: regularSymbolDescriptors)
      : []
    let totalWeight = cumulativeWeights.last ?? 0

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
    placedDescriptors.reserveCapacity(totalPlacementCount)
    var choiceSequenceState = ShapePlacementEngine.ChoiceSequenceState()
    var regularAssignmentIndex = 0

    for resolvedCell in resolvedPlacementCells {
      if Task.isCancelled { return placedDescriptors }

      let rowIndex = resolvedCell.rowIndex
      let columnIndex = resolvedCell.columnIndex
      let placementIndex = resolvedCell.placementIndex

      let selectedSymbol: PlacementSymbolDescriptor
      let symbolAssignmentIndex: Int
      if let fixedSymbol = fixedSymbolsByPlacementIndex[placementIndex] {
        selectedSymbol = fixedSymbol
        symbolAssignmentIndex = placementIndex
      } else {
        let currentRegularAssignmentIndex: Int
        if configuration.symbolOrder == .columnMajor {
          guard let columnMajorIndex = columnMajorRegularAssignmentIndicesByPlacementIndex[placementIndex] else {
            preconditionFailure("Missing column-major assignment index for placement \(placementIndex)")
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
      }
      let choiceSeed = GridSymbolAssignment.choiceSeed(
        baseSeed: configuration.seed,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
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
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        cellIndex: symbolAssignmentIndex,
      )

      guard let selectedPolygons = polygonCache[selectedRenderSymbol.id] else { continue }

      let basePosition = gridCellCenter(
        columnIndex: columnIndex,
        rowIndex: rowIndex,
        columnSpan: resolvedCell.columnSpan,
        rowSpan: resolvedCell.rowSpan,
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
      let mergeSizingMultiplier: Double = switch resolvedCell.mergeSymbolSizing {
      case .natural:
        1
      case .fitMergedCell:
        mergedCellFitScaleMultiplier(
          polygons: selectedPolygons,
          rowSpan: resolvedCell.rowSpan,
          columnSpan: resolvedCell.columnSpan,
          baseCellSize: resolvedGrid.cellSize,
        )
      }
      let scale = max(0, baseScale * mergeSizingMultiplier * scaleMultiplier)
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

    return placedDescriptors
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

  static func resolvePlacementCells(
    mergedCells: [PlacementModel.Grid.CellMerge],
    grid: ResolvedGrid,
  ) -> [ResolvedPlacementCell] {
    let columnCount = grid.columnCount
    let rowCount = grid.rowCount
    guard columnCount > 0, rowCount > 0 else { return [] }

    var occupied = Array(repeating: false, count: rowCount * columnCount)
    var cells: [ResolvedPlacementCell] = []
    cells.reserveCapacity(grid.totalCellCount)

    for merge in mergedCells {
      let origin = merge.origin
      let span = merge.span
      guard origin.row >= 0, origin.column >= 0, span.rows > 0, span.columns > 0 else {
        continue
      }
      guard origin.row + span.rows <= rowCount, origin.column + span.columns <= columnCount else {
        continue
      }

      var overlapsExistingCell = false
      for row in origin.row..<(origin.row + span.rows) {
        for column in origin.column..<(origin.column + span.columns) {
          if occupied[cellIndexInGrid(row: row, column: column, columnCount: columnCount)] {
            overlapsExistingCell = true
            break
          }
        }
        if overlapsExistingCell {
          break
        }
      }

      guard overlapsExistingCell == false else { continue }

      for row in origin.row..<(origin.row + span.rows) {
        for column in origin.column..<(origin.column + span.columns) {
          occupied[cellIndexInGrid(row: row, column: column, columnCount: columnCount)] = true
        }
      }

      cells.append(ResolvedPlacementCell(
        rowIndex: origin.row,
        columnIndex: origin.column,
        rowSpan: span.rows,
        columnSpan: span.columns,
        placementIndex: 0,
        mergeSymbolID: merge.symbolID,
        mergeSymbolSizing: merge.symbolSizing,
      ))
    }

    for rowIndex in 0..<rowCount {
      for columnIndex in 0..<columnCount {
        let index = cellIndexInGrid(row: rowIndex, column: columnIndex, columnCount: columnCount)
        guard occupied[index] == false else { continue }

        occupied[index] = true
        cells.append(ResolvedPlacementCell(
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          rowSpan: 1,
          columnSpan: 1,
          placementIndex: 0,
          mergeSymbolID: nil,
          mergeSymbolSizing: .natural,
        ))
      }
    }

    cells.sort { lhs, rhs in
      if lhs.rowIndex == rhs.rowIndex {
        return lhs.columnIndex < rhs.columnIndex
      }
      return lhs.rowIndex < rhs.rowIndex
    }

    return cells.enumerated().map { offset, cell in
      var updatedCell = cell
      updatedCell.placementIndex = offset
      return updatedCell
    }
  }

  private static func makeColumnMajorRegularAssignmentIndicesByPlacementIndex(
    resolvedPlacementCells: [ResolvedPlacementCell],
    fixedPlacementIndices: Set<Int>,
    rowCount: Int,
    columnCount: Int,
  ) -> [Int: Int] {
    var placementIndexByGridIndex = Array(repeating: -1, count: rowCount * columnCount)
    for cell in resolvedPlacementCells {
      let gridIndex = cellIndexInGrid(row: cell.rowIndex, column: cell.columnIndex, columnCount: columnCount)
      placementIndexByGridIndex[gridIndex] = cell.placementIndex
    }

    var indicesByPlacementIndex: [Int: Int] = [:]
    indicesByPlacementIndex.reserveCapacity(max(0, resolvedPlacementCells.count - fixedPlacementIndices.count))
    var regularAssignmentIndex = 0

    for column in 0..<columnCount {
      for row in 0..<rowCount {
        let gridIndex = cellIndexInGrid(row: row, column: column, columnCount: columnCount)
        let placementIndex = placementIndexByGridIndex[gridIndex]
        guard placementIndex >= 0 else { continue }
        guard fixedPlacementIndices.contains(placementIndex) == false else { continue }

        indicesByPlacementIndex[placementIndex] = regularAssignmentIndex
        regularAssignmentIndex += 1
      }
    }

    return indicesByPlacementIndex
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
    columnSpan: Int = 1,
    rowSpan: Int = 1,
    cellSize: CGSize,
  ) -> CGPoint {
    CGPoint(
      x: (CGFloat(columnIndex) + CGFloat(columnSpan) / 2) * cellSize.width,
      y: (CGFloat(rowIndex) + CGFloat(rowSpan) / 2) * cellSize.height,
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

  private static func mergedCellFitScaleMultiplier(
    polygons: [CollisionPolygon],
    rowSpan: Int,
    columnSpan: Int,
    baseCellSize: CGSize,
  ) -> Double {
    let fallbackMultiplier = sqrt(Double(max(1, rowSpan * columnSpan)))
    let targetSize = CGSize(
      width: CGFloat(columnSpan) * baseCellSize.width,
      height: CGFloat(rowSpan) * baseCellSize.height,
    )

    guard let bounds = bounds(for: polygons), bounds.width > 0, bounds.height > 0 else {
      return fallbackMultiplier
    }

    let horizontalScale = targetSize.width / bounds.width
    let verticalScale = targetSize.height / bounds.height
    let fitScale = min(horizontalScale, verticalScale)
    guard fitScale.isFinite, fitScale > 0 else {
      return fallbackMultiplier
    }

    return Double(fitScale)
  }

  private static func bounds(for polygons: [CollisionPolygon]) -> CGRect? {
    var minimumX = CGFloat.greatestFiniteMagnitude
    var minimumY = CGFloat.greatestFiniteMagnitude
    var maximumX = -CGFloat.greatestFiniteMagnitude
    var maximumY = -CGFloat.greatestFiniteMagnitude
    var hasPoints = false

    for polygon in polygons {
      for point in polygon.points {
        hasPoints = true
        minimumX = min(minimumX, point.x)
        minimumY = min(minimumY, point.y)
        maximumX = max(maximumX, point.x)
        maximumY = max(maximumY, point.y)
      }
    }

    guard hasPoints else { return nil }

    return CGRect(
      x: minimumX,
      y: minimumY,
      width: maximumX - minimumX,
      height: maximumY - minimumY,
    )
  }
}
