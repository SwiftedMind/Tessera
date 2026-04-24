// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func `organic placement is deterministic for same seed`() throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 1,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 16,
  )
  let symbolDescriptor = try makeSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
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

@Test func `organic placement differs for different seeds`() throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 1,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 16,
  )
  let symbolDescriptor = try makeSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
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

@Test func `organic sequence choice cycles across accepted placements`() throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 5,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 16,
  )
  let rootID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000011"))
  let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000012"))
  let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000013"))
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

@Test func `organic index sequence choice cycles across accepted placements`() throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 6,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 12,
  )
  let rootID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000018"))
  let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000019"))
  let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000001A"))
  let thirdID = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000001B"))
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

@Test func `organic index sequence choice normalizes out of range and negative indices`() throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 7,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 9,
  )
  let rootID = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000001C"))
  let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000001D"))
  let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000001E"))
  let thirdID = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000001F"))
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

@Test func `organic choice seed changes choice resolution for same placement seed`() throws {
  let size = CGSize(width: 100, height: 100)
  let placement = PlacementModel.Organic(
    seed: 5,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 20,
  )
  let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000014"))
  let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000015"))
  let choiceWithSeedA = try makeChoiceSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000016")),
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
  let choiceWithSeedB = try makeChoiceSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000017")),
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

@Test func `organic placement does not overlap symbols`() throws {
  let size = CGSize(width: 256, height: 256)
  let placement = PlacementModel.Organic(
    seed: 123,
    minimumSpacing: 5,
    density: 0.5,
    baseScaleRange: 1...1,
    maximumSymbolCount: 25,
  )
  let symbolDescriptor = try makeSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
    collisionShape: .circle(center: .zero, radius: 10),
  )

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
  expectNoOverlaps(in: placed, minimumSpacing: placement.minimumSpacing)
}

@Test func `dense organic placement is deterministic and does not reduce accepted count`() throws {
  let size = CGSize(width: 140, height: 140)
  let rejectionPlacement = PlacementModel.Organic(
    seed: 44,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 90,
  )
  let densePlacement = PlacementModel.Organic(
    seed: rejectionPlacement.seed,
    minimumSpacing: rejectionPlacement.minimumSpacing,
    density: rejectionPlacement.density,
    baseScaleRange: rejectionPlacement.baseScaleRange,
    maximumSymbolCount: rejectionPlacement.maximumSymbolCount,
    fillStrategy: .dense,
  )
  let symbols = try [
    makeSymbolDescriptor(
      id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000025")),
      collisionShape: .circle(center: .zero, radius: 12),
    ),
    makeSymbolDescriptor(
      id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000026")),
      collisionShape: .circle(center: .zero, radius: 5),
    ),
  ]

  var rejectionGenerator = SeededGenerator(seed: rejectionPlacement.seed)
  let rejectionPlaced = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: rejectionPlacement,
    randomGenerator: &rejectionGenerator,
  )

  var denseGeneratorA = SeededGenerator(seed: densePlacement.seed)
  let densePlacedA = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: densePlacement,
    randomGenerator: &denseGeneratorA,
  )

  var denseGeneratorB = SeededGenerator(seed: densePlacement.seed)
  let densePlacedB = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: densePlacement,
    randomGenerator: &denseGeneratorB,
  )

  #expect(snapshot(densePlacedA) == snapshot(densePlacedB))
  #expect(densePlacedA.count >= rejectionPlaced.count)
  expectNoOverlaps(in: densePlacedA, minimumSpacing: densePlacement.minimumSpacing)
}

