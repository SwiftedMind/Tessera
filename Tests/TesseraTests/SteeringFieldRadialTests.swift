// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test func steeringFieldConvenienceConstructorsSetExpectedShapes() async throws {
  let linear = PlacementModel.SteeringField.linear(
    values: 0...1,
    from: .leading,
    to: .trailing,
  )
  let radial = PlacementModel.SteeringField.radial(
    values: 0...1,
    center: .center,
    radius: .shortestSideFraction(0.5),
  )

  switch linear.shape {
  case let .linear(from, to):
    #expect(abs(from.x - 0) < 0.000_001)
    #expect(abs(to.x - 1) < 0.000_001)
  case .radial:
    Issue.record("Expected linear shape")
  }

  switch radial.shape {
  case let .radial(center, radius):
    #expect(abs(center.x - 0.5) < 0.000_001)
    #expect(abs(center.y - 0.5) < 0.000_001)
    #expect(radius == .shortestSideFraction(0.5))
  case .linear:
    Issue.record("Expected radial shape")
  }
}

@Test func steeringFieldCanonicalizesNonFiniteInputsForHashableSafety() async throws {
  var field = PlacementModel.SteeringField.linear(
    values: 0...1,
    from: .leading,
    to: .trailing,
  )

  field.shape = .radial(
    center: .init(x: .nan, y: .infinity),
    radius: .shortestSideFraction(.nan),
  )
  field.values = 0...Double.infinity

  switch field.shape {
  case let .radial(center, radius):
    #expect(center.x == 0)
    #expect(center.y == 0)
    #expect(radius == .autoFarthestCorner)
  case .linear:
    Issue.record("Expected radial shape")
  }

  #expect(field.values.lowerBound == 0)
  #expect(field.values.upperBound == 0)

  let set: Set<PlacementModel.SteeringField> = [field]
  #expect(set.contains(field))
}

@Test func radialFieldAutoRadiusInterpolatesCenterToCorner() async throws {
  let size = CGSize(width: 120, height: 120)
  let field = PlacementModel.SteeringField.radial(
    values: 0...10,
    center: .center,
    easing: .linear,
  )

  let center = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 60, y: 60),
    canvasSize: size,
  )
  let corner = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 0, y: 0),
    canvasSize: size,
  )

  #expect(abs(center - 0) < 0.000_001)
  #expect(abs(corner - 10) < 0.000_001)
}

@Test func radialFieldAutoRadiusUsesFarthestCornerForOffCenterOrigin() async throws {
  let size = CGSize(width: 200, height: 100)
  let field = PlacementModel.SteeringField.radial(
    values: 0...10,
    center: .topLeading,
    radius: .autoFarthestCorner,
    easing: .linear,
  )

  let origin = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 0, y: 0),
    canvasSize: size,
  )
  let bottomRight = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 200, y: 100),
    canvasSize: size,
  )

  #expect(abs(origin - 0) < 0.000_001)
  #expect(abs(bottomRight - 10) < 0.000_001)
}

@Test func radialFieldShortestSideFractionRadiusInterpolatesByDistance() async throws {
  let size = CGSize(width: 200, height: 100)
  let field = PlacementModel.SteeringField.radial(
    values: 0...1,
    center: .center,
    radius: .shortestSideFraction(0.5),
    easing: .linear,
  )

  let half = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 125, y: 50),
    canvasSize: size,
  )
  let edge = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 150, y: 50),
    canvasSize: size,
  )

  #expect(abs(half - 0.5) < 0.000_001)
  #expect(abs(edge - 1) < 0.000_001)
}

@Test func radialFieldInvalidExplicitRadiusFallsBackToAuto() async throws {
  let size = CGSize(width: 180, height: 120)
  let position = CGPoint(x: 0, y: 0)
  let auto = PlacementModel.SteeringField.radial(
    values: 2...8,
    center: .center,
    radius: .autoFarthestCorner,
    easing: .linear,
  )

  let invalidFields: [PlacementModel.SteeringField] = [
    .radial(values: 2...8, center: .center, radius: .shortestSideFraction(.nan), easing: .linear),
    .radial(values: 2...8, center: .center, radius: .shortestSideFraction(0), easing: .linear),
    .radial(values: 2...8, center: .center, radius: .shortestSideFraction(-0.5), easing: .linear),
  ]

  let autoValue = ShapePlacementSteering.value(
    for: auto,
    position: position,
    canvasSize: size,
  )
  for field in invalidFields {
    let value = ShapePlacementSteering.value(
      for: field,
      position: position,
      canvasSize: size,
    )
    #expect(abs(value - autoValue) < 0.000_001)
  }
}

@Test func radialEasingIsMonotonicAlongRadius() async throws {
  let size = CGSize(width: 100, height: 100)
  let easings: [PlacementModel.SteeringField.Easing] = [
    .linear,
    .smoothStep,
    .easeIn,
    .easeOut,
    .easeInOut,
  ]

  for easing in easings {
    let field = PlacementModel.SteeringField.radial(
      values: 0...1,
      center: .center,
      radius: .shortestSideFraction(0.5),
      easing: easing,
    )

    var values: [Double] = []
    for x in stride(from: 50, through: 100, by: 5) {
      values.append(
        ShapePlacementSteering.value(
          for: field,
          position: CGPoint(x: CGFloat(x), y: 50),
          canvasSize: size,
        ),
      )
    }

    for index in 0..<(values.count - 1) {
      #expect(values[index] <= values[index + 1])
    }
  }
}

