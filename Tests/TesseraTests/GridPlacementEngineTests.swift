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

@Test func gridPlacementSupportsMergedCellsAndComputesMergedCenter() async throws {
  let placed = placeGrid(
    size: CGSize(width: 400, height: 400),
    symbolDescriptors: [
      makeGridSymbolDescriptor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
    seed: 11,
    columnCount: 4,
    rowCount: 4,
    mergedCells: [
      .init(origin: .init(row: 1, column: 1), span: .init(rows: 2, columns: 2)),
    ],
  )

  #expect(placed.count == 13)
  #expect(placed.count(where: { $0.position == CGPoint(x: 200, y: 200) }) == 1)
  #expect(placed.contains { $0.position == CGPoint(x: 150, y: 150) } == false)
  #expect(placed.contains { $0.position == CGPoint(x: 250, y: 150) } == false)
  #expect(placed.contains { $0.position == CGPoint(x: 150, y: 250) } == false)
  #expect(placed.contains { $0.position == CGPoint(x: 250, y: 250) } == false)
}

@Test func gridPlacementSkipsOverlappingMergedCellsAfterFirstValidMerge() async throws {
  let placed = placeGrid(
    size: CGSize(width: 300, height: 300),
    symbolDescriptors: [
      makeGridSymbolDescriptor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000072")!,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
    seed: 12,
    columnCount: 3,
    rowCount: 3,
    mergedCells: [
      .init(origin: .init(row: 0, column: 0), span: .init(rows: 2, columns: 2)),
      .init(origin: .init(row: 1, column: 1), span: .init(rows: 2, columns: 2)),
    ],
  )

  #expect(placed.count == 6)
  #expect(placed.contains { $0.position == CGPoint(x: 100, y: 100) })
  #expect(placed.contains { $0.position == CGPoint(x: 200, y: 200) } == false)
}

@Test func gridPlacementSkipsOutOfBoundsMergedCells() async throws {
  let placed = placeGrid(
    size: CGSize(width: 300, height: 300),
    symbolDescriptors: [
      makeGridSymbolDescriptor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000073")!,
        allowedRotationRangeDegrees: 0...0,
      ),
    ],
    seed: 13,
    columnCount: 3,
    rowCount: 3,
    mergedCells: [
      .init(origin: .init(row: 2, column: 2), span: .init(rows: 2, columns: 2)),
    ],
  )

  #expect(placed.count == 9)
  #expect(placed.contains { $0.position == CGPoint(x: 250, y: 250) })
}

@Test func gridRowMajorOrderUsesContiguousResolvedPlacementIndicesWithMergedCells() async throws {
  let symbolIDs = [
    UUID(uuidString: "00000000-0000-0000-0000-000000000074")!,
    UUID(uuidString: "00000000-0000-0000-0000-000000000075")!,
    UUID(uuidString: "00000000-0000-0000-0000-000000000076")!,
  ]
  let symbols = symbolIDs.map { id in
    makeGridSymbolDescriptor(
      id: id,
      allowedRotationRangeDegrees: 0...0,
    )
  }
  let placed = placeGrid(
    size: CGSize(width: 300, height: 200),
    symbolDescriptors: symbols,
    seed: 14,
    columnCount: 3,
    rowCount: 2,
    mergedCells: [
      .init(origin: .init(row: 0, column: 1), span: .init(rows: 1, columns: 2)),
    ],
  )

  #expect(placed.count == 5)
  #expect(placed.map(\.position) == [
    CGPoint(x: 50, y: 50),
    CGPoint(x: 200, y: 50),
    CGPoint(x: 50, y: 150),
    CGPoint(x: 150, y: 150),
    CGPoint(x: 250, y: 150),
  ])
  #expect(placed.map(\.symbolId) == [
    symbolIDs[0],
    symbolIDs[1],
    symbolIDs[2],
    symbolIDs[0],
    symbolIDs[1],
  ])
}

