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

@Test func columnShiftZeroDoesNotForceEvenColumnCountUnderWrapping() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .columnShift(fraction: 0),
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

@Test func rowShiftNonZeroForcesEvenRowCountUnderWrapping() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .rowShift(fraction: 0.25),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 12)
}

@Test func columnShiftNonZeroForcesEvenColumnCountUnderWrapping() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .columnShift(fraction: 0.25),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 12)
}

@Test func checkerShiftNonZeroForcesEvenCountsUnderWrapping() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .checkerShift(fraction: 0.25),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 16)
}

@Test func rowShiftNegativeActsAsZero() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .rowShift(fraction: -1),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 9)
  #expect(placed[3].position == CGPoint(x: 50, y: 150))
}

@Test func rowShiftNaNActsAsZero() async throws {
  let size = CGSize(width: 300, height: 300)

  let configuration = TesseraPlacement.Grid(
    columnCount: 3,
    rowCount: 3,
    offsetStrategy: .rowShift(fraction: Double.nan),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placed.count == 9)
  #expect(placed[3].position == CGPoint(x: 50, y: 150))
}

@Test func largeRowShiftCullsInFiniteButNotInWrapping() async throws {
  let size = CGSize(width: 200, height: 200)

  let configuration = TesseraPlacement.Grid(
    columnCount: 4,
    rowCount: 4,
    offsetStrategy: .rowShift(fraction: 2),
  )

  let placedFinite = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  let placedWrapped = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeTestSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placedFinite.count == 12)
  #expect(placedWrapped.count == 16)
}

@Test func gridPlacementRespectsRotationRange() async throws {
  let size = CGSize(width: 200, height: 100)

  let configuration = TesseraPlacement.Grid(
    columnCount: 2,
    rowCount: 1,
    offsetStrategy: .none,
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeRotationRangeSymbolDescriptor()],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(placed.count == 2)
  let expectedFirst = expectedRotationRadians(
    rangeDegrees: 0...180,
    rowIndex: 0,
    columnIndex: 0,
    symbolIndex: 0,
  )
  let expectedSecond = expectedRotationRadians(
    rangeDegrees: 0...180,
    rowIndex: 0,
    columnIndex: 1,
    symbolIndex: 1,
  )

  #expect(abs(placed[0].rotationRadians - expectedFirst) < 0.000001)
  #expect(abs(placed[1].rotationRadians - expectedSecond) < 0.000001)
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

private func makeRotationRangeSymbolDescriptor() -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: UUID(),
    weight: 1,
    allowedRotationRangeDegrees: 0...180,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
}

private func expectedRotationRadians(
  rangeDegrees: ClosedRange<Double>,
  rowIndex: Int,
  columnIndex: Int,
  symbolIndex: Int,
) -> Double {
  let lower = rangeDegrees.lowerBound
  let upper = rangeDegrees.upperBound
  guard upper > lower else {
    return lower * Double.pi / 180
  }

  let seed = gridRotationSeed(
    rowIndex: rowIndex,
    columnIndex: columnIndex,
    symbolIndex: symbolIndex,
  )
  var generator = SeededGenerator(seed: seed)
  let degrees = Double.random(in: lower...upper, using: &generator)
  return degrees * Double.pi / 180
}

private func gridRotationSeed(
  rowIndex: Int,
  columnIndex: Int,
  symbolIndex: Int,
) -> UInt64 {
  var seed = UInt64(truncatingIfNeeded: rowIndex) &* 0x9E37_79B9_7F4A_7C15
  seed ^= UInt64(truncatingIfNeeded: columnIndex) &* 0xBF58_476D_1CE4_E5B9
  seed ^= UInt64(truncatingIfNeeded: symbolIndex) &* 0x94D0_49BB_1331_11EB
  seed ^= seed >> 29
  return seed
}
