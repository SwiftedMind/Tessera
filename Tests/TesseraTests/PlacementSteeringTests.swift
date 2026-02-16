// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test func steeringFieldInterpolatesTopToBottomLinearly() async throws {
  let size = CGSize(width: 100, height: 100)
  let field = PlacementModel.SteeringField(
    values: 0...10,
    from: .top,
    to: .bottom,
    easing: .linear,
  )

  let top = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 50, y: 0),
    canvasSize: size,
  )
  let middle = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 50, y: 50),
    canvasSize: size,
  )
  let bottom = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 50, y: 100),
    canvasSize: size,
  )

  #expect(abs(top - 0) < 0.000_001)
  #expect(abs(middle - 5) < 0.000_001)
  #expect(abs(bottom - 10) < 0.000_001)
}

@Test func steeringFieldHandlesDegenerateAxisByReturningLowerBound() async throws {
  let size = CGSize(width: 120, height: 80)
  let field = PlacementModel.SteeringField(
    values: 2...8,
    from: .center,
    to: .center,
    easing: .linear,
  )

  let value = ShapePlacementSteering.value(
    for: field,
    position: CGPoint(x: 100, y: 40),
    canvasSize: size,
  )

  #expect(abs(value - 2) < 0.000_001)
}

@Test func steeringEasingIsMonotonicAlongAxis() async throws {
  let size = CGSize(width: 100, height: 100)
  let easings: [PlacementModel.SteeringField.Easing] = [
    .linear,
    .smoothStep,
    .easeIn,
    .easeOut,
    .easeInOut,
  ]

  for easing in easings {
    let field = PlacementModel.SteeringField(
      values: 0...1,
      from: .leading,
      to: .trailing,
      easing: easing,
    )

    var values: [Double] = []
    for x in stride(from: 0, through: 100, by: 5) {
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

@Test func organicSteeringIncreasesNearestNeighborDistanceTowardBottom() async throws {
  let size = CGSize(width: 300, height: 300)
  let placement = PlacementModel.Organic(
    seed: 99,
    minimumSpacing: 6,
    density: 0.9,
    baseScaleRange: 1...1,
    maximumSymbolCount: 320,
    steering: .init(
      minimumSpacingMultiplier: .init(
        values: 0.25...2.0,
        from: .top,
        to: .bottom,
        easing: .linear,
      ),
      scaleMultiplier: nil,
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
    collisionShape: .circle(center: .zero, radius: 3),
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

  let topBand = placed.filter { $0.position.y <= size.height * 0.33 }
  let bottomBand = placed.filter { $0.position.y >= size.height * 0.66 }

  #expect(topBand.count >= 8)
  #expect(bottomBand.count >= 8)

  let topAverage = averageNearestNeighborDistance(for: topBand, among: placed)
  let bottomAverage = averageNearestNeighborDistance(for: bottomBand, among: placed)

  #expect(bottomAverage > topAverage * 1.2)
}

@Test func organicScaleSteeringIncreasesAverageScaleTowardBottom() async throws {
  let size = CGSize(width: 240, height: 240)
  let placement = PlacementModel.Organic(
    seed: 23,
    minimumSpacing: 3,
    density: 0.9,
    baseScaleRange: 1...1,
    maximumSymbolCount: 300,
    steering: .init(
      minimumSpacingMultiplier: nil,
      scaleMultiplier: .init(
        values: 0.5...1.8,
        from: .top,
        to: .bottom,
        easing: .linear,
      ),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
    collisionShape: .circle(center: .zero, radius: 2),
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

  let topBand = placed.filter { $0.position.y <= size.height * 0.33 }
  let bottomBand = placed.filter { $0.position.y >= size.height * 0.66 }

  #expect(topBand.count >= 8)
  #expect(bottomBand.count >= 8)

  let topAverageScale = topBand.map { Double($0.scale) }.reduce(0, +) / Double(topBand.count)
  let bottomAverageScale = bottomBand.map { Double($0.scale) }.reduce(0, +) / Double(bottomBand.count)

  #expect(bottomAverageScale > topAverageScale * 1.35)
}

@Test func organicRotationOffsetSteeringIncreasesRotationTowardBottom() async throws {
  let size = CGSize(width: 220, height: 220)
  let placement = PlacementModel.Organic(
    seed: 88,
    minimumSpacing: 2,
    density: 0.9,
    baseScaleRange: 1...1,
    maximumSymbolCount: 280,
    steering: .init(
      rotationOffsetDegrees: .init(
        values: 0...180,
        from: .top,
        to: .bottom,
        easing: .linear,
      ),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!,
    collisionShape: .circle(center: .zero, radius: 2),
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

  let topBand = placed.filter { $0.position.y <= size.height * 0.33 }
  let bottomBand = placed.filter { $0.position.y >= size.height * 0.66 }

  #expect(topBand.count >= 8)
  #expect(bottomBand.count >= 8)

  let topAverageRotation = topBand.map(\.rotationRadians).reduce(0, +) / Double(topBand.count)
  let bottomAverageRotation = bottomBand.map(\.rotationRadians).reduce(0, +) / Double(bottomBand.count)

  #expect(bottomAverageRotation > topAverageRotation + 0.8)
}

@Test func organicSteeringRemainsDeterministicForSameSeed() async throws {
  let size = CGSize(width: 160, height: 160)
  let placement = PlacementModel.Organic(
    seed: 7,
    minimumSpacing: 5,
    density: 0.75,
    baseScaleRange: 0.8...1.1,
    maximumSymbolCount: 120,
    steering: .init(
      minimumSpacingMultiplier: .init(values: 0.5...1.4, from: .leading, to: .trailing, easing: .easeInOut),
      scaleMultiplier: .init(values: 0.8...1.2, from: .topLeading, to: .bottomTrailing, easing: .smoothStep),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
    collisionShape: .circle(center: .zero, radius: 4),
    resolvedScaleRange: 0.8...1.1,
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

@Test func gridScaleSteeringIncreasesScaleAcrossRows() async throws {
  let size = CGSize(width: 100, height: 100)
  let configuration = PlacementModel.Grid(
    columnCount: 1,
    rowCount: 5,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 1,
    steering: .init(
      scaleMultiplier: .init(
        values: 0.5...2.0,
        from: .top,
        to: .bottom,
        easing: .linear,
      ),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
    collisionShape: .circle(center: .zero, radius: 1),
    resolvedScaleRange: 1...1,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  let sortedScales = placed
    .sorted { $0.position.y < $1.position.y }
    .map { Double($0.scale) }

  #expect(sortedScales.count == 5)
  for index in 0..<(sortedScales.count - 1) {
    #expect(sortedScales[index] <= sortedScales[index + 1])
  }
  #expect(sortedScales.first! < sortedScales.last!)
}

@Test func gridRotationMultiplierSteeringIncreasesRotationAcrossColumns() async throws {
  let size = CGSize(width: 120, height: 40)
  let configuration = PlacementModel.Grid(
    columnCount: 5,
    rowCount: 1,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 1,
    steering: .init(
      rotationMultiplier: .init(
        values: 0.5...1.5,
        from: .leading,
        to: .trailing,
        easing: .linear,
      ),
    ),
  )
  let symbolDescriptor = makeSteeringSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!,
    collisionShape: .circle(center: .zero, radius: 1),
    resolvedScaleRange: 1...1,
    allowedRotationRangeDegrees: 90...90,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  let sortedRotations = placed
    .sorted { $0.position.x < $1.position.x }
    .map(\.rotationRadians)

  #expect(sortedRotations.count == 5)
  for index in 0..<(sortedRotations.count - 1) {
    #expect(sortedRotations[index] <= sortedRotations[index + 1])
  }
  #expect(sortedRotations.first! < sortedRotations.last!)
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

private func averageNearestNeighborDistance(
  for placements: [ShapePlacementEngine.PlacedSymbolDescriptor],
  among allPlacements: [ShapePlacementEngine.PlacedSymbolDescriptor],
) -> Double {
  let distances = placements.compactMap { candidate -> Double? in
    var minimumDistanceSquared = Double.greatestFiniteMagnitude
    var foundNeighbor = false

    for other in allPlacements where other.position != candidate.position {
      let deltaX = Double(candidate.position.x - other.position.x)
      let deltaY = Double(candidate.position.y - other.position.y)
      let distanceSquared = deltaX * deltaX + deltaY * deltaY
      if distanceSquared < minimumDistanceSquared {
        minimumDistanceSquared = distanceSquared
        foundNeighbor = true
      }
    }

    guard foundNeighbor else { return nil }

    return sqrt(minimumDistanceSquared)
  }

  guard distances.isEmpty == false else { return 0 }

  return distances.reduce(0, +) / Double(distances.count)
}
