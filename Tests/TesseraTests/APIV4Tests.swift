// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test func placementFactoryProvidesExpectedDefaults() async throws {
  let placement = TesseraPlacement.organic()

  guard case let .organic(options) = placement else {
    Issue.record("Expected organic placement")
    return
  }

  #expect(options.minimumSpacing == 10)
  #expect(options.density == 0.6)
  #expect(options.baseScaleRange.lowerBound == 0.9)
  #expect(options.baseScaleRange.upperBound == 1.1)
  #expect(options.maximumSymbolCount == 512)
  #expect(options.steering == .none)
  #expect(options.showsCollisionOverlay == false)
}

@Test func gridPlacementFactoryProvidesExpectedDefaults() async throws {
  let placement = TesseraPlacement.grid(columns: 3, rows: 2)

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.columnCount == 3)
  #expect(options.rowCount == 2)
  #expect(options.offsetStrategy == .none)
  #expect(options.symbolOrder == .rowMajor)
  #expect(options.symbolPhases.isEmpty)
  #expect(options.showsGridOverlay == false)
  #expect(options.subgrids.isEmpty)
  #expect(options.steering == .none)
}

@Test func gridPlacementFactoryMapsSymbolPhases() async throws {
  let symbolID = UUID()
  let phases: [UUID: TesseraPlacement.Grid.SymbolPhase] = [
    symbolID: .init(x: 0.5, y: 0.25),
  ]
  let placement = TesseraPlacement.grid(
    columns: 4,
    rows: 3,
    symbolPhases: phases,
  )

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.symbolPhases == phases)
}

@Test func gridPlacementFactoryMapsShowsGridOverlay() async throws {
  let placement = TesseraPlacement.grid(
    columns: 4,
    rows: 3,
    showsGridOverlay: true,
  )

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.showsGridOverlay)
}

@Test func gridPlacementFactoryMapsSubgrids() async throws {
  let subgrids: [TesseraPlacement.Grid.Subgrid] = [
    .init(
      at: .init(row: 1, column: 2),
      spanning: .init(rows: 2, columns: 3),
      symbols: [
        Symbol(
          id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B0")!,
          collider: .shape(.circle(center: .zero, radius: 1)),
        ) { Circle() },
      ],
      symbolOrder: .columnMajor,
      seed: 777,
    ),
  ]
  let placement = TesseraPlacement.grid(
    columns: 6,
    rows: 4,
    subgrids: subgrids,
  )

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.subgrids == subgrids)
}

@Test func patternInitializerResolvesInlineSubgridSymbols() async throws {
  let regularID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
  let subgridID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
  let regularSymbol = Symbol(id: regularID, collider: .shape(.circle(center: .zero, radius: 1))) { Circle() }
  let subgridSymbol = Symbol(id: subgridID, collider: .shape(.circle(center: .zero, radius: 2))) { Circle() }

  let pattern = Pattern(
    symbols: [regularSymbol],
    placement: .grid(
      columns: 6,
      rows: 4,
      subgrids: [
        .init(
          at: .init(row: 1, column: 2),
          spanning: .init(rows: 2, columns: 3),
          symbols: [subgridSymbol],
          symbolOrder: .snake,
          seed: 505,
        ),
      ],
    ),
  )

  #expect(pattern.symbols.count == 1)
  #expect(Set(pattern.symbols.map(\.id)) == Set([regularID]))

  guard case let .grid(options) = pattern.placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.subgrids.count == 1)
  #expect(options.subgrids[0].origin == .init(row: 1, column: 2))
  #expect(options.subgrids[0].span == .init(rows: 2, columns: 3))
  #expect(options.subgrids[0].symbols.map(\.id) == [subgridID])
  #expect(options.subgrids[0].symbolOrder == .snake)
  #expect(options.subgrids[0].seed == 505)

  let legacy = pattern.legacyConfiguration
  #expect(Set(legacy.symbols.map(\.id)) == Set([regularID, subgridID]))

  guard case let .grid(legacyOptions) = legacy.placement else {
    Issue.record("Expected legacy grid placement")
    return
  }

  #expect(legacyOptions.subgrids.count == 1)
  #expect(legacyOptions.subgrids[0].symbolIDs == [subgridID])
  #expect(legacyOptions.subgrids[0].symbolOrder == .snake)
  #expect(legacyOptions.subgrids[0].seed == 505)
}

@Test func gridOptionsCanWrapInternalBaseConfiguration() async throws {
  let subgridID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B5")!
  let internalBase = PlacementModel.Grid(
    columnCount: 7,
    rowCount: 5,
    offsetStrategy: .checkerShift(fraction: 0.5),
    symbolOrder: .snake,
    seed: 909,
    symbolPhases: [subgridID: .init(x: 0.25, y: 0.5)],
    steering: .none,
    showsGridOverlay: true,
    subgrids: [
      .init(
        at: .init(row: 1, column: 1),
        spanning: .init(rows: 2, columns: 2),
        symbolIDs: [subgridID],
        symbolOrder: .columnMajor,
        seed: 123,
      ),
    ],
  )
  let options = TesseraPlacement.Grid(base: internalBase)

  #expect(options.columnCount == 7)
  #expect(options.rowCount == 5)
  #expect(options.offsetStrategy == .checkerShift(fraction: 0.5))
  #expect(options.symbolOrder == .snake)
  #expect(options.seed == 909)
  #expect(options.showsGridOverlay)
  #expect(options.subgrids.count == 1)
  #expect(options.subgrids[0].origin == .init(row: 1, column: 1))
  #expect(options.subgrids[0].span == .init(rows: 2, columns: 2))
  #expect(options.subgrids[0].symbols.isEmpty)
  #expect(options.subgrids[0].symbolOrder == .columnMajor)
  #expect(options.subgrids[0].seed == 123)
}