@Test func gridColumnMajorOrderUsesContiguousRegularIndicesWithMergedCells() async throws {
  let symbolIDs = [
    UUID(uuidString: "00000000-0000-0000-0000-000000000079")!,
    UUID(uuidString: "00000000-0000-0000-0000-000000000080")!,
    UUID(uuidString: "00000000-0000-0000-0000-000000000081")!,
  ]
  let symbols = symbolIDs.map { id in
    makeGridSymbolDescriptor(
      id: id,
      allowedRotationRangeDegrees: 0...0,
    )
  }
  let placed = placeGrid(
    size: CGSize(width: 300, height: 200),
    symbolDescriptors: symbols,
    seed: 15,
    columnCount: 3,
    rowCount: 2,
    symbolOrder: .columnMajor,
    mergedCells: [
      .init(origin: .init(row: 0, column: 1), span: .init(rows: 1, columns: 2)),
    ],
  )

  #expect(placed.count == 5)
  #expect(placed.map(\.position) == [
    CGPoint(x: 50, y: 50),
    CGPoint(x: 200, y: 50),
    CGPoint(x: 50, y: 150),
    CGPoint(x: 150, y: 150),
    CGPoint(x: 250, y: 150),
  ])
  #expect(placed.map(\.symbolId) == [
    symbolIDs[0],
    symbolIDs[2],
    symbolIDs[1],
    symbolIDs[0],
    symbolIDs[1],
  ])
}

@Test func gridMergedCellsRemainDeterministicWithWrappingAndOffset() async throws {
  let symbols = [
    makeGridSymbolDescriptor(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000077")!,
      allowedRotationRangeDegrees: 0...0,
    ),
    makeGridSymbolDescriptor(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000078")!,
      allowedRotationRangeDegrees: 0...0,
    ),
  ]
  let mergedCells: [PlacementModel.Grid.CellMerge] = [
    .init(origin: .init(row: 1, column: 1), span: .init(rows: 2, columns: 1)),
  ]

  let first = placeGrid(
    size: CGSize(width: 280, height: 280),
    symbolDescriptors: symbols,
    seed: 99,
    columnCount: 5,
    rowCount: 5,
    edgeBehavior: .seamlessWrapping,
    offsetStrategy: .rowShift(fraction: 0.5),
    symbolOrder: .randomWeightedPerCell,
    mergedCells: mergedCells,
  )
  let second = placeGrid(
    size: CGSize(width: 280, height: 280),
    symbolDescriptors: symbols,
    seed: 99,
    columnCount: 5,
    rowCount: 5,
    edgeBehavior: .seamlessWrapping,
    offsetStrategy: .rowShift(fraction: 0.5),
    symbolOrder: .randomWeightedPerCell,
    mergedCells: mergedCells,
  )

  #expect(first.map(\.symbolId) == second.map(\.symbolId))
  #expect(first.map(\.position) == second.map(\.position))
  #expect(first.map(\.rotationRadians) == second.map(\.rotationRadians))
}

@Test func gridMergedCellCanOverrideSymbolAndKeepRegularSequenceForRegularCells() async throws {
  let regularA = UUID(uuidString: "00000000-0000-0000-0000-000000000079")!
  let regularB = UUID(uuidString: "00000000-0000-0000-0000-000000000080")!
  let mergedOnly = UUID(uuidString: "00000000-0000-0000-0000-000000000081")!
  let symbols = [
    makeGridSymbolDescriptor(id: regularA, allowedRotationRangeDegrees: 0...0),
    makeGridSymbolDescriptor(id: regularB, allowedRotationRangeDegrees: 0...0),
    makeGridSymbolDescriptor(id: mergedOnly, allowedRotationRangeDegrees: 0...0),
  ]

  let placed = placeGrid(
    size: CGSize(width: 400, height: 100),
    symbolDescriptors: symbols,
    seed: 101,
    columnCount: 4,
    rowCount: 1,
    mergedCells: [
      .init(
        origin: .init(row: 0, column: 1),
        span: .init(rows: 1, columns: 2),
        symbolID: mergedOnly,
      ),
    ],
  )

  #expect(placed.map(\.position) == [
    CGPoint(x: 50, y: 50),
    CGPoint(x: 200, y: 50),
    CGPoint(x: 350, y: 50),
  ])
  #expect(placed.map(\.symbolId) == [regularA, mergedOnly, regularB])
}

