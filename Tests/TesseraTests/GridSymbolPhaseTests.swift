// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func symbolPhaseDefaultsToZeroOffset() async throws {
  let symbolID = UUID()
  let symbol = makeSymbolDescriptor(id: symbolID)
  let size = CGSize(width: 200, height: 200)

  let configurationWithoutPhase = PlacementModel.Grid(
    columnCount: 2,
    rowCount: 2,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 7,
  )
  let configurationWithZeroPhase = PlacementModel.Grid(
    columnCount: 2,
    rowCount: 2,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 7,
    symbolPhases: [symbolID: .init(x: 0, y: 0)],
  )

  let withoutPhase = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configurationWithoutPhase,
  )
  let withZeroPhase = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configurationWithZeroPhase,
  )

  #expect(withoutPhase.map(\.position) == withZeroPhase.map(\.position))
  #expect(withoutPhase.map(\.symbolId) == withZeroPhase.map(\.symbolId))
}

@Test func symbolPhaseAppliesPerSelectedSymbolID() async throws {
  let symbolA = makeSymbolDescriptor(id: UUID())
  let symbolB = makeSymbolDescriptor(id: UUID())
  let size = CGSize(width: 400, height: 400)
  let configuration = PlacementModel.Grid(
    columnCount: 4,
    rowCount: 4,
    offsetStrategy: .none,
    symbolOrder: .diagonal,
    seed: 13,
    symbolPhases: [symbolB.id: .init(x: 0.25, y: 0.25)],
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbolA, symbolB],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(placed.count == 16)
  #expect(placed[0].symbolId == symbolA.id)
  #expect(placed[0].position == CGPoint(x: 50, y: 50))
  #expect(placed[1].symbolId == symbolB.id)
  #expect(placed[1].position == CGPoint(x: 175, y: 75))
  #expect(placed[4].symbolId == symbolB.id)
  #expect(placed[4].position == CGPoint(x: 75, y: 175))
}

@Test func symbolPhaseSupportsValuesGreaterThanOne() async throws {
  let symbolID = UUID()
  let size = CGSize(width: 400, height: 100)
  let configuration = PlacementModel.Grid(
    columnCount: 4,
    rowCount: 1,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 1,
    symbolPhases: [symbolID: .init(x: 1.25, y: 0)],
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeSymbolDescriptor(id: symbolID)],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(placed.count == 3)
  #expect(placed.map(\.position.x) == [175, 275, 375])
}

@Test func symbolPhaseNaNAndInfinityActAsZero() async throws {
  let symbolID = UUID()
  let size = CGSize(width: 200, height: 200)
  var phase = PlacementModel.Grid.SymbolPhase(x: 0.2, y: 0.3)
  phase.x = .nan
  phase.y = .infinity
  let defaultConfiguration = PlacementModel.Grid(
    columnCount: 2,
    rowCount: 2,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 3,
  )
  let nonFinitePhaseConfiguration = PlacementModel.Grid(
    columnCount: 2,
    rowCount: 2,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 3,
    symbolPhases: [symbolID: phase],
  )

  let symbol = makeSymbolDescriptor(id: symbolID)
  let placedDefault = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: defaultConfiguration,
  )
  let placedWithPhase = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: nonFinitePhaseConfiguration,
  )

  #expect(phase.x == 0)
  #expect(phase.y == 0)
  #expect(placedDefault.map(\.position) == placedWithPhase.map(\.position))
}

@Test func largeSymbolPhaseCullsInFiniteButWrapsInSeamlessMode() async throws {
  let symbolID = UUID()
  let size = CGSize(width: 400, height: 100)
  let configuration = PlacementModel.Grid(
    columnCount: 4,
    rowCount: 1,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 1,
    symbolPhases: [symbolID: .init(x: 1.25, y: 0)],
  )
  let symbol = makeSymbolDescriptor(id: symbolID)

  let placedFinite = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )
  let placedWrapped = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .seamlessWrapping,
    configuration: configuration,
  )

  #expect(placedFinite.count == 3)
  #expect(placedWrapped.count == 4)
  #expect(placedWrapped.map(\.position.x) == [175, 275, 375, 75])
}

@Test func symbolPhaseWithMergedCellsUsesBaseCellUnits() async throws {
  let symbolID = UUID()
  let size = CGSize(width: 400, height: 200)
  let configuration = PlacementModel.Grid(
    columnCount: 4,
    rowCount: 2,
    offsetStrategy: .none,
    symbolOrder: .sequence,
    seed: 31,
    symbolPhases: [symbolID: .init(x: 0.25, y: 0)],
    mergedCells: [
      .init(origin: .init(row: 0, column: 0), span: .init(rows: 1, columns: 2)),
    ],
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [makeSymbolDescriptor(id: symbolID)],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: configuration,
  )

  #expect(placed.count == 7)
  #expect(placed.contains { $0.position == CGPoint(x: 125, y: 50) })
  #expect(placed.contains { $0.position == CGPoint(x: 150, y: 50) } == false)
}

private func makeSymbolDescriptor(id: UUID) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
}
