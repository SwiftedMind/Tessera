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
  #expect(options.symbolOrder == .sequence)
  #expect(options.symbolPhases.isEmpty)
  #expect(options.showsGridOverlay == false)
  #expect(options.mergedCells.isEmpty)
  #expect(options.excludeMergedSymbolsFromRegularCells)
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

@Test func gridPlacementFactoryMapsMergedCells() async throws {
  let merges: [TesseraPlacement.Grid.CellMerge] = [
    .init(
      at: .init(row: 1, column: 2),
      spanning: .init(rows: 2, columns: 3),
      symbol: Symbol(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B0")!,
        collider: .shape(.circle(center: .zero, radius: 1)),
      ) { Circle() },
      symbolSizing: .fitMergedCell,
    ),
  ]
  let placement = TesseraPlacement.grid(
    columns: 6,
    rows: 4,
    mergedCells: merges,
  )

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.mergedCells == merges)
}

@Test func cellMergeSymbolOverrideProvidesExplicitModes() async throws {
  let existingID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!
  let inlineID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B4")!
  let inlineSymbol = Symbol(
    id: inlineID,
    collider: .shape(.circle(center: .zero, radius: 1)),
  ) { Circle() }

  var merge = TesseraPlacement.Grid.CellMerge(
    at: .init(row: 0, column: 1),
    spanning: .init(rows: 2, columns: 2),
    symbolOverride: .existing(existingID),
  )

  if case let .existing(id) = merge.symbolOverride {
    #expect(id == existingID)
  } else {
    Issue.record("Expected existing symbol override mode")
  }

  merge.symbol = inlineSymbol
  if case let .inline(symbol) = merge.symbolOverride {
    #expect(symbol.id == inlineID)
  } else {
    Issue.record("Expected inline symbol override mode")
  }

  let idBased = TesseraPlacement.Grid.CellMerge(
    at: .init(row: 0, column: 1),
    spanning: .init(rows: 2, columns: 2),
    symbolOverride: .existing(inlineID),
  )
  #expect(merge == idBased)
}

@Test func patternInitializerResolvesInlineMergedSymbolOverrides() async throws {
  let regularID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
  let mergedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
  let regularSymbol = Symbol(id: regularID, collider: .shape(.circle(center: .zero, radius: 1))) { Circle() }
  let mergedSymbol = Symbol(id: mergedID, collider: .shape(.circle(center: .zero, radius: 2))) { Circle() }

  let pattern = Pattern(
    symbols: [regularSymbol],
    placement: .grid(
      columns: 6,
      rows: 4,
      mergedCells: [
        .init(
          at: .init(row: 1, column: 2),
          spanning: .init(rows: 2, columns: 3),
          symbol: mergedSymbol,
          symbolSizing: .fitMergedCell,
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

  #expect(options.mergedCells.count == 1)
  #expect(options.mergedCells[0].origin == .init(row: 1, column: 2))
  #expect(options.mergedCells[0].span == .init(rows: 2, columns: 3))
  #expect(options.mergedCells[0].symbol?.id == mergedID)
  #expect(options.mergedCells[0].symbolSizing == .fitMergedCell)

  let legacy = pattern.legacyConfiguration
  #expect(Set(legacy.symbols.map(\.id)) == Set([regularID, mergedID]))

  guard case let .grid(legacyOptions) = legacy.placement else {
    Issue.record("Expected legacy grid placement")
    return
  }

  #expect(legacyOptions.mergedCells.count == 1)
  #expect(legacyOptions.mergedCells[0].symbolID == mergedID)
}

@Test func gridPlacementFactoryMapsExcludeMergedSymbolsFromRegularCells() async throws {
  let placement = TesseraPlacement.grid(
    columns: 4,
    rows: 3,
    excludeMergedSymbolsFromRegularCells: false,
  )

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.excludeMergedSymbolsFromRegularCells == false)
}

@Test func gridOptionsCanWrapInternalBaseConfiguration() async throws {
  let mergedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B5")!
  let internalBase = PlacementModel.Grid(
    columnCount: 7,
    rowCount: 5,
    offsetStrategy: .checkerShift(fraction: 0.5),
    symbolOrder: .snake,
    seed: 909,
    symbolPhases: [mergedID: .init(x: 0.25, y: 0.5)],
    steering: .none,
    showsGridOverlay: true,
    mergedCells: [
      .init(
        at: .init(row: 1, column: 1),
        spanning: .init(rows: 2, columns: 2),
        symbolID: mergedID,
      ),
    ],
    excludeMergedSymbolsFromRegularCells: false,
  )
  let options = TesseraPlacement.Grid(base: internalBase)

  #expect(options.columnCount == 7)
  #expect(options.rowCount == 5)
  #expect(options.offsetStrategy == .checkerShift(fraction: 0.5))
  #expect(options.symbolOrder == .snake)
  #expect(options.seed == 909)
  #expect(options.showsGridOverlay)
  #expect(options.excludeMergedSymbolsFromRegularCells == false)
  #expect(options.mergedCells.count == 1)
  if case let .existing(symbolID) = options.mergedCells[0].symbolOverride {
    #expect(symbolID == mergedID)
  } else {
    Issue.record("Expected existing symbol override mode")
  }
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
