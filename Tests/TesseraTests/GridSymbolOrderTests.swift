// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func rowMajorMatchesPriorSequenceBehavior() async throws {
  let size = CGSize(width: 200, height: 200)

  let ids = [UUID(), UUID(), UUID()]
  let symbols = ids.map { makeSymbolDescriptor(id: $0) }

  let configuration = PlacementModel.Grid(
    sizing: .count(columns: 2, rows: 2),
    offsetStrategy: .none,
    symbolOrder: .rowMajor,
    seed: 1,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(placed.map(\.symbolId) == [ids[0], ids[1], ids[2], ids[0]])
}

@Test func columnMajorAssignsTopToBottomThenNextColumn() async throws {
  let size = CGSize(width: 300, height: 200)

  let ids = [UUID(), UUID(), UUID()]
  let symbols = ids.map { makeSymbolDescriptor(id: $0) }

  let configuration = PlacementModel.Grid(
    sizing: .count(columns: 3, rows: 2),
    offsetStrategy: .none,
    symbolOrder: .columnMajor,
    seed: 1,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(symbolID(at: CGPoint(x: 50, y: 50), in: placed) == ids[0])
  #expect(symbolID(at: CGPoint(x: 50, y: 150), in: placed) == ids[1])
  #expect(symbolID(at: CGPoint(x: 150, y: 50), in: placed) == ids[2])
  #expect(symbolID(at: CGPoint(x: 150, y: 150), in: placed) == ids[0])
  #expect(symbolID(at: CGPoint(x: 250, y: 50), in: placed) == ids[1])
  #expect(symbolID(at: CGPoint(x: 250, y: 150), in: placed) == ids[2])
}

@Test func diagonalAssignsByRowPlusColumn() async throws {
  let size = CGSize(width: 300, height: 300)

  let ids = [UUID(), UUID(), UUID()]
  let symbols = ids.map { makeSymbolDescriptor(id: $0) }

  let configuration = PlacementModel.Grid(
    sizing: .count(columns: 3, rows: 3),
    offsetStrategy: .none,
    symbolOrder: .diagonal,
    seed: 1,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  let expected = expectedIndices(columnCount: 3, rowCount: 3) { row, column, _ in
    (row + column) % symbols.count
  }
  #expect(placed.map(\.symbolId) == expected.map { ids[$0] })
}

@Test func snakeReversesOddRows() async throws {
  let size = CGSize(width: 400, height: 200)

  let ids = [UUID(), UUID(), UUID(), UUID()]
  let symbols = ids.map { makeSymbolDescriptor(id: $0) }

  let configuration = PlacementModel.Grid(
    sizing: .count(columns: 4, rows: 2),
    offsetStrategy: .none,
    symbolOrder: .snake,
    seed: 1,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(placed.map(\.symbolId) == [ids[0], ids[1], ids[2], ids[3], ids[3], ids[2], ids[1], ids[0]])
}

@Test func shuffleIsDeterministicAndBalanced() async throws {
  let size = CGSize(width: 400, height: 200)

  let ids = [UUID(), UUID(), UUID()]
  let symbols = ids.map { makeSymbolDescriptor(id: $0) }

  let configuration = PlacementModel.Grid(
    sizing: .count(columns: 4, rows: 2),
    offsetStrategy: .none,
    symbolOrder: .shuffle,
    seed: 123,
  )

  let first = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )
  let second = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(first.map(\.symbolId) == second.map(\.symbolId))

  let expectedIndices = expectedShuffleIndices(
    symbolCount: symbols.count,
    totalCellCount: 8,
    seed: configuration.seed,
  )
  #expect(first.map(\.symbolId) == expectedIndices.map { ids[$0] })

  let counts = first.reduce(into: [UUID: Int]()) { counts, placed in
    counts[placed.symbolId, default: 0] += 1
  }
  let values = counts.values.sorted()
  #expect(values.last! - values.first! <= 1)
}

@Test func randomWeightedPerCellRespectsWeightsAndIsDeterministic() async throws {
  let size = CGSize(width: 300, height: 300)

  let ids = [UUID(), UUID(), UUID()]
  let symbols = [
    makeSymbolDescriptor(id: ids[0], weight: 0),
    makeSymbolDescriptor(id: ids[1], weight: 0),
    makeSymbolDescriptor(id: ids[2], weight: 10),
  ]

  let configuration = PlacementModel.Grid(
    sizing: .count(columns: 3, rows: 3),
    offsetStrategy: .none,
    symbolOrder: .randomWeightedPerCell,
    seed: 999,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(Set(placed.map(\.symbolId)) == [ids[2]])

  let deterministicSymbols = [
    makeSymbolDescriptor(id: ids[0], weight: 1),
    makeSymbolDescriptor(id: ids[1], weight: 2),
  ]
  let deterministicConfiguration = PlacementModel.Grid(
    sizing: .count(columns: 3, rows: 3),
    offsetStrategy: .none,
    symbolOrder: .randomWeightedPerCell,
    seed: 42,
  )
  let deterministicPlaced = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: deterministicSymbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: deterministicConfiguration,
  )

  let expected = expectedIndices(columnCount: 3, rowCount: 3) { row, column, cellIndex in
    expectedRandomWeightedIndex(
      symbolWeights: deterministicSymbols.map(\.weight),
      baseSeed: deterministicConfiguration.seed,
      rowIndex: row,
      columnIndex: column,
      cellIndex: cellIndex,
    )
  }
  #expect(deterministicPlaced.map(\.symbolId) == expected.map { ids[$0] })
}

private func makeSymbolDescriptor(
  id: UUID,
  weight: Double = 1,
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: weight,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
}

private func symbolID(
  at position: CGPoint,
  in placedDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor],
) -> UUID? {
  placedDescriptors.first(where: { $0.position == position })?.symbolId
}

private func expectedIndices(
  columnCount: Int,
  rowCount: Int,
  indexForCell: (_ rowIndex: Int, _ columnIndex: Int, _ cellIndex: Int) -> Int,
) -> [Int] {
  var indices: [Int] = []
  indices.reserveCapacity(columnCount * rowCount)

  for row in 0..<rowCount {
    for column in 0..<columnCount {
      let cellIndex = row * columnCount + column
      indices.append(indexForCell(row, column, cellIndex))
    }
  }

  return indices
}

private func expectedShuffleIndices(
  symbolCount: Int,
  totalCellCount: Int,
  seed: UInt64,
) -> [Int] {
  var indices = Array(repeating: 0, count: totalCellCount)
  for index in 0..<totalCellCount {
    indices[index] = index % symbolCount
  }

  var randomGenerator = SeededGenerator(seed: seed)
  indices.shuffle(using: &randomGenerator)
  return indices
}

private func expectedRandomWeightedIndex(
  symbolWeights: [Double],
  baseSeed: UInt64,
  rowIndex: Int,
  columnIndex: Int,
  cellIndex: Int,
) -> Int {
  var cumulativeWeights: [Double] = []
  cumulativeWeights.reserveCapacity(symbolWeights.count)

  var runningTotal = 0.0
  for weight in symbolWeights {
    let normalizedWeight = weight.isFinite ? max(0, weight) : 0
    runningTotal += normalizedWeight
    cumulativeWeights.append(runningTotal)
  }

  let totalWeight = cumulativeWeights.last ?? 0
  var randomGenerator = SeededGenerator(
    seed: expectedGridSymbolSeed(
      baseSeed: baseSeed,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      cellIndex: cellIndex,
    ),
  )

  guard totalWeight > 0 else {
    return Int.random(in: 0..<symbolWeights.count, using: &randomGenerator)
  }

  let value = Double.random(in: 0..<totalWeight, using: &randomGenerator)
  var lowerBound = 0
  var upperBound = cumulativeWeights.count - 1
  while lowerBound < upperBound {
    let mid = (lowerBound + upperBound) / 2
    if value < cumulativeWeights[mid] {
      upperBound = mid
    } else {
      lowerBound = mid + 1
    }
  }

  return lowerBound
}

private func expectedGridSymbolSeed(
  baseSeed: UInt64,
  rowIndex: Int,
  columnIndex: Int,
  cellIndex: Int,
) -> UInt64 {
  var seed = baseSeed
  seed ^= UInt64(truncatingIfNeeded: rowIndex) &* 0x9E37_79B9_7F4A_7C15
  seed ^= UInt64(truncatingIfNeeded: columnIndex) &* 0xBF58_476D_1CE4_E5B9
  seed ^= UInt64(truncatingIfNeeded: cellIndex) &* 0x94D0_49BB_1331_11EB
  seed ^= seed >> 29
  return seed
}
