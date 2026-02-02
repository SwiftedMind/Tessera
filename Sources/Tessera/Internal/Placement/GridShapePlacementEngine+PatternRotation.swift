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
    let targetCount = resolvedGrid.totalCellCount
    let normalizedOffset = normalizedOffsetAmount(from: configuration.offsetStrategy)
    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: .seamlessWrapping)

    let shuffledSymbolIndices = configuration.symbolOrder == .shuffle
      ? GridSymbolAssignment.shuffledSymbolIndices(
        symbolCount: symbolCount,
        totalCellCount: targetCount,
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

    let inverseBounds = RotationMath.inverseRotatedTileBounds(
      tileSize: size,
      anchor: patternRotationAnchor,
      rotationRadians: patternRotationRadians,
    )

    struct Candidate {
      var descriptor: PlacedSymbolDescriptor
      var baseCellIndex: Int
      var rowCopy: Int
      var columnCopy: Int
      var rowIndex: Int
      var columnIndex: Int
    }

    func sortKey(for candidate: Candidate) -> (Int, Int, Int, Int, Int, Int) {
      (
        candidate.rowCopy + candidate.columnCopy,
        candidate.rowCopy,
        candidate.columnCopy,
        candidate.baseCellIndex,
        candidate.rowIndex,
        candidate.columnIndex,
      )
    }

    let basePadding = patternRotationPadding(
      for: configuration.offsetStrategy,
      normalizedOffset: normalizedOffset,
    )
    let maximumExpandedColumns = max(resolvedGrid.columnCount * 5, 256)
    let maximumExpandedRows = max(resolvedGrid.rowCount * 5, 256)

    var candidates: [Candidate] = []
    candidates.reserveCapacity(targetCount * 3)

    for pass in 1...3 {
      candidates.removeAll(keepingCapacity: true)

      var columnRange = RotationMath.indexRangeCoveringBounds(
        min: inverseBounds.minX,
        max: inverseBounds.maxX,
        cellSize: cellSize.width,
      )
      var rowRange = RotationMath.indexRangeCoveringBounds(
        min: inverseBounds.minY,
        max: inverseBounds.maxY,
        cellSize: cellSize.height,
      )

      let scaledColumns = basePadding.columns * pass
      let scaledRows = basePadding.rows * pass
      columnRange = (columnRange.lowerBound - scaledColumns)...(columnRange.upperBound + scaledColumns)
      rowRange = (rowRange.lowerBound - scaledRows)...(rowRange.upperBound + scaledRows)

      columnRange = RotationMath.clampedIndexRange(columnRange, maximumCount: maximumExpandedColumns)
      rowRange = RotationMath.clampedIndexRange(rowRange, maximumCount: maximumExpandedRows)

      for rowIndex in rowRange {
        for columnIndex in columnRange {
          if Task.isCancelled { return candidates.map(\.descriptor) }

          let baseRow = ShapePlacementWrapping.wrappedIndex(rowIndex, modulus: resolvedGrid.rowCount)
          let baseColumn = ShapePlacementWrapping.wrappedIndex(columnIndex, modulus: resolvedGrid.columnCount)
          let baseCellIndex = baseRow * resolvedGrid.columnCount + baseColumn

          let resolvedSymbolIndex = resolvedSymbolIndexForGridCell(
            baseRow: baseRow,
            baseColumn: baseColumn,
            baseCellIndex: baseCellIndex,
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
            rowIndex: baseRow,
            columnIndex: baseColumn,
            cellIndex: baseCellIndex,
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

          guard (0..<size.width).contains(position.x),
                (0..<size.height).contains(position.y)
          else { continue }

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

          let rowCopy = abs(rowIndex - baseRow) / max(1, resolvedGrid.rowCount)
          let columnCopy = abs(columnIndex - baseColumn) / max(1, resolvedGrid.columnCount)
          let candidate = Candidate(
            descriptor: candidateDescriptor,
            baseCellIndex: baseCellIndex,
            rowCopy: rowCopy,
            columnCopy: columnCopy,
            rowIndex: rowIndex,
            columnIndex: columnIndex,
          )

          candidates.append(candidate)
        }
      }

      if candidates.count >= targetCount {
        break
      }
    }

    candidates.sort { sortKey(for: $0) < sortKey(for: $1) }

    var placedDescriptors: [PlacedSymbolDescriptor] = []
    placedDescriptors.reserveCapacity(min(targetCount, candidates.count))

    var usedBaseCellIndices: Set<Int> = []
    usedBaseCellIndices.reserveCapacity(min(targetCount, candidates.count))

    for candidate in candidates {
      if usedBaseCellIndices.insert(candidate.baseCellIndex).inserted {
        placedDescriptors.append(candidate.descriptor)
        if placedDescriptors.count == targetCount { return placedDescriptors }
      }
    }

    for candidate in candidates {
      if placedDescriptors.count == targetCount { break }
      placedDescriptors.append(candidate.descriptor)
    }

    if placedDescriptors.count > targetCount {
      placedDescriptors.removeLast(placedDescriptors.count - targetCount)
    }

    return placedDescriptors
  }
}

private extension GridShapePlacementEngine {
  struct PatternRotationPadding: Sendable {
    var columns: Int
    var rows: Int
  }

  static func patternRotationPadding(
    for strategy: TesseraPlacement.GridOffsetStrategy,
    normalizedOffset: Double,
  ) -> PatternRotationPadding {
    let base = max(2, Int(ceil(normalizedOffset)) + 2)

    return switch strategy {
    case .none:
      PatternRotationPadding(columns: 2, rows: 2)
    case .rowShift:
      PatternRotationPadding(columns: base, rows: 2)
    case .columnShift:
      PatternRotationPadding(columns: 2, rows: base)
    case .checkerShift:
      PatternRotationPadding(columns: base, rows: base)
    }
  }

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
