// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func gridPlacementReturnsEmptyWhenNoSymbolsAreProvided() async throws {
  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: CGSize(width: 200, height: 120),
    symbolDescriptors: [],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: PlacementModel.Grid(
      columnCount: 4,
      rowCount: 3,
      offsetStrategy: .none,
      symbolOrder: .rowMajor,
      seed: 9,
    ),
  )

  #expect(placed.isEmpty)
}

@Test func gridRotationVariesAcrossDifferentSeeds() async throws {
  let size = CGSize(width: 320, height: 200)
  let symbol = makeGridSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
    allowedRotationRangeDegrees: 5...175,
  )

  let first = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: PlacementModel.Grid(
      columnCount: 6,
      rowCount: 4,
      offsetStrategy: .none,
      symbolOrder: .rowMajor,
      seed: 1,
    ),
  )
  let second = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: PlacementModel.Grid(
      columnCount: 6,
      rowCount: 4,
      offsetStrategy: .none,
      symbolOrder: .rowMajor,
      seed: 2,
    ),
  )

  #expect(first.count == second.count)
  #expect(first.map(\.rotationRadians) != second.map(\.rotationRadians))
}

@Test func gridWeightedChoiceIsDeterministicForSameSeedAndVariesAcrossSeeds() async throws {
  let size = CGSize(width: 320, height: 240)
  let choiceSymbolID = UUID(uuidString: "00000000-0000-0000-0000-000000000030")!
  let firstVariantID = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
  let secondVariantID = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!
  let choiceSymbol = makeChoiceSymbolDescriptor(
    id: choiceSymbolID,
    strategy: .weightedRandom,
    choices: [
      makeGridSymbolDescriptor(
        id: firstVariantID,
        allowedRotationRangeDegrees: 0...0,
      ),
      makeGridSymbolDescriptor(
        id: secondVariantID,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
  )

  let first = placeGrid(
    size: size,
    symbolDescriptors: [choiceSymbol],
    seed: 7,
    columnCount: 6,
    rowCount: 5,
  )
  let second = placeGrid(
    size: size,
    symbolDescriptors: [choiceSymbol],
    seed: 7,
    columnCount: 6,
    rowCount: 5,
  )
  let third = placeGrid(
    size: size,
    symbolDescriptors: [choiceSymbol],
    seed: 8,
    columnCount: 6,
    rowCount: 5,
  )

  #expect(first.map(\.renderSymbolId) == second.map(\.renderSymbolId))
  #expect(first.map(\.renderSymbolId) != third.map(\.renderSymbolId))
  #expect(first.allSatisfy { $0.symbolId == choiceSymbolID })
}

@Test func gridChoiceSeedChangesChoiceResolutionForSamePlacementSeed() async throws {
  let size = CGSize(width: 320, height: 240)
  let firstVariantID = UUID(uuidString: "00000000-0000-0000-0000-000000000033")!
  let secondVariantID = UUID(uuidString: "00000000-0000-0000-0000-000000000034")!
  let choiceWithSeedA = makeChoiceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000035")!,
    strategy: .weightedRandom,
    choiceSeed: 11,
    choices: [
      makeGridSymbolDescriptor(
        id: firstVariantID,
        allowedRotationRangeDegrees: 0...0,
      ),
      makeGridSymbolDescriptor(
        id: secondVariantID,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
  )
  let choiceWithSeedB = makeChoiceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000036")!,
    strategy: .weightedRandom,
    choiceSeed: 29,
    choices: [
      makeGridSymbolDescriptor(
        id: firstVariantID,
        allowedRotationRangeDegrees: 0...0,
      ),
      makeGridSymbolDescriptor(
        id: secondVariantID,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
  )

  let withSeedAFirst = placeGrid(
    size: size,
    symbolDescriptors: [choiceWithSeedA],
    seed: 41,
    columnCount: 6,
    rowCount: 5,
  )
  let withSeedASecond = placeGrid(
    size: size,
    symbolDescriptors: [choiceWithSeedA],
    seed: 41,
    columnCount: 6,
    rowCount: 5,
  )
  let withSeedB = placeGrid(
    size: size,
    symbolDescriptors: [choiceWithSeedB],
    seed: 41,
    columnCount: 6,
    rowCount: 5,
  )

  #expect(withSeedAFirst.map(\.renderSymbolId) == withSeedASecond.map(\.renderSymbolId))
  #expect(withSeedAFirst.map(\.renderSymbolId) != withSeedB.map(\.renderSymbolId))
}

@Test func gridSequenceChoiceCyclesAcrossCellsAndSupportsNestedChoices() async throws {
  let size = CGSize(width: 240, height: 120)
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000040")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
  let nestedID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
  let nestedFirstID = UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
  let nestedSecondID = UUID(uuidString: "00000000-0000-0000-0000-000000000044")!

  let nestedChoice = makeChoiceSymbolDescriptor(
    id: nestedID,
    strategy: .sequence,
    choices: [
      makeGridSymbolDescriptor(
        id: nestedFirstID,
        allowedRotationRangeDegrees: 0...0,
      ),
      makeGridSymbolDescriptor(
        id: nestedSecondID,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
  )
  let rootChoice = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .sequence,
    choices: [
      makeGridSymbolDescriptor(
        id: firstID,
        allowedRotationRangeDegrees: 0...0,
      ),
      nestedChoice,
    ],
  )

  let placed = placeGrid(
    size: size,
    symbolDescriptors: [rootChoice],
    seed: 13,
    columnCount: 4,
    rowCount: 1,
  )

  #expect(placed.count == 4)
  #expect(placed.map(\.renderSymbolId) == [firstID, nestedFirstID, firstID, nestedSecondID])
}

@Test func gridIndexSequenceChoiceCyclesAcrossCellsAndRepeatsProvidedIndices() async throws {
  let size = CGSize(width: 300, height: 100)
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000045")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000046")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000047")!
  let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000048")!
  let rootChoice = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .indexSequence([2, 0, 1]),
    choices: [
      makeGridSymbolDescriptor(id: firstID, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: secondID, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: thirdID, allowedRotationRangeDegrees: 0...0),
    ],
  )

  let placed = placeGrid(
    size: size,
    symbolDescriptors: [rootChoice],
    seed: 14,
    columnCount: 5,
    rowCount: 1,
  )

  #expect(placed.map(\.renderSymbolId) == [thirdID, firstID, secondID, thirdID, firstID])
}

@Test func gridIndexSequenceChoiceNormalizesOutOfRangeAndNegativeIndices() async throws {
  let size = CGSize(width: 180, height: 100)
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000049")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-00000000004A")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-00000000004B")!
  let thirdID = UUID(uuidString: "00000000-0000-0000-0000-00000000004C")!
  let rootChoice = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .indexSequence([5, -1, 1]),
    choices: [
      makeGridSymbolDescriptor(id: firstID, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: secondID, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: thirdID, allowedRotationRangeDegrees: 0...0),
    ],
  )

  let placed = placeGrid(
    size: size,
    symbolDescriptors: [rootChoice],
    seed: 15,
    columnCount: 3,
    rowCount: 1,
  )

  #expect(placed.map(\.renderSymbolId) == [thirdID, thirdID, secondID])
}

@Test func gridSequenceChoiceDoesNotAdvanceWhenCellIsRejected() async throws {
  let size = CGSize(width: 200, height: 100)
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000050")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000052")!
  let rootChoice = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .sequence,
    choices: [
      makeGridSymbolDescriptor(
        id: firstID,
        allowedRotationRangeDegrees: 0...0,
      ),
      makeGridSymbolDescriptor(
        id: secondID,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
  )
  let pinnedSymbol = ShapePlacementEngine.PinnedSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000053")!,
    position: CGPoint(x: 50, y: 50),
    rotationRadians: 0,
    scale: 1,
    collisionShape: .circle(center: .zero, radius: 30),
  )

  let placed = placeGrid(
    size: size,
    symbolDescriptors: [rootChoice],
    seed: 17,
    columnCount: 2,
    rowCount: 1,
    pinnedSymbolDescriptors: [pinnedSymbol],
  )

  #expect(placed.count == 1)
  #expect(placed[0].symbolId == rootID)
  #expect(placed[0].renderSymbolId == firstID)
}

