// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func organicDenseCircleWorkloadUsesCircleFastPath() async throws {
  let size = CGSize(width: 260, height: 260)
  let placement = PlacementModel.Organic(
    seed: 501,
    minimumSpacing: 2,
    density: 0.95,
    baseScaleRange: 1...1,
    maximumSymbolCount: 260,
  )
  let symbolDescriptor = makePerformanceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
    collisionShape: .circle(center: .zero, radius: 2),
  )

  let diagnostics = ShapePlacementCollision.Diagnostics()
  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
    diagnostics: diagnostics,
  )

  #expect(placed.count > 50)
  #expect(diagnostics.pairChecks > 0)
  #expect(diagnostics.circleFastPathChecks > 0)
  #expect(diagnostics.polygonChecks == 0)
}

@Test func organicRectangleWorkloadUsesPolygonNarrowPhase() async throws {
  let size = CGSize(width: 260, height: 260)
  let placement = PlacementModel.Organic(
    seed: 777,
    minimumSpacing: 2,
    density: 0.95,
    baseScaleRange: 1...1,
    maximumSymbolCount: 220,
  )
  let symbolDescriptor = makePerformanceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 8, height: 6)),
  )

  let diagnostics = ShapePlacementCollision.Diagnostics()
  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
    diagnostics: diagnostics,
  )

  #expect(placed.isEmpty == false)
  #expect(diagnostics.pairChecks > 0)
  #expect(diagnostics.polygonChecks > 0)
}

@Test func organicCollisionDiagnosticsRemainDeterministicForSameSeed() async throws {
  let size = CGSize(width: 220, height: 220)
  let placement = PlacementModel.Organic(
    seed: 903,
    minimumSpacing: 3,
    density: 0.9,
    baseScaleRange: 1...1,
    maximumSymbolCount: 200,
  )
  let symbols: [ShapePlacementEngine.PlacementSymbolDescriptor] = [
    makePerformanceSymbolDescriptor(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
      collisionShape: .circle(center: .zero, radius: 3),
    ),
    makePerformanceSymbolDescriptor(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000204")!,
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 10, height: 7)),
    ),
  ]

  let diagnosticsA = ShapePlacementCollision.Diagnostics()
  var generatorA = SeededGenerator(seed: placement.seed)
  let placedA = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorA,
    diagnostics: diagnosticsA,
  )

  let diagnosticsB = ShapePlacementCollision.Diagnostics()
  var generatorB = SeededGenerator(seed: placement.seed)
  let placedB = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: symbols,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorB,
    diagnostics: diagnosticsB,
  )

  #expect(placedA.map(placementSnapshot) == placedB.map(placementSnapshot))
  #expect(diagnosticsA.pairChecks == diagnosticsB.pairChecks)
  #expect(diagnosticsA.circleFastPathChecks == diagnosticsB.circleFastPathChecks)
  #expect(diagnosticsA.polygonChecks == diagnosticsB.polygonChecks)
}

@Test func saturatedOrganicWorkloadTerminatesEarly() async throws {
  let size = CGSize(width: 140, height: 140)
  let placement = PlacementModel.Organic(
    seed: 1404,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 5000,
  )
  let symbolDescriptor = makePerformanceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000205")!,
    collisionShape: .circle(center: .zero, radius: 10),
  )

  let diagnostics = ShapePlacementCollision.Diagnostics()
  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
    diagnostics: diagnostics,
  )

  #expect(!placed.isEmpty)
  #expect(placed.count < 200)
  #expect(diagnostics.terminatedForSaturation)
  #expect(diagnostics.placementOuterAttempts < 1000)
  #expect(diagnostics.placementFailures > 0)
}

@Test func nonSaturatedOrganicWorkloadDoesNotTerminateEarly() async throws {
  let size = CGSize(width: 80, height: 80)
  let placement = PlacementModel.Organic(
    seed: 2205,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 120,
  )
  let symbolDescriptor = makePerformanceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000206")!,
    collisionShape: .circle(center: .zero, radius: 0),
  )

  let diagnostics = ShapePlacementCollision.Diagnostics()
  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generator,
    diagnostics: diagnostics,
  )

  #expect(placed.count == placement.maximumSymbolCount)
  #expect(diagnostics.terminatedForSaturation == false)
  #expect(diagnostics.placementOuterAttempts == placement.maximumSymbolCount)
  #expect(diagnostics.placementSuccesses == placement.maximumSymbolCount)
  #expect(diagnostics.placementFailures == 0)
}

@Test func saturatedTerminationDiagnosticsRemainDeterministicForSameSeed() async throws {
  let size = CGSize(width: 140, height: 140)
  let placement = PlacementModel.Organic(
    seed: 3306,
    minimumSpacing: 0,
    density: 1,
    baseScaleRange: 1...1,
    maximumSymbolCount: 5000,
  )
  let symbolDescriptor = makePerformanceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000207")!,
    collisionShape: .circle(center: .zero, radius: 10),
  )

  let diagnosticsA = ShapePlacementCollision.Diagnostics()
  var generatorA = SeededGenerator(seed: placement.seed)
  let placedA = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorA,
    diagnostics: diagnosticsA,
  )

  let diagnosticsB = ShapePlacementCollision.Diagnostics()
  var generatorB = SeededGenerator(seed: placement.seed)
  let placedB = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    randomGenerator: &generatorB,
    diagnostics: diagnosticsB,
  )

  #expect(placedA.map(placementSnapshot) == placedB.map(placementSnapshot))
  #expect(diagnosticsA.placementOuterAttempts == diagnosticsB.placementOuterAttempts)
  #expect(diagnosticsA.placementSuccesses == diagnosticsB.placementSuccesses)
  #expect(diagnosticsA.placementFailures == diagnosticsB.placementFailures)
  #expect(diagnosticsA.terminatedForSaturation == diagnosticsB.terminatedForSaturation)
}

private func makePerformanceSymbolDescriptor(
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

private func placementSnapshot(_ descriptor: ShapePlacementEngine.PlacedSymbolDescriptor) -> PlacementSnapshot {
  PlacementSnapshot(
    symbolId: descriptor.symbolId,
    renderSymbolId: descriptor.renderSymbolId,
    x: Double(descriptor.position.x),
    y: Double(descriptor.position.y),
    rotationRadians: descriptor.rotationRadians,
    scale: Double(descriptor.scale),
  )
}

private struct PlacementSnapshot: Hashable, Sendable {
  var symbolId: UUID
  var renderSymbolId: UUID
  var x: Double
  var y: Double
  var rotationRadians: Double
  var scale: Double
}
