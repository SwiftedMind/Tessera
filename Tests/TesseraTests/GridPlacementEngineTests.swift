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
    configuration: TesseraPlacement.Grid(
      columnCount: 4,
      rowCount: 3,
      offsetStrategy: .none,
      symbolOrder: .sequence,
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
    configuration: TesseraPlacement.Grid(
      columnCount: 6,
      rowCount: 4,
      offsetStrategy: .none,
      symbolOrder: .sequence,
      seed: 1,
    ),
  )
  let second = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: TesseraPlacement.Grid(
      columnCount: 6,
      rowCount: 4,
      offsetStrategy: .none,
      symbolOrder: .sequence,
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
  let symbolPhases: [UUID: TesseraPlacement.Grid.SymbolPhase] = [
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
  pinnedSymbolDescriptors: [ShapePlacementEngine.PinnedSymbolDescriptor] = [],
  symbolPhases: [UUID: TesseraPlacement.Grid.SymbolPhase] = [:],
) -> [ShapePlacementEngine.PlacedSymbolDescriptor] {
  GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbolDescriptors,
    pinnedSymbolDescriptors: pinnedSymbolDescriptors,
    edgeBehavior: .finite,
    configuration: TesseraPlacement.Grid(
      columnCount: columnCount,
      rowCount: rowCount,
      offsetStrategy: .none,
      symbolOrder: .sequence,
      seed: seed,
      symbolPhases: symbolPhases,
    ),
  )
}