@Test func gridIndexSequenceChoiceDoesNotAdvanceWhenCellIsRejected() async throws {
  let size = CGSize(width: 200, height: 100)
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000054")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000055")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000056")!
  let rootChoice = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .indexSequence([1, 0]),
    choices: [
      makeGridSymbolDescriptor(id: firstID, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: secondID, allowedRotationRangeDegrees: 0...0),
    ],
  )
  let pinnedSymbol = ShapePlacementEngine.PinnedSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000057")!,
    position: CGPoint(x: 50, y: 50),
    rotationRadians: 0,
    scale: 1,
    collisionShape: .circle(center: .zero, radius: 30),
  )

  let placed = placeGrid(
    size: size,
    symbolDescriptors: [rootChoice],
    seed: 17,
    columnCount: 2,
    rowCount: 1,
    pinnedSymbolDescriptors: [pinnedSymbol],
  )

  #expect(placed.count == 1)
  #expect(placed[0].symbolId == rootID)
  #expect(placed[0].renderSymbolId == secondID)
}

@Test func gridIndexSequenceChoiceFallsBackToSequenceWhenIndicesAreEmpty() async throws {
  let size = CGSize(width: 240, height: 100)
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000058")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000059")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-00000000005A")!
  let rootChoice = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .indexSequence([]),
    choices: [
      makeGridSymbolDescriptor(id: firstID, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: secondID, allowedRotationRangeDegrees: 0...0),
    ],
  )

  let placed = placeGrid(
    size: size,
    symbolDescriptors: [rootChoice],
    seed: 18,
    columnCount: 4,
    rowCount: 1,
  )

  #expect(placed.map(\.renderSymbolId) == [firstID, secondID, firstID, secondID])
}

