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

@Test func gridCenterPointMaskValidationChecksCenterOnlyOncePerCell() async throws {
  let size = CGSize(width: 120, height: 80)
  let placement = PlacementModel.Grid(
    sizing: .count(columns: 4, rows: 3),
    seed: 9,
  )
  let symbolDescriptor = makePerformanceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000208")!,
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 6, height: 6)),
  )
  let counter = Counter()
  let mask = CountingPlacementMask(counter: counter)

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    alphaMask: mask,
    maskConstraintMode: .centerPoint,
  )

  #expect(placed.count == 12)
  #expect(counter.value == 12)
}

@Test func sliceAlphaMaskContainsMatchesDenseMaskForSampledPoints() async throws {
  let rasterSize = CGSize(width: 160, height: 120)
  let rasterPixelsWide = 160
  let rasterPixelsHigh = 120
  let slice = SliceAlphaMask(
    rasterSize: rasterSize,
    rasterPixelsWide: rasterPixelsWide,
    rasterPixelsHigh: rasterPixelsHigh,
    sliceOriginX: 40,
    sliceOriginY: 20,
    slicePixelsWide: 30,
    slicePixelsHigh: 20,
    alphaBytes: makeSliceBytes(width: 30, height: 20),
  )
  let dense = TesseraAlphaMask(
    size: rasterSize,
    pixelsWide: rasterPixelsWide,
    pixelsHigh: rasterPixelsHigh,
    alphaBytes: slice.makeDenseAlphaBytes(),
    thresholdByte: 128,
    sampling: .nearest,
    invert: false,
  )

  for x in stride(from: 0.0, through: 159.0, by: 3.0) {
    for y in stride(from: 0.0, through: 119.0, by: 3.0) {
      let point = CGPoint(x: x, y: y)
      #expect(slice.contains(point) == dense.contains(point))
    }
  }
}

@Test func sliceAlphaMaskForEachRasterSampleSkipsOutOfBoundsIndices() async throws {
  let rasterPixelsWide = 12
  let rasterPixelsHigh = 10
  let slice = SliceAlphaMask(
    rasterSize: CGSize(width: 120, height: 100),
    rasterPixelsWide: rasterPixelsWide,
    rasterPixelsHigh: rasterPixelsHigh,
    sliceOriginX: rasterPixelsWide - 2,
    sliceOriginY: rasterPixelsHigh - 2,
    slicePixelsWide: 5,
    slicePixelsHigh: 5,
    alphaBytes: [UInt8](repeating: 255, count: 25),
  )

  let fullPixelCount = rasterPixelsWide * rasterPixelsHigh
  var emittedOutOfBoundsIndex = false
  slice.forEachRasterSample { fullIndex, _ in
    if fullIndex < 0 || fullIndex >= fullPixelCount {
      emittedOutOfBoundsIndex = true
    }
  }

  #expect(emittedOutOfBoundsIndex == false)
}

@Test func estimatedFilledFractionFindsThinCoverageWithRefinedSampling() async throws {
  let canvasSize = CGSize(width: 100, height: 100)
  let thinBand = CGRect(x: 50.055, y: 50.055, width: 0.02, height: 0.02)
  let estimated = MosaicPlacementPlanner.testingEstimatedFilledFraction(
    in: canvasSize,
    bounds: CGRect(origin: .zero, size: canvasSize),
    sampleGridSide: 96,
  ) { point in
    thinBand.contains(point)
  }

  #expect(estimated > 0)
}

@Test func organicReadsFilledFractionOncePerRun() async throws {
  let size = CGSize(width: 120, height: 120)
  let placement = PlacementModel.Organic(
    seed: 888,
    minimumSpacing: 1,
    density: 0.6,
    baseScaleRange: 1...1,
    maximumSymbolCount: 40,
  )
  let symbolDescriptor = makePerformanceSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000209")!,
    collisionShape: .circle(center: .zero, radius: 2),
  )
  let counter = Counter()
  let mask = FilledFractionCountingMask(counter: counter)
  var generator = SeededGenerator(seed: placement.seed)

  _ = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    alphaMask: mask,
    randomGenerator: &generator,
  )

  #expect(counter.value == 1)
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

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var currentValue = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return currentValue
  }

  func increment() {
    lock.lock()
    currentValue += 1
    lock.unlock()
  }
}

private struct CountingPlacementMask: PlacementMask {
  var counter: Counter

  func contains(_ point: CGPoint) -> Bool {
    counter.increment()
    return true
  }

  var filledFraction: Double {
    1
  }

  func filledBounds() -> CGRect? {
    CGRect(x: 0, y: 0, width: 120, height: 80)
  }
}

private struct FilledFractionCountingMask: PlacementMask {
  var counter: Counter

  func contains(_ point: CGPoint) -> Bool {
    true
  }

  var filledFraction: Double {
    counter.increment()
    return 0.5
  }

  func filledBounds() -> CGRect? {
    CGRect(x: 0, y: 0, width: 120, height: 120)
  }
}

private func makeSliceBytes(width: Int, height: Int) -> [UInt8] {
  guard width > 0, height > 0 else { return [] }

  var bytes = [UInt8](repeating: 0, count: width * height)
  for y in 0..<height {
    for x in 0..<width {
      if (x + y).isMultiple(of: 3) {
        bytes[y * width + x] = 255
      }
    }
  }
  return bytes
}
