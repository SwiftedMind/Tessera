// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func organicPlacementIsDeterministicForSameSeed() async throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 1,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 16,
  )
  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    collisionShape: .circle(center: .zero, radius: 0),
  )

  var generatorA = SeededGenerator(seed: placement.seed)
  let placedA = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorA,
  )

  var generatorB = SeededGenerator(seed: placement.seed)
  let placedB = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorB,
  )

  #expect(snapshot(placedA) == snapshot(placedB))
}

@Test func organicPlacementDiffersForDifferentSeeds() async throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 1,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 16,
  )
  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    collisionShape: .circle(center: .zero, radius: 0),
  )

  var generatorA = SeededGenerator(seed: 1)
  let placedA = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorA,
  )

  var generatorB = SeededGenerator(seed: 2)
  let placedB = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorB,
  )

  #expect(snapshot(placedA) != snapshot(placedB))
}

@Test func organicSequenceChoiceCyclesAcrossAcceptedPlacements() async throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 5,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 16,
  )
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
  let choiceSymbol = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .sequence,
    choices: [
      makeSymbolDescriptor(
        id: firstID,
        collisionShape: .circle(center: .zero, radius: 0),
      ),
      makeSymbolDescriptor(
        id: secondID,
        collisionShape: .circle(center: .zero, radius: 0),
      ),
    ],
  )

  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [choiceSymbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
  )

  #expect(placed.count == placement.maximumSymbolCount)
  #expect(placed.allSatisfy { $0.symbolId == rootID })
  for (index, descriptor) in placed.enumerated() {
    let expectedID = index.isMultiple(of: 2) ? firstID : secondID
    #expect(descriptor.renderSymbolId == expectedID)
  }
}

@Test func organicIndexSequenceChoiceCyclesAcrossAcceptedPlacements() async throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 6,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 12,
  )
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-000000000018")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000019")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-00000000001A")!
  let thirdID = UUID(uuidString: "00000000-0000-0000-0000-00000000001B")!
  let choiceSymbol = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .indexSequence([2, 0, 1]),
    choices: [
      makeSymbolDescriptor(id: firstID, collisionShape: .circle(center: .zero, radius: 0)),
      makeSymbolDescriptor(id: secondID, collisionShape: .circle(center: .zero, radius: 0)),
      makeSymbolDescriptor(id: thirdID, collisionShape: .circle(center: .zero, radius: 0)),
    ],
  )

  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [choiceSymbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
  )

  #expect(placed.count == placement.maximumSymbolCount)
  #expect(placed.allSatisfy { $0.symbolId == rootID })
  #expect(placed.map(\.renderSymbolId) == [
    thirdID, firstID, secondID,
    thirdID, firstID, secondID,
    thirdID, firstID, secondID,
    thirdID, firstID, secondID,
  ])
}

@Test func organicIndexSequenceChoiceNormalizesOutOfRangeAndNegativeIndices() async throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 7,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 9,
  )
  let rootID = UUID(uuidString: "00000000-0000-0000-0000-00000000001C")!
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-00000000001D")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-00000000001E")!
  let thirdID = UUID(uuidString: "00000000-0000-0000-0000-00000000001F")!
  let choiceSymbol = makeChoiceSymbolDescriptor(
    id: rootID,
    strategy: .indexSequence([7, -1, 1]),
    choices: [
      makeSymbolDescriptor(id: firstID, collisionShape: .circle(center: .zero, radius: 0)),
      makeSymbolDescriptor(id: secondID, collisionShape: .circle(center: .zero, radius: 0)),
      makeSymbolDescriptor(id: thirdID, collisionShape: .circle(center: .zero, radius: 0)),
    ],
  )

  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [choiceSymbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
  )

  #expect(placed.count == placement.maximumSymbolCount)
  #expect(placed.allSatisfy { $0.symbolId == rootID })
  #expect(placed.map(\.renderSymbolId) == [
    secondID, thirdID, secondID,
    secondID, thirdID, secondID,
    secondID, thirdID, secondID,
  ])
}

@Test func organicChoiceSeedChangesChoiceResolutionForSamePlacementSeed() async throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 5,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 20,
  )
  let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000014")!
  let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000015")!
  let choiceWithSeedA = makeChoiceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!,
    strategy: .weightedRandom,
    choiceSeed: 3,
    choices: [
      makeSymbolDescriptor(
        id: firstID,
        collisionShape: .circle(center: .zero, radius: 0),
      ),
      makeSymbolDescriptor(
        id: secondID,
        collisionShape: .circle(center: .zero, radius: 0),
      ),
    ],
  )
  let choiceWithSeedB = makeChoiceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000017")!,
    strategy: .weightedRandom,
    choiceSeed: 9,
    choices: [
      makeSymbolDescriptor(
        id: firstID,
        collisionShape: .circle(center: .zero, radius: 0),
      ),
      makeSymbolDescriptor(
        id: secondID,
        collisionShape: .circle(center: .zero, radius: 0),
      ),
    ],
  )

  var generatorAFirst = SeededGenerator(seed: placement.seed)
  let withSeedAFirst = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [choiceWithSeedA],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorAFirst,
  )
  var generatorASecond = SeededGenerator(seed: placement.seed)
  let withSeedASecond = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [choiceWithSeedA],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorASecond,
  )
  var generatorB = SeededGenerator(seed: placement.seed)
  let withSeedB = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [choiceWithSeedB],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorB,
  )

  #expect(withSeedAFirst.map(\.renderSymbolId) == withSeedASecond.map(\.renderSymbolId))
  #expect(withSeedAFirst.map(\.renderSymbolId) != withSeedB.map(\.renderSymbolId))
}