@Test func `organic placement rescues tight gap by retrying smaller scales`() throws {
  let size = CGSize(width: 160, height: 120)
  let symbolDescriptor = try makeSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000022")),
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 0.45...1,
    collisionShape: .circle(center: .zero, radius: 20),
  )
  let leftPinned = try ShapePlacementEngine.PinnedSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000023")),
    position: CGPoint(x: 50, y: 60),
    rotationRadians: 0,
    scale: 1,
    collisionShape: .circle(center: .zero, radius: 20),
  )
  let rightPinned = try ShapePlacementEngine.PinnedSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000024")),
    position: CGPoint(x: 114, y: 60),
    rotationRadians: 0,
    scale: 1,
    collisionShape: .circle(center: .zero, radius: 20),
  )
  let region = TesseraCanvasRegion.polygon(
    [
      CGPoint(x: 79, y: 58),
      CGPoint(x: 85, y: 58),
      CGPoint(x: 85, y: 62),
      CGPoint(x: 79, y: 62),
    ],
    mapping: .canvasCoordinates,
  )
  let resolvedRegion = region.resolvedPolygon(in: size)

  #expect(resolvedRegion != nil)

  var rescuedScale: Double?

  for seed in UInt64(0)..<256 {
    let placement = PlacementModel.Organic(
      seed: seed,
      minimumSpacing: 0,
      density: 1,
      baseScaleRange: 1...1,
      maximumSymbolCount: 20,
    )
    let diagnostics = ShapePlacementCollision.Diagnostics()
    var generator = SeededGenerator(seed: placement.seed)
    let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
      in: size,
      symbolDescriptors: [symbolDescriptor],
      pinnedSymbolDescriptors: [leftPinned, rightPinned],
      edgeBehavior: .finite,
      configuration: placement,
      region: resolvedRegion,
      randomGenerator: &generator,
      diagnostics: diagnostics,
    )

    guard diagnostics.placementSuccessesUsingRescue == 1 else { continue }

    #expect(placed.count == 1)
    rescuedScale = Double(placed[0].scale)
    break
  }

  #expect(rescuedScale != nil)
  if let rescuedScale {
    #expect(rescuedScale <= 0.6)
  }
}

@Test func `organic placement avoids pinned symbol collisions`() throws {
  let size = CGSize(width: 256, height: 256)
  let placement = PlacementModel.Organic(
    seed: 123,
    minimumSpacing: 0,
    density: 0.8,
    baseScaleRange: 1...1,
    maximumSymbolCount: 25,
  )
  let symbolDescriptor = try makeSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
    collisionShape: .circle(center: .zero, radius: 10),
  )
  let pinnedSymbol = try ShapePlacementEngine.PinnedSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
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

@Test func `organic placement wraps pinned collisions across tile edges`() throws {
  let size = CGSize(width: 101, height: 80)
  let placement = PlacementModel.Organic(
    seed: 991,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 2,
  )
  let symbolDescriptor = try makeSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000020")),
    collisionShape: .circle(center: .zero, radius: 20),
  )
  let pinnedSymbol = try ShapePlacementEngine.PinnedSymbolDescriptor(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000021")),
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

private struct PlacementSnapshot: Hashable {
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

private func expectNoOverlaps(
  in placed: [ShapePlacementEngine.PlacedSymbolDescriptor],
  minimumSpacing: Double,
) {
  let polygonsByIndex = placed.map { CollisionMath.polygons(for: $0.collisionShape) }
  let buffer = CGFloat(minimumSpacing)

  for aIndex in placed.indices {
    for bIndex in placed.indices where bIndex > aIndex {
      let isIntersecting = CollisionMath.polygonsIntersect(
        polygonsByIndex[aIndex],
        transformA: placed[aIndex].collisionTransform,
        polygonsByIndex[bIndex],
        transformB: placed[bIndex].collisionTransform,
        buffer: buffer,
      )
      #expect(isIntersecting == false)
    }
  }
}

private func makeSymbolDescriptor(
  id: UUID,
  allowedRotationRangeDegrees: ClosedRange<Double> = 0...0,
  resolvedScaleRange: ClosedRange<Double> = 1...1,
  collisionShape: CollisionShape,
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    allowedRotationRangeDegrees: allowedRotationRangeDegrees,
    resolvedScaleRange: resolvedScaleRange,
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
