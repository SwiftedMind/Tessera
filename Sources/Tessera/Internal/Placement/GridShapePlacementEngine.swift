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
    edgeBehavior: TesseraEdgeBehavior,
  ) -> ResolvedGrid {
    let baseColumnCount = max(1, configuration.columnCount)
    let baseRowCount = max(1, configuration.rowCount)
    let rowNeedsEven = edgeBehavior == .seamlessWrapping && rowShiftRequiresEvenRowCount(
      for: configuration.offsetStrategy,
    )
    let columnNeedsEven = edgeBehavior == .seamlessWrapping && columnShiftRequiresEvenColumnCount(
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
