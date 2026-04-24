// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test func `placement factory provides expected defaults`() {
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
  #expect(options.fillStrategy == .rejection)
  #expect(options.showsCollisionOverlay == false)
}

@Test func `renderable symbol initializer defaults Z index to zero`() {
  let symbol = Symbol(collider: .shape(.circle(center: .zero, radius: 1))) { Circle() }

  #expect(symbol.zIndex == 0)
}

@Test func `choice symbol initializer maps Z index`() {
  let symbol = TesseraSymbol(
    zIndex: 7,
    choiceStrategy: .sequence,
    choices: [
      TesseraSymbol(collisionShape: .circle(center: .zero, radius: 1)) { Circle() },
    ],
  )

  #expect(symbol.zIndex == 7)
}

@Test func `pinned symbol initializer defaults Z index to zero`() {
  let pinnedSymbol = PinnedSymbol(position: .centered(), collider: .shape(.circle(center: .zero, radius: 1))) {
    Circle()
  }

  #expect(pinnedSymbol.zIndex == 0)
}

@Test func `pinned symbol initializer maps Z index`() {
  let pinnedSymbol = PinnedSymbol(
    position: .centered(),
    zIndex: 7,
    collider: .shape(.circle(center: .zero, radius: 1)),
  ) {
    Circle()
  }

  #expect(pinnedSymbol.zIndex == 7)
}

@Test func `grid placement factory provides expected defaults`() {
  let placement = TesseraPlacement.grid(columns: 3, rows: 2)

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.sizing == .count(columns: 3, rows: 2))
  #expect(options.offsetStrategy == .none)
  #expect(options.symbolOrder == .rowMajor)
  #expect(options.symbolPhases.isEmpty)
  #expect(options.showsGridOverlay == false)
  #expect(options.subgrids.isEmpty)
  #expect(options.steering == .none)
}

@Test func `fixed grid placement factory maps sizing`() {
  let placement = TesseraPlacement.grid(
    cellSize: CGSize(width: 24, height: 18),
    origin: CGPoint(x: -6, y: 12),
  )

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.sizing == .fixed(
    cellSize: CGSize(width: 24, height: 18),
    origin: CGPoint(x: -6, y: 12),
  ))
}

@Test func `grid sizing square creates fixed square cells`() {
  #expect(
    TesseraPlacement.Grid.Sizing.square(20, origin: CGPoint(x: 3, y: -4)) ==
      .fixed(
        cellSize: CGSize(width: 20, height: 20),
        origin: CGPoint(x: 3, y: -4),
      ),
  )
}

