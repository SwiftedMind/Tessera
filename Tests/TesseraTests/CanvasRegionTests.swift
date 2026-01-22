// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test func gridPlacementRespectsPolygonRegion() async throws {
  let canvasSize = CGSize(width: 200, height: 200)
  let region = TesseraCanvasRegion.polygon([
    CGPoint(x: 0, y: 0),
    CGPoint(x: 180, y: 10),
    CGPoint(x: 160, y: 180),
    CGPoint(x: 10, y: 160),
  ])
  let resolvedRegion = region.resolvedPolygon(in: canvasSize)

  #expect(resolvedRegion != nil)

  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
    collisionShape: .circle(center: .zero, radius: 4),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: canvasSize,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: TesseraPlacement.Grid(columnCount: 6, rowCount: 6),
    region: resolvedRegion,
  )

  #expect(placed.isEmpty == false)

  for descriptor in placed {
    #expect(resolvedRegion?.contains(descriptor.position) == true)
  }
}

@Test func organicPlacementRespectsPolygonRegion() async throws {
  let canvasSize = CGSize(width: 220, height: 220)
  let region = TesseraCanvasRegion.polygon([
    CGPoint(x: 0, y: 0),
    CGPoint(x: 200, y: 40),
    CGPoint(x: 180, y: 200),
    CGPoint(x: 40, y: 180),
  ])
  let resolvedRegion = region.resolvedPolygon(in: canvasSize)

  #expect(resolvedRegion != nil)

  let placement = TesseraPlacement.Organic(
    seed: 42,
    minimumSpacing: 4,
    density: 0.9,
    baseScaleRange: 1...1,
    maximumSymbolCount: 48,
  )

  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
    collisionShape: .circle(center: .zero, radius: 6),
  )

  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: canvasSize,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    region: resolvedRegion,
    randomGenerator: &generator,
  )

  #expect(placed.isEmpty == false)

  for descriptor in placed {
    #expect(resolvedRegion?.contains(descriptor.position) == true)
  }
}

@Test func polygonRegionFromCGPathFlattensCurves() async throws {
  let canvasSize = CGSize(width: 220, height: 220)
  let ellipsePath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 120, height: 80), transform: nil)

  let region = TesseraCanvasRegion.polygon(ellipsePath, flatness: 2)
  let resolvedRegion = region.resolvedPolygon(in: canvasSize)

  #expect(resolvedRegion != nil)
  #expect(resolvedRegion?.points.count ?? 0 > 12)
  #expect((resolvedRegion?.area ?? 0) > 0)
}

@Test @MainActor func canvasPNGExportClipsToPolygonRegion() async throws {
  let canvasSize = CGSize(width: 120, height: 120)
  let region = TesseraCanvasRegion.polygon(
    [
      CGPoint(x: 0, y: 0),
      CGPoint(x: canvasSize.width, y: 0),
      CGPoint(x: 0, y: canvasSize.height),
    ],
    mapping: .canvasCoordinates,
  )

  let configuration = TesseraConfiguration(
    symbols: [],
    placement: .organic(
      TesseraPlacement.Organic(
        seed: 1,
        minimumSpacing: 10,
        density: 0,
        baseScaleRange: 1...1,
        maximumSymbolCount: 0,
      ),
    ),
  )

  let pinnedSymbol = TesseraPinnedSymbol(
    position: .centered(),
    collisionShape: .rectangle(center: .zero, size: canvasSize),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: canvasSize.width, height: canvasSize.height)
  }

  let canvas = TesseraCanvas(
    configuration,
    pinnedSymbols: [pinnedSymbol],
    seed: 1,
    edgeBehavior: .finite,
    region: region,
  )

  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPNG(
    to: temporaryDirectory,
    fileName: fileName,
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: cgImage.width - 1, y: cgImage.height - 1)
  let interiorPixel = try pixelComponents(in: cgImage, x: 10, y: 10)

  #expect(cornerPixel.alpha == 0)
  #expect(interiorPixel.alpha > 0)
}

@Test @MainActor func canvasPNGExportUnclippedPolygonRegionDoesNotClip() async throws {
  let canvasSize = CGSize(width: 120, height: 120)
  let region = TesseraCanvasRegion.polygon(
    [
      CGPoint(x: 0, y: 0),
      CGPoint(x: canvasSize.width, y: 0),
      CGPoint(x: 0, y: canvasSize.height),
    ],
    mapping: .canvasCoordinates,
  )

  let configuration = TesseraConfiguration(
    symbols: [],
    placement: .organic(
      TesseraPlacement.Organic(
        seed: 1,
        minimumSpacing: 10,
        density: 0,
        baseScaleRange: 1...1,
        maximumSymbolCount: 0,
      ),
    ),
  )

  let pinnedSymbol = TesseraPinnedSymbol(
    position: .centered(),
    collisionShape: .rectangle(center: .zero, size: canvasSize),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: canvasSize.width, height: canvasSize.height)
  }

  let canvas = TesseraCanvas(
    configuration,
    pinnedSymbols: [pinnedSymbol],
    seed: 1,
    edgeBehavior: .finite,
    region: region,
    regionRendering: .unclipped,
  )

  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPNG(
    to: temporaryDirectory,
    fileName: fileName,
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: cgImage.width - 1, y: cgImage.height - 1)
  let interiorPixel = try pixelComponents(in: cgImage, x: 10, y: 10)

  #expect(cornerPixel.alpha > 0)
  #expect(interiorPixel.alpha > 0)
}

private func makeSymbolDescriptor(
  id: UUID,
  collisionShape: CollisionShape,
) -> ShapePlacementEngine.PlacementSymbolDescriptor {
  ShapePlacementEngine.PlacementSymbolDescriptor(
    id: id,
    weight: 1,
    allowedRotationRangeDegrees: 0...0,
    resolvedScaleRange: 1...1,
    collisionShape: collisionShape,
  )
}