@Test func gridSymbolPhasesUseResolvedChoiceLeafID() async throws {
  let size = CGSize(width: 200, height: 100)
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000060")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000061")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000062")!
  let rootChoice = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .sequence,
    choices: [
      makeGridSymbolDescriptor(
        id: firstID,
        allowedRotationRangeDegrees: 0...0,
      ),
      makeGridSymbolDescriptor(
        id: secondID,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
  )
  let symbolPhases: [UUID: PlacementModel.Grid.SymbolPhase] = [
    secondID: .init(x: -0.25, y: 0),
  ]

  let placed = placeGrid(
    size: size,
    symbolDescriptors: [rootChoice],
    seed: 23,
    columnCount: 2,
    rowCount: 1,
    symbolPhases: symbolPhases,
  )

  #expect(placed.map(\.renderSymbolId) == [firstID, secondID])
  #expect(abs(placed[0].position.x - 50) < 0.0001)
  #expect(abs(placed[1].position.x - 125) < 0.0001)
}

@Test func gridPlacementSupportsSubgridsWithDedicatedSymbols() async throws {
  let regular = UUID(uuidString: "00000000-0000-0000-0000-000000000071")!
  let subgridSymbol = UUID(uuidString: "00000000-0000-0000-0000-000000000072")!
  let placed = placeGrid(
    size: CGSize(width: 400, height: 400),
    symbolDescriptors: [
      makeGridSymbolDescriptor(id: regular, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: subgridSymbol, allowedRotationRangeDegrees: 0...0),
    ],
    seed: 11,
    columnCount: 4,
    rowCount: 4,
    subgrids: [
      .init(
        origin: .init(row: 1, column: 1),
        span: .init(rows: 2, columns: 2),
        symbolIDs: [subgridSymbol],
      ),
    ],
  )

  #expect(placed.count == 16)
  #expect(placed.contains { $0.symbolId == subgridSymbol && $0.position == CGPoint(x: 150, y: 150) })
  #expect(placed.contains { $0.symbolId == subgridSymbol && $0.position == CGPoint(x: 250, y: 150) })
  #expect(placed.contains { $0.symbolId == subgridSymbol && $0.position == CGPoint(x: 150, y: 250) })
  #expect(placed.contains { $0.symbolId == subgridSymbol && $0.position == CGPoint(x: 250, y: 250) })
  #expect(placed.contains { $0.symbolId == subgridSymbol && $0.position == CGPoint(x: 50, y: 50) } == false)
}