@Test func gridCanIncludeMergedOverrideSymbolsInRegularCellsWhenConfigured() async throws {
  let regular = UUID(uuidString: "00000000-0000-0000-0000-000000000082")!
  let mergedOnly = UUID(uuidString: "00000000-0000-0000-0000-000000000083")!
  let symbols = [
    makeGridSymbolDescriptor(id: regular, allowedRotationRangeDegrees: 0...0),
    makeGridSymbolDescriptor(id: mergedOnly, allowedRotationRangeDegrees: 0...0),
  ]

  let placed = placeGrid(
    size: CGSize(width: 300, height: 100),
    symbolDescriptors: symbols,
    seed: 102,
    columnCount: 3,
    rowCount: 1,
    mergedCells: [
      .init(
        origin: .init(row: 0, column: 1),
        span: .init(rows: 1, columns: 1),
        symbolID: mergedOnly,
      ),
    ],
    excludeMergedSymbolsFromRegularCells: false,
  )

  #expect(placed.map(\.symbolId) == [regular, mergedOnly, mergedOnly])
}

@Test func gridMergedCellWithUnknownOverrideIDFallsBackToRegularAssignment() async throws {
  let regularA = UUID(uuidString: "00000000-0000-0000-0000-000000000086")!
  let regularB = UUID(uuidString: "00000000-0000-0000-0000-000000000087")!
  let unknownOverride = UUID(uuidString: "00000000-0000-0000-0000-000000000088")!
  let symbols = [
    makeGridSymbolDescriptor(id: regularA, allowedRotationRangeDegrees: 0...0),
    makeGridSymbolDescriptor(id: regularB, allowedRotationRangeDegrees: 0...0),
  ]

  let placed = placeGrid(
    size: CGSize(width: 300, height: 100),
    symbolDescriptors: symbols,
    seed: 333,
    columnCount: 3,
    rowCount: 1,
    mergedCells: [
      .init(
        origin: .init(row: 0, column: 1),
        span: .init(rows: 1, columns: 1),
        symbolID: unknownOverride,
      ),
    ],
  )

  #expect(placed.map(\.symbolId) == [regularA, regularB, regularA])
}

@Test func gridMergedCellFitSizingScalesSymbolToMergedCellBounds() async throws {
  let regular = UUID(uuidString: "00000000-0000-0000-0000-000000000084")!
  let mergedOnly = UUID(uuidString: "00000000-0000-0000-0000-000000000085")!
  let regularSymbol = makeGridSymbolDescriptor(id: regular, allowedRotationRangeDegrees: 0...0)
  let mergedSymbol = ShapePlacementEngine.PlacementSymbolDescriptor(
    id: mergedOnly,
    weight: 1,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 20, height: 20)),
  )

  let placed = placeGrid(
    size: CGSize(width: 400, height: 200),
    symbolDescriptors: [regularSymbol, mergedSymbol],
    seed: 103,
    columnCount: 4,
    rowCount: 2,
    mergedCells: [
      .init(
        origin: .init(row: 0, column: 1),
        span: .init(rows: 2, columns: 2),
        symbolID: mergedOnly,
        symbolSizing: .fitMergedCell,
      ),
    ],
  )

  guard let mergedPlacement = placed.first(where: { $0.symbolId == mergedOnly }) else {
    Issue.record("Expected merged override symbol placement")
    return
  }

  #expect(abs(mergedPlacement.position.x - 200) < 0.0001)
  #expect(abs(mergedPlacement.position.y - 100) < 0.0001)
  #expect(abs(mergedPlacement.scale - 10) < 0.0001)
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
  mergedCells: [PlacementModel.Grid.CellMerge] = [],
  excludeMergedSymbolsFromRegularCells: Bool = true,
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
      mergedCells: mergedCells,
      excludeMergedSymbolsFromRegularCells: excludeMergedSymbolsFromRegularCells,
    ),
  )
}