@Test func `grid placement factory maps symbol phases`() {
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

@Test func `grid placement factory maps shows grid overlay`() {
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

@Test func `grid placement factory maps subgrids`() throws {
  let subgrids: [TesseraPlacement.Grid.Subgrid] = try [
    .init(
      at: .init(row: 1, column: 2),
      spanning: .init(rows: 2, columns: 3),
      symbols: [
        Symbol(
          id: #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B0")),
          collider: .shape(.circle(center: .zero, radius: 1)),
        ) { Circle() },
      ],
      symbolOrder: .columnMajor,
      seed: 777,
      clipsToBounds: true,
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
  #expect(options.subgrids[0].clipsToBounds)
}

@Test func `grid placement factory maps subgrid local grid`() throws {
  let symbolID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B8"))
  let subgrids: [TesseraPlacement.Grid.Subgrid] = [
    .init(
      at: .init(row: 1, column: 2),
      spanning: .init(rows: 2, columns: 3),
      symbols: [
        Symbol(id: symbolID, collider: .shape(.circle(center: .zero, radius: 1))) { Circle() },
      ],
      grid: .init(
        sizing: .count(columns: 10, rows: 10),
        offsetStrategy: .checkerShift(fraction: 0.15),
        symbolOrder: .shuffle,
        seed: 818,
      ),
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
  #expect(options.subgrids[0].grid?.sizing == .count(columns: 10, rows: 10))
  #expect(options.subgrids[0].grid?.offsetStrategy == .checkerShift(fraction: 0.15))
  #expect(options.subgrids[0].grid?.symbolOrder == .shuffle)
  #expect(options.subgrids[0].grid?.seed == 818)
}

@Test func `pattern initializer resolves inline subgrid symbols`() throws {
  let regularID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B1"))
  let subgridID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B2"))
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
  #expect(legacyOptions.subgrids[0].grid == nil)
}

@Test func `grid options can wrap internal base configuration`() throws {
  let subgridID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B5"))
  let internalBase = PlacementModel.Grid(
    sizing: .count(columns: 7, rows: 5),
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
        clipsToBounds: true,
      ),
    ],
  )
  let options = TesseraPlacement.Grid(base: internalBase)

  #expect(options.sizing == .count(columns: 7, rows: 5))
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
  #expect(options.subgrids[0].clipsToBounds)
  #expect(options.subgrids[0].grid == nil)
}

@Test func `grid options import internal subgrid local grid`() throws {
  let subgridID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B9"))
  let internalBase = PlacementModel.Grid(
    sizing: .count(columns: 7, rows: 5),
    subgrids: [
      .init(
        at: .init(row: 1, column: 1),
        spanning: .init(rows: 2, columns: 2),
        symbolIDs: [subgridID],
        grid: .init(
          sizing: .fixed(
            cellSize: CGSize(width: 24, height: 18),
            origin: CGPoint(x: -6, y: 10),
          ),
          offsetStrategy: .rowShift(fraction: 0.25),
          symbolOrder: .randomWeightedPerCell,
          seed: 321,
        ),
      ),
    ],
  )
  let options = TesseraPlacement.Grid(base: internalBase)

  #expect(options.subgrids.count == 1)
  #expect(options.subgrids[0].grid?.sizing == .fixed(
    cellSize: CGSize(width: 24, height: 18),
    origin: CGPoint(x: -6, y: 10),
  ))
  #expect(options.subgrids[0].grid?.offsetStrategy == .rowShift(fraction: 0.25))
  #expect(options.subgrids[0].grid?.symbolOrder == .randomWeightedPerCell)
  #expect(options.subgrids[0].grid?.seed == 321)
}

@Test func `resolved internal grid options preserve subgrid local grid`() throws {
  let symbolID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000BB"))
  let options = TesseraPlacement.Grid(
    sizing: .count(columns: 6, rows: 4),
    subgrids: [
      .init(
        at: .init(row: 1, column: 2),
        spanning: .init(rows: 2, columns: 2),
        symbols: [
          Symbol(id: symbolID, collider: .shape(.circle(center: .zero, radius: 1))) { Circle() },
        ],
        clipsToBounds: true,
        grid: .init(
          sizing: .count(columns: 5, rows: 5),
          offsetStrategy: .checkerShift(fraction: 0.1),
          symbolOrder: .shuffle,
          seed: 515,
        ),
      ),
    ],
  )

  let resolved = options.resolvedInternalGridOptions()

  #expect(resolved.subgridSymbols.map(\.id) == [symbolID])
  #expect(resolved.options.subgrids.count == 1)
  #expect(resolved.options.subgrids[0].clipsToBounds)
  #expect(resolved.options.subgrids[0].grid?.sizing == .count(columns: 5, rows: 5))
  #expect(resolved.options.subgrids[0].grid?.offsetStrategy == .checkerShift(fraction: 0.1))
  #expect(resolved.options.subgrids[0].grid?.symbolOrder == .shuffle)
  #expect(resolved.options.subgrids[0].grid?.seed == 515)
}

@Test func `subgrid equality ignores legacy seed and order when local grid exists`() throws {
  let symbolID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000C0"))
  let first = TesseraPlacement.Grid.Subgrid(
    at: .init(row: 1, column: 2),
    spanning: .init(rows: 2, columns: 2),
    symbols: [
      Symbol(id: symbolID, collider: .shape(.circle(center: .zero, radius: 1))) { Circle() },
    ],
    symbolOrder: .rowMajor,
    seed: 111,
    grid: .init(
      sizing: .count(columns: 4, rows: 4),
      symbolOrder: .shuffle,
    ),
  )
  let second = TesseraPlacement.Grid.Subgrid(
    at: .init(row: 1, column: 2),
    spanning: .init(rows: 2, columns: 2),
    symbols: [
      Symbol(id: symbolID, collider: .shape(.circle(center: .zero, radius: 1))) { Circle() },
    ],
    symbolOrder: .snake,
    seed: 999,
    grid: .init(
      sizing: .count(columns: 4, rows: 4),
      symbolOrder: .shuffle,
    ),
  )

  #expect(first == second)
  #expect(Set([first, second]).count == 1)
}

@Test func `grid options preserve imported subgrid identifiers when appending inline symbols`() throws {
  let importedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B6"))
  let inlineID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B7"))
  let internalBase = PlacementModel.Grid(
    sizing: .count(columns: 4, rows: 4),
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

@Test func `grid options preserve imported subgrid identifiers when inline symbols are cleared`() throws {
  let importedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B8"))
  let internalBase = PlacementModel.Grid(
    sizing: .count(columns: 4, rows: 4),
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

@Test func `pattern offset maps to legacy pattern offset`() {
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

@Test func `automatic collider builds circle collision shape`() {
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

@Test func `symbol choice initializer stores strategy and children`() throws {
  let first = Symbol(collider: .automatic(size: CGSize(width: 8, height: 8))) {
    Circle().frame(width: 8, height: 8)
  }
  let second = Symbol(collider: .automatic(size: CGSize(width: 10, height: 10))) {
    Rectangle().frame(width: 10, height: 10)
  }
  let choice = try Symbol(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")),
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

@Test func `symbol choice initializer stores index sequence strategy`() throws {
  let first = Symbol(collider: .automatic(size: CGSize(width: 8, height: 8))) {
    Circle().frame(width: 8, height: 8)
  }
  let second = Symbol(collider: .automatic(size: CGSize(width: 10, height: 10))) {
    Rectangle().frame(width: 10, height: 10)
  }
  let strategy: TesseraSymbolChoiceStrategy = .indexSequence([2, -1, 0])
  let choice = try Symbol(
    id: #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000AB")),
    choiceStrategy: strategy,
    choices: [first, second],
  )

  #expect(choice.choiceStrategy == strategy)
  #expect(choice.choices.map(\.id) == [first.id, second.id])
}

@Test @MainActor func `canvas mode export requires canvas size`() async throws {
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
    _ = try await tessera.export(.png, options: options)
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