@Test func gridPlacementSkipsOverlappingSubgridsAfterFirstValidSubgrid() async throws {
  let firstSubgridSymbol = UUID(uuidString: "00000000-0000-0000-0000-000000000073")!
  let secondSubgridSymbol = UUID(uuidString: "00000000-0000-0000-0000-000000000074")!
  let regular = UUID(uuidString: "00000000-0000-0000-0000-000000000075")!
  let placed = placeGrid(
    size: CGSize(width: 300, height: 300),
    symbolDescriptors: [
      makeGridSymbolDescriptor(id: regular, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: firstSubgridSymbol, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: secondSubgridSymbol, allowedRotationRangeDegrees: 0...0),
    ],
    seed: 12,
    columnCount: 3,
    rowCount: 3,
    subgrids: [
      .init(origin: .init(row: 0, column: 0), span: .init(rows: 2, columns: 2), symbolIDs: [firstSubgridSymbol]),
      .init(origin: .init(row: 1, column: 1), span: .init(rows: 2, columns: 2), symbolIDs: [secondSubgridSymbol]),
    ],
  )

  #expect(placed.count == 9)
  #expect(placed.contains { $0.symbolId == firstSubgridSymbol && $0.position == CGPoint(x: 50, y: 50) })
  #expect(placed.contains { $0.symbolId == secondSubgridSymbol } == false)
}

@Test func gridPlacementSkipsInvalidSubgrids() async throws {
  let regular = UUID(uuidString: "00000000-0000-0000-0000-000000000076")!
  let subgridSymbol = UUID(uuidString: "00000000-0000-0000-0000-000000000077")!
  let placed = placeGrid(
    size: CGSize(width: 300, height: 300),
    symbolDescriptors: [
      makeGridSymbolDescriptor(id: regular, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: subgridSymbol, allowedRotationRangeDegrees: 0...0),
    ],
    seed: 13,
    columnCount: 3,
    rowCount: 3,
    subgrids: [
      .init(origin: .init(row: -1, column: 0), span: .init(rows: 1, columns: 1), symbolIDs: [subgridSymbol]),
      .init(origin: .init(row: 2, column: 2), span: .init(rows: 2, columns: 2), symbolIDs: [subgridSymbol]),
      .init(origin: .init(row: 0, column: 0), span: .init(rows: 1, columns: 1), symbolIDs: []),
    ],
  )

  #expect(placed.count == 9)
  #expect(placed.contains { $0.symbolId == subgridSymbol } == false)
}

@Test func acceptedSubgridAreasIgnoreUnknownSymbolsWhenKnownIDsProvided() async throws {
  let unknown = UUID(uuidString: "00000000-0000-0000-0000-00000000007A")!
  let known = UUID(uuidString: "00000000-0000-0000-0000-00000000007B")!
  let configuration = PlacementModel.Grid(
    columnCount: 3,
    rowCount: 3,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 2, columns: 2),
        symbolIDs: [unknown],
      ),
      .init(
        origin: .init(row: 1, column: 1),
        span: .init(rows: 2, columns: 2),
        symbolIDs: [known],
      ),
    ],
  )
  let resolvedGrid = GridShapePlacementEngine.resolveGrid(
    for: CGSize(width: 300, height: 300),
    configuration: configuration,
    edgeBehavior: .finite,
  )

  let accepted = GridShapePlacementEngine.resolveAcceptedSubgridAreas(
    subgrids: configuration.subgrids,
    grid: resolvedGrid,
    knownSymbolIDs: Set([known]),
  )

  #expect(accepted.count == 1)
  #expect(accepted[0].rowIndex == 1)
  #expect(accepted[0].columnIndex == 1)
  #expect(accepted[0].rowCount == 2)
  #expect(accepted[0].columnCount == 2)
}