@Test func gridOptionsPreserveImportedSubgridIDsWhenAppendingInlineSymbols() async throws {
  let importedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B6")!
  let inlineID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B7")!
  let internalBase = PlacementModel.Grid(
    columnCount: 4,
    rowCount: 4,
    subgrids: [
      .init(
        at: .init(row: 0, column: 0),
        spanning: .init(rows: 2, columns: 2),
        symbolIDs: [importedID],
      ),
    ],
  )

  var options = TesseraPlacement.Grid(base: internalBase)
  options.subgrids[0].symbols.append(
    Symbol(id: inlineID, collider: .shape(.circle(center: .zero, radius: 1))) { Circle() },
  )

  let resolved = options.resolvedInternalGridOptions().options
  #expect(resolved.subgrids[0].symbolIDs == [importedID, inlineID])
}

@Test func gridOptionsPreserveImportedSubgridIDsWhenInlineSymbolsAreCleared() async throws {
  let importedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B8")!
  let internalBase = PlacementModel.Grid(
    columnCount: 4,
    rowCount: 4,
    subgrids: [
      .init(
        at: .init(row: 0, column: 0),
        spanning: .init(rows: 2, columns: 2),
        symbolIDs: [importedID],
      ),
    ],
  )

  var options = TesseraPlacement.Grid(base: internalBase)
  options.subgrids[0].symbols = []

  let resolved = options.resolvedInternalGridOptions().options
  #expect(resolved.subgrids[0].symbolIDs == [importedID])
}

@Test func patternOffsetMapsToLegacyPatternOffset() async throws {
  let symbol = Symbol(collider: .automatic(size: CGSize(width: 10, height: 10))) {
    Circle().frame(width: 10, height: 10)
  }

  var pattern = Pattern(symbols: [symbol], offset: CGSize(width: 12, height: -3))
  #expect(pattern.offset.width == 12)
  #expect(pattern.offset.height == -3)

  pattern.offset = CGSize(width: -1, height: 8)
  #expect(pattern.offset.width == -1)
  #expect(pattern.offset.height == 8)

  let legacy = pattern.legacyConfiguration
  #expect(legacy.patternOffset.width == -1)
  #expect(legacy.patternOffset.height == 8)
}

@Test func automaticColliderBuildsCircleCollisionShape() async throws {
  let approximateSize = CGSize(width: 30, height: 40)
  let symbol = Symbol(collider: .automatic(size: approximateSize)) {
    Rectangle().frame(width: approximateSize.width, height: approximateSize.height)
  }

  switch symbol.collisionShape {
  case let .circle(center, radius):
    #expect(center.x == 0)
    #expect(center.y == 0)
    #expect(abs(radius - hypot(approximateSize.width, approximateSize.height) / 2) < 0.0001)
  default:
    Issue.record("Expected automatic collider to resolve to a circle")
  }
}

@Test func symbolChoiceInitializerStoresStrategyAndChildren() async throws {
  let first = Symbol(collider: .automatic(size: CGSize(width: 8, height: 8))) {
    Circle().frame(width: 8, height: 8)
  }
  let second = Symbol(collider: .automatic(size: CGSize(width: 10, height: 10))) {
    Rectangle().frame(width: 10, height: 10)
  }
  let choice = Symbol(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
    weight: 2,
    choiceStrategy: .sequence,
    choiceSeed: 77,
    choices: [first, second],
  )

  #expect(choice.weight == 2)
  #expect(choice.choiceStrategy == .sequence)
  #expect(choice.choiceSeed == 77)
  #expect(choice.choices.count == 2)
  #expect(choice.renderableLeafSymbols.map(\.id) == [first.id, second.id])
}

@Test func symbolChoiceInitializerStoresIndexSequenceStrategy() async throws {
  let first = Symbol(collider: .automatic(size: CGSize(width: 8, height: 8))) {
    Circle().frame(width: 8, height: 8)
  }
  let second = Symbol(collider: .automatic(size: CGSize(width: 10, height: 10))) {
    Rectangle().frame(width: 10, height: 10)
  }
  let strategy: TesseraSymbolChoiceStrategy = .indexSequence([2, -1, 0])
  let choice = Symbol(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AB")!,
    choiceStrategy: strategy,
    choices: [first, second],
  )

  #expect(choice.choiceStrategy == strategy)
  #expect(choice.choices.map(\.id) == [first.id, second.id])
}

@Test @MainActor func canvasModeExportRequiresCanvasSize() async throws {
  let symbol = Symbol(collider: .automatic(size: CGSize(width: 12, height: 12))) {
    Circle().frame(width: 12, height: 12)
  }
  let pattern = Pattern(symbols: [symbol])
  let tessera = Tessera(pattern).mode(.canvas())
  let options = ExportOptions(
    directory: FileManager.default.temporaryDirectory,
    fileName: "tessera-v4-export-requires-size",
  )

  do {
    _ = try tessera.export(.png, options: options)
    Issue.record("Expected .missingCanvasSize export error")
  } catch let error as RenderError {
    switch error {
    case .missingCanvasSize:
      break
    default:
      Issue.record("Unexpected RenderError: \(error)")
    }
  } catch {
    Issue.record("Unexpected error: \(error)")
  }
}
