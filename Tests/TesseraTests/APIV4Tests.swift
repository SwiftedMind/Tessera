// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test func placementFactoryProvidesExpectedDefaults() async throws {
  let placement = Placement.organic()

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
  let placement = Placement.grid(columns: 3, rows: 2)

  guard case let .grid(options) = placement else {
    Issue.record("Expected grid placement")
    return
  }

  #expect(options.columnCount == 3)
  #expect(options.rowCount == 2)
  #expect(options.offsetStrategy == .none)
  #expect(options.symbolOrder == .sequence)
  #expect(options.symbolPhases.isEmpty)
  #expect(options.steering == .none)
}

@Test func gridPlacementFactoryMapsSymbolPhases() async throws {
  let symbolID = UUID()
  let phases: [UUID: Placement.GridOptions.SymbolPhase] = [
    symbolID: .init(x: 0.5, y: 0.25),
  ]
  let placement = Placement.grid(
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