@Test func gridPlacementLeavesRegularCellsEmptyWhenOnlySubgridSymbolsAreAvailable() async throws {
  let subgridSymbol = UUID(uuidString: "00000000-0000-0000-0000-00000000007C")!
  let placed = placeGrid(
    size: CGSize(width: 200, height: 200),
    symbolDescriptors: [
      makeGridSymbolDescriptor(id: subgridSymbol, allowedRotationRangeDegrees: 0...0),
    ],
    seed: 33,
    columnCount: 2,
    rowCount: 2,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 1, columns: 1),
        symbolIDs: [subgridSymbol],
      ),
    ],
  )

  #expect(placed.count == 1)
  #expect(placed[0].symbolId == subgridSymbol)
  #expect(placed[0].position == CGPoint(x: 50, y: 50))
}

@Test func gridRowMajorOrderUsesContiguousRegularIndicesWithSubgrids() async throws {
  let regularA = UUID(uuidString: "00000000-0000-0000-0000-000000000078")!
  let regularB = UUID(uuidString: "00000000-0000-0000-0000-000000000079")!
  let subgridSymbol = UUID(uuidString: "00000000-0000-0000-0000-000000000080")!
  let placed = placeGrid(
    size: CGSize(width: 400, height: 100),
    symbolDescriptors: [
      makeGridSymbolDescriptor(id: regularA, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: regularB, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: subgridSymbol, allowedRotationRangeDegrees: 0...0),
    ],
    seed: 14,
    columnCount: 4,
    rowCount: 1,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 1),
        span: .init(rows: 1, columns: 2),
        symbolIDs: [subgridSymbol],
      ),
    ],
  )

  #expect(placed.map(\.symbolId) == [regularA, subgridSymbol, subgridSymbol, regularB])
}

@Test func gridColumnMajorOrderUsesContiguousRegularIndicesWithSubgrids() async throws {
  let regularA = UUID(uuidString: "00000000-0000-0000-0000-000000000081")!
  let regularB = UUID(uuidString: "00000000-0000-0000-0000-000000000082")!
  let subgridSymbol = UUID(uuidString: "00000000-0000-0000-0000-000000000083")!
  let placed = placeGrid(
    size: CGSize(width: 300, height: 200),
    symbolDescriptors: [
      makeGridSymbolDescriptor(id: regularA, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: regularB, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: subgridSymbol, allowedRotationRangeDegrees: 0...0),
    ],
    seed: 15,
    columnCount: 3,
    rowCount: 2,
    symbolOrder: .columnMajor,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 1),
        span: .init(rows: 1, columns: 2),
        symbolIDs: [subgridSymbol],
      ),
    ],
  )

  #expect(placed.map(\.symbolId) == [regularA, subgridSymbol, subgridSymbol, regularB, regularA, regularB])
}