@Test func organicPlacementDoesNotOverlapSymbols() async throws {
  let size = CGSize(width: 256, height: 256)
  let placement = PlacementModel.Organic(
    seed: 123,
    minimumSpacing: 5,
    density: 0.5,
    baseScaleRange: 1...1,
    maximumSymbolCount: 25,
  )
  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    collisionShape: .circle(center: .zero, radius: 10),
  )
  let polygons = CollisionMath.polygons(for: symbolDescriptor.collisionShape)

  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
  )

  #expect(placed.count > 5)

  let buffer = CGFloat(placement.minimumSpacing)
  for aIndex in placed.indices {
    for bIndex in placed.indices where bIndex > aIndex {
      let isIntersecting = CollisionMath.polygonsIntersect(
        polygons,
        transformA: placed[aIndex].collisionTransform,
        polygons,
        transformB: placed[bIndex].collisionTransform,
        buffer: buffer,
      )
      #expect(isIntersecting == false)
    }
  }
}

@Test func organicPlacementAvoidsPinnedSymbolCollisions() async throws {
  let size = CGSize(width: 256, height: 256)
  let placement = PlacementModel.Organic(
    seed: 123,
    minimumSpacing: 0,
    density: 0.8,
    baseScaleRange: 1...1,
    maximumSymbolCount: 25,
  )
  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    collisionShape: .circle(center: .zero, radius: 10),
  )
  let pinnedSymbol = ShapePlacementEngine.PinnedSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
    position: CGPoint(x: size.width / 2, y: size.height / 2),
    rotationRadians: 0,
    scale: 1,
    collisionShape: .circle(center: .zero, radius: 60),
  )
  let generatedPolygons = CollisionMath.polygons(for: symbolDescriptor.collisionShape)
  let pinnedPolygons = CollisionMath.polygons(for: pinnedSymbol.collisionShape)
  let pinnedTransform = CollisionTransform(
    position: pinnedSymbol.position,
    rotation: 0,
    scale: pinnedSymbol.scale,
  )

  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [pinnedSymbol],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
  )

  #expect(placed.isEmpty == false)

  for descriptor in placed {
    let isIntersecting = CollisionMath.polygonsIntersect(
      generatedPolygons,
      transformA: descriptor.collisionTransform,
      pinnedPolygons,
      transformB: pinnedTransform,
      buffer: 0,
    )
    #expect(isIntersecting == false)
  }
}

@Test func organicPlacementWrapsPinnedCollisionsAcrossTileEdges() async throws {
  let size = CGSize(width: 101, height: 80)
  let placement = PlacementModel.Organic(
    seed: 991,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 2,
  )
  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
    collisionShape: .circle(center: .zero, radius: 20),
  )
  let pinnedSymbol = ShapePlacementEngine.PinnedSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
    position: CGPoint(x: 4, y: size.height / 2),
    rotationRadians: 0,
    scale: 1,
    collisionShape: .circle(center: .zero, radius: 25),
  )
  let region = TesseraCanvasRegion.polygon(
    [
      CGPoint(x: 99, y: 0),
      CGPoint(x: 101, y: 0),
      CGPoint(x: 101, y: size.height),
      CGPoint(x: 99, y: size.height),
    ],
    mapping: .canvasCoordinates,
  )
  let resolvedRegion = region.resolvedPolygon(in: size)

  #expect(resolvedRegion != nil)

  var finiteGenerator = SeededGenerator(seed: placement.seed)
  let finitePlaced = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [pinnedSymbol],
    edgeBehavior: .finite,
    configuration: placement,
    region: resolvedRegion,
    randomGenerator: &finiteGenerator,
  )

  var wrappedGenerator = SeededGenerator(seed: placement.seed)
  let wrappedPlaced = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [pinnedSymbol],
    edgeBehavior: .seamlessWrapping,
    configuration: placement,
    region: resolvedRegion,
    randomGenerator: &wrappedGenerator,
  )

  #expect(finitePlaced.count == 1)
  #expect(wrappedPlaced.isEmpty)
}

private struct PlacementSnapshot: Hashable, Sendable {
  var symbolId: UUID
  var renderSymbolId: UUID
  var x: Double
  var y: Double
  var rotationRadians: Double
  var scale: Double
}

private func snapshot(_ placed: [ShapePlacementEngine.PlacedSymbolDescriptor]) -> [PlacementSnapshot] {
  placed.map { descriptor in
    PlacementSnapshot(
      symbolId: descriptor.symbolId,
      renderSymbolId: descriptor.renderSymbolId,
      x: Double(descriptor.position.x),
      y: Double(descriptor.position.y),
      rotationRadians: descriptor.rotationRadians,
      scale: Double(descriptor.scale),
    )
  }
}

private func makeSymbolDescriptor(
  id: UUID,
  collisionShape: CollisionShape,
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: collisionShape,
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
    zIndex: 0,
    sourceOrder: 0,
    choiceStrategy: strategy,
    choiceSeed: choiceSeed,
    renderDescriptor: nil,
    choices: choices,
  )
}
