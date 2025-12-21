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
  /// - Returns: The placed symbol descriptors for the tile.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor],
    edgeBehavior: TesseraEdgeBehavior,
    configuration: TesseraPlacement.Grid,
  ) -> [PlacedSymbolDescriptor] {
    guard size.width > 0, size.height > 0 else { return [] }

    let symbolCount = symbolDescriptors.count
    let resolvedGrid = resolveGrid(
      for: size,
      configuration: configuration,
      symbolCount: symbolCount,
      edgeBehavior: edgeBehavior,
    )
    let normalizedFraction = normalizedOffsetFraction(from: configuration.offsetStrategy)
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
      )
    }

    let polygonCache: [UUID: [CollisionPolygon]] = symbolDescriptors.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = CollisionMath.polygons(for: symbol.collisionShape)
    }

    var placedDescriptors: [PlacedSymbolDescriptor] = []
    placedDescriptors.reserveCapacity(resolvedGrid.totalCellCount)

    for rowIndex in 0..<resolvedGrid.rowCount {
      for columnIndex in 0..<resolvedGrid.columnCount {
        if Task.isCancelled { return placedDescriptors }

        let resolvedSymbolIndex: Int = switch configuration.symbolOrder {
        case .sequence:
          rowIndex * resolvedGrid.columnCount + columnIndex
        }
        let selectedSymbol = symbolDescriptors[resolvedSymbolIndex % symbolCount]

        let scale = selectedSymbol.resolvedScaleRange.lowerBound
        let rotationRadians = rotationRadiansForGrid(rangeDegrees: selectedSymbol.allowedRotationRangeDegrees)

        guard let selectedPolygons = polygonCache[selectedSymbol.id] else { continue }

        let basePosition = gridCellCenter(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
          cellSize: resolvedGrid.cellSize,
        )
        let offset = gridOffset(
          for: configuration.offsetStrategy,
          normalizedFraction: normalizedFraction,
          columnIndex: columnIndex,
          rowIndex: rowIndex,
          cellSize: resolvedGrid.cellSize,
        )
        var position = CGPoint(x: basePosition.x + offset.width, y: basePosition.y + offset.height)

        switch edgeBehavior {
        case .finite:
          guard (0..<size.width).contains(position.x),
                (0..<size.height).contains(position.y)
          else { continue }

        case .seamlessWrapping:
          position = ShapePlacementWrapping.wrappedPosition(position, in: size)
        }

        let candidate = PlacedSymbolDescriptor(
          symbolId: selectedSymbol.id,
          position: position,
          rotationRadians: rotationRadians,
          scale: CGFloat(scale),
          collisionShape: selectedSymbol.collisionShape,
        )

        if pinnedColliders.isEmpty == false {
          let pinnedIndices = Array(pinnedColliders.indices)
          let isValid = ShapePlacementCollision.isPlacementValid(
            candidate: candidate,
            candidatePolygons: selectedPolygons,
            existingColliderIndices: pinnedIndices,
            allColliders: pinnedColliders,
            tileSize: size,
            edgeBehavior: edgeBehavior,
            wrapOffsets: wrapOffsets,
            minimumSpacing: 0,
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
  ) -> Double {
    rangeDegrees.lowerBound * Double.pi / 180
  }

  private static func resolveGrid(
    for size: CGSize,
    configuration: TesseraPlacement.Grid,
    symbolCount: Int,
    edgeBehavior: TesseraEdgeBehavior,
  ) -> ResolvedGrid {
    let safeCellWidth = max(configuration.cellSize.width, 1)
    let safeCellHeight = max(configuration.cellSize.height, 1)
    let baseColumnCount = max(1, Int((size.width / safeCellWidth).rounded()))
    let baseRowCount = max(1, Int((size.height / safeCellHeight).rounded()))
    let rowNeedsEven = edgeBehavior == .seamlessWrapping && rowShiftRequiresEvenRowCount(
      for: configuration.offsetStrategy,
    )
    let columnNeedsEven = edgeBehavior == .seamlessWrapping && columnShiftRequiresEvenColumnCount(
      for: configuration.offsetStrategy,
    )
    let columnMultiple = columnRequiredMultiple(
      symbolCount: symbolCount,
      symbolOrder: configuration.symbolOrder,
      requiresEven: columnNeedsEven,
    )
    let rowMultiple = rowNeedsEven ? 2 : 1
    let columnCount = adjustedGridCount(
      baseCount: baseColumnCount,
      desiredCellSize: safeCellWidth,
      totalLength: size.width,
      requiredMultiple: columnMultiple,
    )
    let rowCount = adjustedGridCount(
      baseCount: baseRowCount,
      desiredCellSize: safeCellHeight,
      totalLength: size.height,
      requiredMultiple: rowMultiple,
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

  private static func adjustedGridCount(
    baseCount: Int,
    desiredCellSize: CGFloat,
    totalLength: CGFloat,
    requiredMultiple: Int,
  ) -> Int {
    let safeMultiple = max(1, requiredMultiple)
    guard totalLength > 0 else { return max(1, baseCount) }

    let floorMultiple = max(safeMultiple, (baseCount / safeMultiple) * safeMultiple)
    let ceilMultiple = max(
      safeMultiple,
      ((baseCount + safeMultiple - 1) / safeMultiple) * safeMultiple,
    )

    let floorCellSize = totalLength / CGFloat(floorMultiple)
    let ceilCellSize = totalLength / CGFloat(ceilMultiple)
    let floorDelta = abs(floorCellSize - desiredCellSize)
    let ceilDelta = abs(ceilCellSize - desiredCellSize)

    if floorDelta == ceilDelta {
      return max(1, ceilMultiple)
    }
    return floorDelta < ceilDelta ? max(1, floorMultiple) : max(1, ceilMultiple)
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

  private static func columnRequiredMultiple(
    symbolCount: Int,
    symbolOrder: TesseraPlacement.GridSymbolOrder,
    requiresEven: Bool,
  ) -> Int {
    let baseMultiple = switch symbolOrder {
    case .sequence:
      max(1, symbolCount)
    }
    let evenMultiple = requiresEven ? 2 : 1
    return lcm(baseMultiple, evenMultiple)
  }

  private static func lcm(_ lhs: Int, _ rhs: Int) -> Int {
    guard lhs > 0, rhs > 0 else { return max(lhs, rhs) }

    return lhs / gcd(lhs, rhs) * rhs
  }

  private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
    var a = lhs
    var b = rhs
    while b != 0 {
      let remainder = a % b
      a = b
      b = remainder
    }
    return a
  }

  private static func normalizedOffsetFraction(from strategy: TesseraPlacement.GridOffsetStrategy) -> Double {
    let fraction: Double = switch strategy {
    case .none:
      0
    case let .rowShift(value),
         let .columnShift(value),
         let .checkerShift(value):
      value
    }

    let remainder = fraction.truncatingRemainder(dividingBy: 1)
    return remainder >= 0 ? remainder : remainder + 1
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
    normalizedFraction: Double,
    columnIndex: Int,
    rowIndex: Int,
    cellSize: CGSize,
  ) -> CGSize {
    guard normalizedFraction > 0 else { return .zero }

    let offsetX = CGFloat(normalizedFraction) * cellSize.width
    let offsetY = CGFloat(normalizedFraction) * cellSize.height

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
}