@Test func organicRadialScaleSteeringChangesCenterVsEdgeAverage() async throws {
  let size = CGSize(width: 260, height: 260)
  let placement = PlacementModel.Organic(
    seed: 401,
    minimumSpacing: 2,
    density: 0.95,
    baseScaleRange: 1...1,
    maximumSymbolCount: 360,
    steering: .init(
      scaleMultiplier: .radial(
        values: 0.6...1.8,
        center: .center,
        radius: .shortestSideFraction(0.55),
        easing: .smoothStep,
      ),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
    collisionShape: .circle(center: .zero, radius: 1.5),
    resolvedScaleRange: 1...1,
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

  let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
  let minSide = min(size.width, size.height)
  let radius = minSide * 0.55

  let centerBand = placed.filter { descriptor in
    descriptor.position.distance(to: centerPoint) <= radius * 0.35
  }
  let edgeBand = placed.filter { descriptor in
    descriptor.position.distance(to: centerPoint) >= radius * 0.85
  }

  #expect(centerBand.count >= 8)
  #expect(edgeBand.count >= 8)

  let centerAverageScale = centerBand.map { Double($0.scale) }.reduce(0, +) / Double(centerBand.count)
  let edgeAverageScale = edgeBand.map { Double($0.scale) }.reduce(0, +) / Double(edgeBand.count)

  #expect(edgeAverageScale > centerAverageScale * 1.25)
}

@Test func gridRadialRotationOffsetSteeringChangesCenterVsEdgeAverage() async throws {
  let size = CGSize(width: 240, height: 240)
  let configuration = PlacementModel.Grid(
    columnCount: 9,
    rowCount: 9,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 404,
    steering: .init(
      rotationOffsetDegrees: .radial(
        values: 0...60,
        center: .center,
        radius: .autoFarthestCorner,
        easing: .linear,
      ),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000032")!,
    collisionShape: .circle(center: .zero, radius: 1),
    resolvedScaleRange: 1...1,
    allowedRotationRangeDegrees: 0...0,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
  let sortedByDistance = placed.sorted {
    $0.position.distance(to: centerPoint) < $1.position.distance(to: centerPoint)
  }
  let sampleCount = max(4, sortedByDistance.count / 5)
  let centerSample = Array(sortedByDistance.prefix(sampleCount))
  let edgeSample = Array(sortedByDistance.suffix(sampleCount))

  #expect(centerSample.count == sampleCount)
  #expect(edgeSample.count == sampleCount)

  let centerAverageRotation = centerSample.map(\.rotationRadians).reduce(0, +) / Double(centerSample.count)
  let edgeAverageRotation = edgeSample.map(\.rotationRadians).reduce(0, +) / Double(edgeSample.count)

  #expect(edgeAverageRotation > centerAverageRotation + 0.2)
}

@Test func organicRadialSteeringRemainsDeterministicForSameSeed() async throws {
  let size = CGSize(width: 170, height: 170)
  let placement = PlacementModel.Organic(
    seed: 409,
    minimumSpacing: 4,
    density: 0.8,
    baseScaleRange: 0.85...1.1,
    maximumSymbolCount: 140,
    steering: .init(
      minimumSpacingMultiplier: .radial(values: 0.7...1.5, center: .center, radius: .autoFarthestCorner),
      scaleMultiplier: .radial(values: 0.75...1.3, center: .center, radius: .shortestSideFraction(0.6)),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000033")!,
    collisionShape: .circle(center: .zero, radius: 3),
    resolvedScaleRange: 0.85...1.1,
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

  #expect(placementSnapshot(placedA) == placementSnapshot(placedB))
}

private struct SteeringPlacementSnapshot: Hashable, Sendable {
  var symbolId: UUID
  var x: Double
  var y: Double
  var rotationRadians: Double
  var scale: Double
}

private func placementSnapshot(_ placed: [ShapePlacementEngine.PlacedSymbolDescriptor]) -> [SteeringPlacementSnapshot] {
  placed.map { descriptor in
    SteeringPlacementSnapshot(
      symbolId: descriptor.symbolId,
      x: Double(descriptor.position.x),
      y: Double(descriptor.position.y),
      rotationRadians: descriptor.rotationRadians,
      scale: Double(descriptor.scale),
    )
  }
}

private func makeSteeringSymbolDescriptor(
  id: UUID,
  collisionShape: CollisionShape,
  resolvedScaleRange: ClosedRange<Double>,
  allowedRotationRangeDegrees: ClosedRange<Double> = 0...0,
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    allowedRotationRangeDegrees: allowedRotationRangeDegrees,
    resolvedScaleRange: resolvedScaleRange,
    collisionShape: collisionShape,
  )
}

private extension CGPoint {
  func distance(to other: CGPoint) -> CGFloat {
    let deltaX = x - other.x
    let deltaY = y - other.y
    return sqrt(deltaX * deltaX + deltaY * deltaY)
  }
}
