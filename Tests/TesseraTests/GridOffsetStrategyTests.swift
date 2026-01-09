// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func rowShiftFractionOneAppliesFullCellShift() async throws {
  let size = CGSize(width: 200, height: 200)

  let configuration = TesseraPlacement.Grid(
    columnCount: 2,
    rowCount: 2,
    offsetStrategy: .rowShift(fraction: 1),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 4)
  #expect(placed[0].position == CGPoint(x: 50, y: 50))
  #expect(placed[1].position == CGPoint(x: 150, y: 50))
  #expect(placed[2].position == CGPoint(x: 150, y: 150))
  #expect(placed[3].position == CGPoint(x: 50, y: 150))
}

@Test func rowShiftSupportsValuesGreaterThanOne() async throws {
  let size = CGSize(width: 200, height: 200)

  let configuration = TesseraPlacement.Grid(
    columnCount: 4,
    rowCount: 2,
    offsetStrategy: .rowShift(fraction: 1.25),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 8)
  #expect(placed[4].position == CGPoint(x: 87.5, y: 150))
  #expect(placed[7].position == CGPoint(x: 37.5, y: 150))
}

@Test func checkerShiftFractionOneAppliesFullCellShift() async throws {
  let size = CGSize(width: 200, height: 200)

  let configuration = TesseraPlacement.Grid(
    columnCount: 2,
    rowCount: 2,
    offsetStrategy: .checkerShift(fraction: 1),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 4)
  #expect(placed[0].position == CGPoint(x: 50, y: 50))
  #expect(placed[1].position == CGPoint(x: 50, y: 150))
  #expect(placed[2].position == CGPoint(x: 150, y: 50))
  #expect(placed[3].position == CGPoint(x: 150, y: 150))
}

@Test func rowShiftZeroDoesNotForceEvenRowCountUnderWrapping() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .rowShift(fraction: 0),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 9)
}

@Test func checkerShiftZeroDoesNotForceEvenCountsUnderWrapping() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .checkerShift(fraction: 0),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 9)
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
