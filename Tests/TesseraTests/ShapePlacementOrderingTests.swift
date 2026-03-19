// By Dennis Müller

import CoreGraphics
import SwiftUI
@testable import Tessera
import Testing

@Test func placementOrderingSortsLowerZIndexBehindHigherZIndex() {
  let backID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!
  let frontID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!
  let placements = [
    makePlacedDescriptor(symbolID: frontID, zIndex: 10, sourceOrder: 1),
    makePlacedDescriptor(symbolID: backID, zIndex: 0, sourceOrder: 0),
  ]

  let orderedIDs = ShapePlacementOrdering
    .normalized(placements)
    .map(\.symbolId)

  #expect(orderedIDs == [backID, frontID])
}

@Test func placementOrderingUsesSourceOrderWhenZIndexMatches() {
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D3")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D4")!
  let placements = [
    makePlacedDescriptor(symbolID: secondID, zIndex: 2, sourceOrder: 1),
    makePlacedDescriptor(symbolID: firstID, zIndex: 2, sourceOrder: 0),
  ]

  let orderedIDs = ShapePlacementOrdering
    .normalized(placements)
    .map(\.symbolId)

  #expect(orderedIDs == [firstID, secondID])
}

@Test func placementOrderingUsesPlacementSequenceWhenZIndexAndSourceOrderMatch() {
  let repeatedSymbolID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D5")!
  let firstPlacement = makePlacedDescriptor(
    symbolID: repeatedSymbolID,
    zIndex: 3,
    sourceOrder: 0,
    position: CGPoint(x: 10, y: 10),
  )
  let secondPlacement = makePlacedDescriptor(
    symbolID: repeatedSymbolID,
    zIndex: 3,
    sourceOrder: 0,
    position: CGPoint(x: 20, y: 20),
  )

  let orderedPositions = ShapePlacementOrdering
    .normalized([firstPlacement, secondPlacement])
    .map(\.position)

  #expect(orderedPositions == [CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 20)])
}

@Test func placementOrderingTreatsNonFiniteZIndexAsZero() {
  let nanID = UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!
  let positiveID = UUID(uuidString: "00000000-0000-0000-0000-0000000000DE")!
  let negativeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000DF")!
  let placements = [
    makePlacedDescriptor(symbolID: positiveID, zIndex: 2, sourceOrder: 2),
    makePlacedDescriptor(symbolID: nanID, zIndex: .nan, sourceOrder: 0),
    makePlacedDescriptor(symbolID: negativeID, zIndex: -.infinity, sourceOrder: 1),
  ]

  let orderedIDs = ShapePlacementOrdering
    .normalized(placements)
    .map(\.symbolId)

  #expect(orderedIDs == [nanID, negativeID, positiveID])
}

@Test func choiceSymbolDescriptorsInheritParentRenderOrder() throws {
  let child = TesseraSymbol(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D6")!,
    zIndex: 99,
    collisionShape: .circle(center: .zero, radius: 1),
  ) { Circle() }
  let choiceSymbol = TesseraSymbol(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D7")!,
    zIndex: 4,
    choiceStrategy: .sequence,
    choices: [child],
  )

  let descriptors = ShapePlacementEngine.makeSymbolDescriptors(
    from: [choiceSymbol],
    placement: .grid(PlacementModel.Grid(sizing: .count(columns: 1, rows: 1))),
  )
  let descriptor = try #require(descriptors.first)
  let childDescriptor = try #require(descriptor.choices.first)

  #expect(descriptor.zIndex == 4)
  #expect(descriptor.sourceOrder == 0)
  #expect(childDescriptor.zIndex == 4)
  #expect(childDescriptor.sourceOrder == 0)
}

@Test @MainActor func synchronousPlacementsEmitNormalizedDrawOrder() {
  let backID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D8")!
  let frontID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D9")!
  let configuration = TesseraConfiguration(
    symbols: [
      TesseraSymbol(
        id: frontID,
        zIndex: 10,
        allowedRotationRange: .zero...(.zero),
        scaleRange: 1.0...1.0,
        collisionShape: .circle(center: .zero, radius: 1),
      ) { Circle() },
      TesseraSymbol(
        id: backID,
        zIndex: 0,
        allowedRotationRange: .zero...(.zero),
        scaleRange: 1.0...1.0,
        collisionShape: .circle(center: .zero, radius: 1),
      ) { Circle() },
    ],
    placement: .grid(
      PlacementModel.Grid(
        sizing: .count(columns: 2, rows: 1),
      ),
    ),
  )
  let symbolDescriptors = ShapePlacementEngine.makeSymbolDescriptors(
    from: configuration.symbols,
    placement: configuration.placement,
  )
  var randomGenerator = SeededGenerator(seed: 1)

  let orderedIDs = ShapePlacementEngine
    .placeSymbolDescriptors(
      in: CGSize(width: 120, height: 60),
      symbolDescriptors: symbolDescriptors,
      edgeBehavior: .finite,
      placement: configuration.placement,
      randomGenerator: &randomGenerator,
    )
    .map(\.symbolId)

  #expect(orderedIDs == [backID, frontID])
}

@Test func renderOrderMetadataUsesFirstDuplicateSymbolID() {
  let sharedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E0")!
  let first = TesseraSymbol(
    id: sharedID,
    zIndex: 4,
    collisionShape: .circle(center: .zero, radius: 1),
  ) { Circle() }
  let second = TesseraSymbol(
    id: sharedID,
    zIndex: .infinity,
    collisionShape: .circle(center: .zero, radius: 1),
  ) { Circle() }

  let metadata = [first, second].renderOrderMetadataBySymbolID

  #expect(metadata.count == 1)
  #expect(metadata[sharedID]?.zIndex == 4)
  #expect(metadata[sharedID]?.sourceOrder == 0)
}

private func makePlacedDescriptor(
  symbolID: UUID,
  zIndex: Double,
  sourceOrder: Int,
  position: CGPoint = .zero,
) -> ShapePlacementEngine.PlacedSymbolDescriptor {
  ShapePlacementEngine.PlacedSymbolDescriptor(
    symbolId: symbolID,
    renderSymbolId: symbolID,
    zIndex: zIndex,
    sourceOrder: sourceOrder,
    position: position,
    rotationRadians: 0,
    scale: 1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
}
