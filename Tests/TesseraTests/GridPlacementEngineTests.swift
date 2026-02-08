// By Dennis Müller

import CoreGraphics
import Foundation
@testable import Tessera
import Testing

@Test func gridPlacementReturnsEmptyWhenNoSymbolsAreProvided() async throws {
  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: CGSize(width: 200, height: 120),
    symbolDescriptors: [],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: TesseraPlacement.Grid(
      columnCount: 4,
      rowCount: 3,
      offsetStrategy: .none,
      symbolOrder: .sequence,
      seed: 9,
    ),
  )

  #expect(placed.isEmpty)
}

@Test func gridRotationVariesAcrossDifferentSeeds() async throws {
  let size = CGSize(width: 320, height: 200)
  let symbol = makeGridSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
    allowedRotationRangeDegrees: 5...175,
  )

  let first = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: TesseraPlacement.Grid(
      columnCount: 6,
      rowCount: 4,
      offsetStrategy: .none,
      symbolOrder: .sequence,
      seed: 1,
    ),
  )
  let second = GridShapePlacementEngine.placeSymbolDescriptors(
    in: size,
    symbolDescriptors: [symbol],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: TesseraPlacement.Grid(
      columnCount: 6,
      rowCount: 4,
      offsetStrategy: .none,
      symbolOrder: .sequence,
      seed: 2,
    ),
  )

  #expect(first.count == second.count)
  #expect(first.map(\.rotationRadians) != second.map(\.rotationRadians))
}

private func makeGridSymbolDescriptor(
  id: UUID,
  allowedRotationRangeDegrees: ClosedRange<Double>,
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    allowedRotationRangeDegrees: allowedRotationRangeDegrees,
    resolvedScaleRange: 1...1,
    collisionShape: .circle(center: .zero, radius: 1),
  )
}
