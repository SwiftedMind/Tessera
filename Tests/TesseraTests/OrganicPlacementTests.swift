// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func organicPlacementIsDeterministicForSameSeed() async throws {
  let size = CGSize(width: 100, height: 100)
  let placement = TesseraPlacement.Organic(
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
  let placement = TesseraPlacement.Organic(
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

@Test func organicPlacementDoesNotOverlapSymbols() async throws {
  let size = CGSize(width: 256, height: 256)
  let placement = TesseraPlacement.Organic(
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
  let placement = TesseraPlacement.Organic(
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

private struct PlacementSnapshot: Hashable, Sendable {
  var symbolId: UUID
  var x: Double
  var y: Double
  var rotationRadians: Double
  var scale: Double
}

private func snapshot(_ placed: [ShapePlacementEngine.PlacedSymbolDescriptor]) -> [PlacementSnapshot] {
  placed.map { descriptor in
    PlacementSnapshot(
      symbolId: descriptor.symbolId,
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