@Test func subgridOrderIsLocalToSubgridBounds() async throws {
  let symbolA = UUID(uuidString: "00000000-0000-0000-0000-000000000084")!
  let symbolB = UUID(uuidString: "00000000-0000-0000-0000-000000000085")!
  let symbolC = UUID(uuidString: "00000000-0000-0000-0000-000000000086")!
  let placed = placeGrid(
    size: CGSize(width: 200, height: 200),
    symbolDescriptors: [
      makeGridSymbolDescriptor(id: symbolA, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: symbolB, allowedRotationRangeDegrees: 0...0),
      makeGridSymbolDescriptor(id: symbolC, allowedRotationRangeDegrees: 0...0),
    ],
    seed: 88,
    columnCount: 2,
    rowCount: 2,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 2, columns: 2),
        symbolIDs: [symbolA, symbolB, symbolC],
        symbolOrder: .columnMajor,
      ),
    ],
  )

  #expect(placed.map(\.symbolId) == [symbolA, symbolC, symbolB, symbolA])
}

@Test func subgridShuffleAndRandomWeightedAreDeterministic() async throws {
  let symbolA = ShapePlacementEngine.PlacementSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000087")!,
    weight: 1,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
  let symbolB = ShapePlacementEngine.PlacementSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000088")!,
    weight: 1.5,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
  let symbolC = ShapePlacementEngine.PlacementSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000089")!,
    weight: 2.2,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
  let symbols = [symbolA, symbolB, symbolC]

  let shuffledFirst = placeGrid(
    size: CGSize(width: 400, height: 200),
    symbolDescriptors: symbols,
    seed: 60,
    columnCount: 4,
    rowCount: 2,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 2, columns: 4),
        symbolIDs: symbols.map(\.id),
        symbolOrder: .shuffle,
        seed: 902,
      ),
    ],
  )
  let shuffledSecond = placeGrid(
    size: CGSize(width: 400, height: 200),
    symbolDescriptors: symbols,
    seed: 60,
    columnCount: 4,
    rowCount: 2,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 2, columns: 4),
        symbolIDs: symbols.map(\.id),
        symbolOrder: .shuffle,
        seed: 902,
      ),
    ],
  )
  let shuffledThird = placeGrid(
    size: CGSize(width: 400, height: 200),
    symbolDescriptors: symbols,
    seed: 60,
    columnCount: 4,
    rowCount: 2,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 2, columns: 4),
        symbolIDs: symbols.map(\.id),
        symbolOrder: .shuffle,
        seed: 999,
      ),
    ],
  )
  #expect(shuffledFirst.map(\.symbolId) == shuffledSecond.map(\.symbolId))
  #expect(shuffledFirst.map(\.symbolId) != shuffledThird.map(\.symbolId))

  let weightedFirst = placeGrid(
    size: CGSize(width: 300, height: 300),
    symbolDescriptors: symbols,
    seed: 99,
    columnCount: 3,
    rowCount: 3,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 3, columns: 3),
        symbolIDs: symbols.map(\.id),
        symbolOrder: .randomWeightedPerCell,
        seed: 1234,
      ),
    ],
  )
  let weightedSecond = placeGrid(
    size: CGSize(width: 300, height: 300),
    symbolDescriptors: symbols,
    seed: 99,
    columnCount: 3,
    rowCount: 3,
    subgrids: [
      .init(
        origin: .init(row: 0, column: 0),
        span: .init(rows: 3, columns: 3),
        symbolIDs: symbols.map(\.id),
        symbolOrder: .randomWeightedPerCell,
        seed: 1234,
      ),
    ],
  )
  #expect(weightedFirst.map(\.symbolId) == weightedSecond.map(\.symbolId))
}

