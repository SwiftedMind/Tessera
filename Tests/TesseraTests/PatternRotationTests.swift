// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test func patternRotationExpandsRotatedGridToFillTileUnderSeamlessWrapping() async throws {
  let size = CGSize(width: 200, height: 200)
  let patternRotationRadians = Double.pi / 4
  let anchor = CGPoint(x: size.width / 2, y: size.height / 2)

  let configuration = TesseraPlacement.Grid(
    columnCount: 6,
    rowCount: 6,
  )

  var randomGenerator = SeededGenerator(seed: 1)
  let placed = ShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    placement: .grid(configuration),
    patternRotationRadians: patternRotationRadians,
    patternRotationAnchor: anchor,
    randomGenerator: &randomGenerator,
  )

  #expect(placed.count == 36)
  #expect(placed.allSatisfy { (0..<size.width).contains($0.position.x) && (0..<size.height).contains($0.position.y) })

  // Coverage check: ensure the rotated grid spans the whole tile.
  let cellSize = CGSize(width: size.width / 6, height: size.height / 6)

  let xs = placed.map(\.position.x)
  let ys = placed.map(\.position.y)
  let minX = xs.min() ?? 0
  let maxX = xs.max() ?? 0
  let minY = ys.min() ?? 0
  let maxY = ys.max() ?? 0

  #expect(minX < cellSize.width)
  #expect(maxX > size.width - cellSize.width)
  #expect(minY < cellSize.height)
  #expect(maxY > size.height - cellSize.height)

  // Seamless check: under `.seamlessWrapping`, rotated grid positions wrap back into the tile bounds.
  let canonical = CGPoint(x: 0.5 * cellSize.width, y: 0.5 * cellSize.height)
  let expectedWrapped = wrapped(
    rotate(canonical, around: anchor, radians: patternRotationRadians),
    in: size,
  )
  let actual = placed[0].position
  #expect(abs(actual.x - expectedWrapped.x) < 0.000_1)
  #expect(abs(actual.y - expectedWrapped.y) < 0.000_1)

  // No duplicate placements (common failure mode when trying to force a fixed count).
  let quantized = Set(placed.map { "\(Int($0.position.x * 10000)):\(Int($0.position.y * 10000))" })
  #expect(quantized.count == placed.count)
}

@Test func patternRotationIsDeterministicForOrganicPlacement() async throws {
  let size = CGSize(width: 200, height: 200)
  let anchor = CGPoint(x: size.width / 2, y: size.height / 2)

  let configuration = TesseraPlacement.Organic(
    seed: 0,
    minimumSpacing: 30,
    density: 0.3,
    baseScaleRange: 1...1,
    maximumSymbolCount: 100,
  )
  let placement = TesseraPlacement.organic(configuration)
  let descriptors = [makeTestSymbolDescriptor()]

  var generatorA = SeededGenerator(seed: 42)
  let placedA = ShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: descriptors,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    placement: placement,
    patternRotationRadians: 0,
    patternRotationAnchor: anchor,
    randomGenerator: &generatorA,
  )

  var generatorB = SeededGenerator(seed: 42)
  let placedB = ShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: descriptors,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    placement: placement,
    patternRotationRadians: 0,
    patternRotationAnchor: anchor,
    randomGenerator: &generatorB,
  )

  #expect(placedA.count == placedB.count)
  for (lhs, rhs) in zip(placedA, placedB) {
    #expect(abs(lhs.position.x - rhs.position.x) < 0.000_1)
    #expect(abs(lhs.position.y - rhs.position.y) < 0.000_1)
  }

  var generatorC = SeededGenerator(seed: 42)
  let placedC = ShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: descriptors,
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    placement: placement,
    patternRotationRadians: Double.pi / 4,
    patternRotationAnchor: anchor,
    randomGenerator: &generatorC,
  )

  let differs = zip(placedA, placedC).contains { lhs, rhs in
    abs(lhs.position.x - rhs.position.x) > 0.000_1 || abs(lhs.position.y - rhs.position.y) > 0.000_1
  }
  #expect(differs)
  #expect(placedC.allSatisfy { (0..<size.width).contains($0.position.x) && (0..<size.height).contains($0.position.y) })
}

@Test func patternRotationIsNoOpUnderFiniteEdgeBehavior() async throws {
  let size = CGSize(width: 200, height: 200)
  let anchor = CGPoint(x: size.width / 2, y: size.height / 2)

  let configuration = TesseraPlacement.Grid(
    columnCount: 4,
    rowCount: 4,
  )

  var generatorA = SeededGenerator(seed: 1)
  let placedA = ShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    placement: .grid(configuration),
    patternRotationRadians: 0,
    patternRotationAnchor: anchor,
    randomGenerator: &generatorA,
  )

  var generatorB = SeededGenerator(seed: 1)
  let placedB = ShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    placement: .grid(configuration),
    patternRotationRadians: Double.pi / 4,
    patternRotationAnchor: anchor,
    randomGenerator: &generatorB,
  )

  #expect(placedA.count == 16)
  #expect(placedA.map(\.position) == placedB.map(\.position))
}

private func makeTestSymbolDescriptor() -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: UUID(),
    weight: 1,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
}

private func rotate(_ point: CGPoint, around anchor: CGPoint, radians: Double) -> CGPoint {
  let cosine = CGFloat(cos(radians))
  let sine = CGFloat(sin(radians))
  let translatedX = point.x - anchor.x
  let translatedY = point.y - anchor.y
  return CGPoint(
    x: anchor.x + translatedX * cosine - translatedY * sine,
    y: anchor.y + translatedX * sine + translatedY * cosine,
  )
}

private func wrapped(_ point: CGPoint, in size: CGSize) -> CGPoint {
  CGPoint(
    x: wrapped(point.x, modulus: size.width),
    y: wrapped(point.y, modulus: size.height),
  )
}

private func wrapped(_ value: CGFloat, modulus: CGFloat) -> CGFloat {
  guard modulus > 0 else { return 0 }

  let remainder = value.truncatingRemainder(dividingBy: modulus)
  return remainder >= 0 ? remainder : remainder + modulus
}
