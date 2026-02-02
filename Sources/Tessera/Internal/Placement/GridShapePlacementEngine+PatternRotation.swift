// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

extension GridShapePlacementEngine {
  static func placeSymbolDescriptorsForSeamlessPatternRotation(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor],
    configuration: TesseraPlacement.Grid,
    region: TesseraResolvedPolygonRegion?,
    alphaMask: TesseraAlphaMask?,
    patternRotationRadians: Double,
    patternRotationAnchor: CGPoint,
  ) -> [PlacedSymbolDescriptor] {
    let symbolCount = symbolDescriptors.count
    let resolvedGrid = resolveGrid(
      for: size,
      configuration: configuration,
      edgeBehavior: .seamlessWrapping,
    )
    let cellSize = resolvedGrid.cellSize
    let normalizedOffset = normalizedOffsetAmount(from: configuration.offsetStrategy)
    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .seamlessWrapping)

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

        let resolvedSymbolIndex = resolvedSymbolIndexForGridCell(
          baseRow: rowIndex,
          baseColumn: columnIndex,
          baseCellIndex: cellIndex,
          gridColumnCount: resolvedGrid.columnCount,
          symbolCount: symbolCount,
          configuration: configuration,
          shuffledSymbolIndices: shuffledSymbolIndices,
          cumulativeWeights: cumulativeWeights,
          totalWeight: totalWeight,
        )
        let selectedSymbol = symbolDescriptors[resolvedSymbolIndex % symbolCount]

        let scale = selectedSymbol.resolvedScaleRange.lowerBound
        let symbolRotationRadians = rotationRadiansForGrid(
          rangeDegrees: selectedSymbol.allowedRotationRangeDegrees,
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          cellIndex: cellIndex,
        )

        guard let selectedPolygons = polygonCache[selectedSymbol.id] else { continue }

        let basePosition = gridCellCenter(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
          cellSize: cellSize,
        )
        let offset = gridOffset(
          for: configuration.offsetStrategy,
          normalizedOffset: normalizedOffset,
          columnIndex: columnIndex,
          rowIndex: rowIndex,
          cellSize: cellSize,
        )
        var position = CGPoint(x: basePosition.x + offset.width, y: basePosition.y + offset.height)
        position = RotationMath.rotate(
          position,
          around: patternRotationAnchor,
          radians: patternRotationRadians,
        )
        position = ShapePlacementWrapping.wrappedPosition(position, in: size)

        if let region, region.contains(position) == false {
          continue
        }

        if let alphaMask, alphaMask.contains(position) == false {
          continue
        }

        let candidateDescriptor = PlacedSymbolDescriptor(
          symbolId: selectedSymbol.id,
          position: position,
          rotationRadians: symbolRotationRadians,
          scale: CGFloat(scale),
          collisionShape: selectedSymbol.collisionShape,
        )

        if pinnedColliders.isEmpty == false {
          let isValid = ShapePlacementCollision.isPlacementValid(
            candidate: candidateDescriptor,
            candidatePolygons: selectedPolygons,
            existingColliderIndices: pinnedIndices,
            allColliders: pinnedColliders,
            tileSize: size,
            edgeBehavior: .seamlessWrapping,
            wrapOffsets: wrapOffsets,
            minimumSpacing: 0,
          )
          guard isValid else { continue }
        }

        placedDescriptors.append(candidateDescriptor)
      }
    }

    return placedDescriptors
  }
}

private extension GridShapePlacementEngine {
  static func resolvedSymbolIndexForGridCell(
    baseRow: Int,
    baseColumn: Int,
    baseCellIndex: Int,
    gridColumnCount: Int,
    symbolCount: Int,
    configuration: TesseraPlacement.Grid,
    shuffledSymbolIndices: [Int]?,
    cumulativeWeights: [Double],
    totalWeight: Double,
  ) -> Int {
    switch configuration.symbolOrder {
    case .sequence:
      return baseCellIndex
    case .diagonal:
      return baseRow + baseColumn
    case .snake:
      let snakeColumn = baseRow.isMultiple(of: 2) ? baseColumn : (gridColumnCount - 1 - baseColumn)
      return baseRow * gridColumnCount + snakeColumn
    case .shuffle:
      return shuffledSymbolIndices?[baseCellIndex] ?? baseCellIndex
    case .randomWeightedPerCell:
      var randomGenerator = SeededGenerator(
        seed: GridSymbolAssignment.symbolSeed(
          baseSeed: configuration.seed,
          rowIndex: baseRow,
          columnIndex: baseColumn,
          cellIndex: baseCellIndex,
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
}
