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
    configuration: TesseraPlacement.Grid,
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
    let normalizedOffset = normalizedOffsetAmount(from: configuration.offsetStrategy)
    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: edgeBehavior)
    let shuffledSymbolIndices = configuration.symbolOrder == .shuffle
      ? GridSymbolAssignment.shuffledSymbolIndices(
        symbolCount: symbolCount,
        totalCellCount: resolvedGrid.totalCellCount,
        seed: configuration.seed,
      )
      : nil

    let cumulativeWeights = configuration.symbolOrder == .randomWeightedPerCell
      ? GridSymbolAssignment.cumulativeWeights(for: symbolDescriptors)
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

    let polygonCache: [UUID: [CollisionPolygon]] = symbolDescriptors.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = CollisionMath.polygons(for: symbol.collisionShape)
    }

    var placedDescriptors: [PlacedSymbolDescriptor] = []
    placedDescriptors.reserveCapacity(resolvedGrid.totalCellCount)

    for rowIndex in 0..<resolvedGrid.rowCount {
      for columnIndex in 0..<resolvedGrid.columnCount {
        if Task.isCancelled { return placedDescriptors }

        let cellIndex = rowIndex * resolvedGrid.columnCount + columnIndex

        let resolvedSymbolIndex: Int
        switch configuration.symbolOrder {
        case .sequence:
          resolvedSymbolIndex = cellIndex
        case .diagonal:
          resolvedSymbolIndex = rowIndex + columnIndex
        case .snake:
          let snakeColumn = rowIndex.isMultiple(of: 2) ? columnIndex : (resolvedGrid.columnCount - 1 - columnIndex)
          resolvedSymbolIndex = rowIndex * resolvedGrid.columnCount + snakeColumn
        case .shuffle:
          resolvedSymbolIndex = shuffledSymbolIndices?[cellIndex] ?? cellIndex
        case .randomWeightedPerCell:
          var randomGenerator = SeededGenerator(
            seed: GridSymbolAssignment.symbolSeed(
              baseSeed: configuration.seed,
              rowIndex: rowIndex,
              columnIndex: columnIndex,
              cellIndex: cellIndex,
            ),
          )
          resolvedSymbolIndex = GridSymbolAssignment.randomWeightedSymbolIndex(
            symbolCount: symbolCount,
            cumulativeWeights: cumulativeWeights,
            totalWeight: totalWeight,
            randomGenerator: &randomGenerator,
          )
        }
        let selectedSymbol = symbolDescriptors[resolvedSymbolIndex % symbolCount]

        let baseRotationRadians = rotationRadiansForGrid(
          rangeDegrees: selectedSymbol.allowedRotationRangeDegrees,
          baseSeed: configuration.seed,
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          cellIndex: cellIndex,
        )

        guard let selectedPolygons = polygonCache[selectedSymbol.id] else { continue }

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
        let symbolPhaseOffset = symbolPhaseOffset(
          for: selectedSymbol.id,
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
        let scale = max(0, selectedSymbol.resolvedScaleRange.lowerBound * scaleMultiplier)
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

        let candidate = PlacedSymbolDescriptor(
          symbolId: selectedSymbol.id,
          position: position,
          rotationRadians: rotationRadians,
          scale: CGFloat(scale),
          collisionShape: selectedSymbol.collisionShape,
        )

        if pinnedColliders.isEmpty == false {
          let isValid = ShapePlacementCollision.isPlacementValid(
            candidate: candidate,
            candidatePolygons: selectedPolygons,
            existingColliderIndices: pinnedIndices,
            allColliders: pinnedColliders,
            tileSize: size,
            edgeBehavior: edgeBehavior,
            wrapOffsets: wrapOffsets,
            candidateMinimumSpacing: 0,
          )

          guard isValid else { continue }
        }

        placedDescriptors.append(candidate)
      }
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

  private static func resolveGrid(
    for size: CGSize,
    configuration: TesseraPlacement.Grid,
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
    for strategy: TesseraPlacement.GridOffsetStrategy,
  ) -> Bool {
    switch strategy {
    case .rowShift, .checkerShift:
      true
    case .none, .columnShift:
      false
    }
  }

  private static func columnShiftRequiresEvenColumnCount(
    for strategy: TesseraPlacement.GridOffsetStrategy,
  ) -> Bool {
    switch strategy {
    case .columnShift, .checkerShift:
      true
    case .none, .rowShift:
      false
    }
  }

  private static func normalizedOffsetAmount(from strategy: TesseraPlacement.GridOffsetStrategy) -> Double {
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
    for strategy: TesseraPlacement.GridOffsetStrategy,
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
    symbolPhases: [UUID: TesseraPlacement.Grid.SymbolPhase],
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