@Test func subgridDerivedSeedDependsOnAcceptedSubgridIndex() async throws {
  let symbolA = UUID(uuidString: "00000000-0000-0000-0000-00000000008A")!
  let symbolB = UUID(uuidString: "00000000-0000-0000-0000-00000000008B")!
  let symbolC = UUID(uuidString: "00000000-0000-0000-0000-00000000008C")!
  let symbolD = UUID(uuidString: "00000000-0000-0000-0000-00000000008D")!
  let primerSymbol = UUID(uuidString: "00000000-0000-0000-0000-00000000008E")!
  let symbols = [symbolA, symbolB, symbolC, symbolD, primerSymbol].map { symbolID in
    makeGridSymbolDescriptor(id: symbolID, allowedRotationRangeDegrees: 0...0)
  }

  let baseSubgrid = PlacementModel.Grid.Subgrid(
    origin: .init(row: 0, column: 0),
    span: .init(rows: 3, columns: 4),
    symbolIDs: [symbolA, symbolB, symbolC, symbolD],
    symbolOrder: .shuffle,
    seed: nil,
  )
  let first = placeGrid(
    size: CGSize(width: 400, height: 400),
    symbolDescriptors: symbols,
    seed: 444,
    columnCount: 4,
    rowCount: 4,
    subgrids: [baseSubgrid],
  )
  let second = placeGrid(
    size: CGSize(width: 400, height: 400),
    symbolDescriptors: symbols,
    seed: 444,
    columnCount: 4,
    rowCount: 4,
    subgrids: [baseSubgrid],
  )
  #expect(first.map(\.symbolId) == second.map(\.symbolId))

  let shifted = placeGrid(
    size: CGSize(width: 400, height: 400),
    symbolDescriptors: symbols,
    seed: 444,
    columnCount: 4,
    rowCount: 4,
    subgrids: [
      .init(
        origin: .init(row: 3, column: 3),
        span: .init(rows: 1, columns: 1),
        symbolIDs: [primerSymbol],
      ),
      baseSubgrid,
    ],
  )

  var targetAreaPositions: [CGPoint] = []
  targetAreaPositions.reserveCapacity(12)
  for row in 0..<3 {
    for column in 0..<4 {
      targetAreaPositions.append(
        CGPoint(
          x: CGFloat(column * 100 + 50),
          y: CGFloat(row * 100 + 50),
        ),
      )
    }
  }
  let firstTargetIDs = first.filter { descriptor in
    targetAreaPositions.contains { $0 == descriptor.position }
  }.map(\.symbolId)
  let shiftedTargetIDs = shifted.filter { descriptor in
    targetAreaPositions.contains { $0 == descriptor.position }
  }.map(\.symbolId)
  #expect(firstTargetIDs != shiftedTargetIDs)
}

private func makeGridSymbolDescriptor(
  id: UUID,
  allowedRotationRangeDegrees: ClosedRange<Double>,
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    allowedRotationRangeDegrees: allowedRotationRangeDegrees,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
}

private func makeChoiceSymbolDescriptor(
  id: UUID,
  strategy: TesseraSymbolChoiceStrategy,
  choiceSeed: UInt64? = nil,
  choices: [ShapePlacementEngine.PlacementSymbolDescriptor],
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    choiceStrategy: strategy,
    choiceSeed: choiceSeed,
    renderDescriptor: nil,
    choices: choices,
  )
}

private func placeGrid(
  size: CGSize,
  symbolDescriptors: [ShapePlacementEngine.PlacementSymbolDescriptor],
  seed: UInt64,
  columnCount: Int,
  rowCount: Int,
  edgeBehavior: TesseraEdgeBehavior = .finite,
  offsetStrategy: PlacementModel.GridOffsetStrategy = .none,
  symbolOrder: PlacementModel.GridSymbolOrder = .rowMajor,
  pinnedSymbolDescriptors: [ShapePlacementEngine.PinnedSymbolDescriptor] = [],
  symbolPhases: [UUID: PlacementModel.Grid.SymbolPhase] = [:],
  subgrids: [PlacementModel.Grid.Subgrid] = [],
) -> [ShapePlacementEngine.PlacedSymbolDescriptor] {
  GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbolDescriptors,
    pinnedSymbolDescriptors: pinnedSymbolDescriptors,
    edgeBehavior: edgeBehavior,
    configuration: PlacementModel.Grid(
      columnCount: columnCount,
      rowCount: rowCount,
      offsetStrategy: offsetStrategy,
      symbolOrder: symbolOrder,
      seed: seed,
      symbolPhases: symbolPhases,
      subgrids: subgrids,
    ),
  )
}
