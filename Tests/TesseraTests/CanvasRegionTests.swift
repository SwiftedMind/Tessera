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
    configuration: PlacementModel.Grid(columnCount: 6, rowCount: 6),
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

  let placement = PlacementModel.Organic(
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

@Test @MainActor func gridPlacementRespectsAlphaMaskRegion() async throws {
  let canvasSize = CGSize(width: 200, height: 200)
  let maskImage = try makeCircularMaskImage(size: canvasSize)
  let region = TesseraCanvasRegion.alphaMask(
    cacheKey: "mask-grid",
    image: maskImage,
    pixelScale: 1,
    alphaThreshold: 0.5,
    sampling: .nearest,
  )
  let resolvedAlphaMask = region.resolvedAlphaMask(in: canvasSize)

  #expect(resolvedAlphaMask != nil)

  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
    collisionShape: .circle(center: .zero, radius: 4),
  )

  let placed = GridShapePlacementEngine.placeSymbolDescriptors(
    in: canvasSize,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: PlacementModel.Grid(columnCount: 6, rowCount: 6),
    region: nil,
    alphaMask: resolvedAlphaMask,
  )

  #expect(placed.isEmpty == false)

  for descriptor in placed {
    #expect(resolvedAlphaMask?.contains(descriptor.position) == true)
  }
}

@Test @MainActor func organicPlacementRespectsAlphaMaskRegion() async throws {
  let canvasSize = CGSize(width: 220, height: 220)
  let maskImage = try makeCircularMaskImage(size: canvasSize)
  let region = TesseraCanvasRegion.alphaMask(
    cacheKey: "mask-organic",
    image: maskImage,
    pixelScale: 1,
    alphaThreshold: 0.5,
    sampling: .nearest,
  )
  let resolvedAlphaMask = region.resolvedAlphaMask(in: canvasSize)

  #expect(resolvedAlphaMask != nil)

  let placement = PlacementModel.Organic(
    seed: 24,
    minimumSpacing: 4,
    density: 0.9,
    baseScaleRange: 1...1,
    maximumSymbolCount: 48,
  )

  let symbolDescriptor = makeSymbolDescriptor(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
    collisionShape: .circle(center: .zero, radius: 6),
  )

  var generator = SeededGenerator(seed: placement.seed)
  let placed = OrganicShapePlacementEngine.placeSymbolDescriptors(
    in: canvasSize,
    symbolDescriptors: [symbolDescriptor],
    pinnedSymbolDescriptors: [],
    edgeBehavior: .finite,
    configuration: placement,
    region: nil,
    alphaMask: resolvedAlphaMask,
    randomGenerator: &generator,
  )

  #expect(placed.isEmpty == false)

  for descriptor in placed {
    #expect(resolvedAlphaMask?.contains(descriptor.position) == true)
  }
}

@Test @MainActor func alphaMaskThresholdRoundsToNearestByte() async throws {
  let canvasSize = CGSize(width: 100, height: 100)
  let maskImage = try makeCircularMaskImage(size: canvasSize)
  let region = TesseraCanvasRegion.alphaMask(
    cacheKey: "mask-threshold",
    image: maskImage,
    pixelScale: 1,
    alphaThreshold: 0.5,
    sampling: .nearest,
  )
  let resolvedAlphaMask = region.resolvedAlphaMask(in: canvasSize)

  #expect(resolvedAlphaMask?.thresholdByte == 128)
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

  let pinnedSymbol = PinnedSymbol(
    position: .centered(),
    collider: .shape(.rectangle(center: .zero, size: canvasSize)),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: canvasSize.width, height: canvasSize.height)
  }

  let tessera = Tessera(
    Pattern(
      symbols: [],
      placement: .organic(
        minimumSpacing: 10,
        density: 0,
        maximumCount: 0,
      ),
    ),
  )
  .mode(.canvas(edgeBehavior: .finite))
  .seed(.fixed(1))
  .region(region)
  .pinnedSymbols([pinnedSymbol])

  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString
  let exportedURL = try await tessera.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
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

  let pinnedSymbol = PinnedSymbol(
    position: .centered(),
    collider: .shape(.rectangle(center: .zero, size: canvasSize)),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: canvasSize.width, height: canvasSize.height)
  }

  let tessera = Tessera(
    Pattern(
      symbols: [],
      placement: .organic(
        minimumSpacing: 10,
        density: 0,
        maximumCount: 0,
      ),
    ),
  )
  .mode(.canvas(edgeBehavior: .finite))
  .seed(.fixed(1))
  .region(region)
  .regionRendering(.unclipped)
  .pinnedSymbols([pinnedSymbol])

  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString
  let exportedURL = try await tessera.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: cgImage.width - 1, y: cgImage.height - 1)
  let interiorPixel = try pixelComponents(in: cgImage, x: 10, y: 10)

  #expect(cornerPixel.alpha > 0)
  #expect(interiorPixel.alpha > 0)
}

@Test @MainActor func canvasPNGExportClipsToAlphaMaskRegion() async throws {
  let canvasSize = CGSize(width: 120, height: 120)
  let maskImage = try makeCircularMaskImage(size: canvasSize)
  let region = TesseraCanvasRegion.alphaMask(
    cacheKey: "mask-export",
    image: maskImage,
    pixelScale: 1,
    alphaThreshold: 0.5,
    sampling: .nearest,
  )

  let pinnedSymbol = PinnedSymbol(
    position: .centered(),
    collider: .shape(.rectangle(center: .zero, size: canvasSize)),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: canvasSize.width, height: canvasSize.height)
  }

  let tessera = Tessera(
    Pattern(
      symbols: [],
      placement: .organic(
        minimumSpacing: 10,
        density: 0,
        maximumCount: 0,
      ),
    ),
  )
  .mode(.canvas(edgeBehavior: .finite))
  .seed(.fixed(1))
  .region(region)
  .pinnedSymbols([pinnedSymbol])

  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString
  let exportedURL = try await tessera.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: cgImage.width - 1, y: cgImage.height - 1)
  let interiorPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(cornerPixel.alpha == 0)
  #expect(interiorPixel.alpha > 0)
}

@Test @MainActor func canvasPNGExportUnclippedAlphaMaskRegionDoesNotClip() async throws {
  let canvasSize = CGSize(width: 120, height: 120)
  let maskImage = try makeCircularMaskImage(size: canvasSize)
  let region = TesseraCanvasRegion.alphaMask(
    cacheKey: "mask-unclipped",
    image: maskImage,
    pixelScale: 1,
    alphaThreshold: 0.5,
    sampling: .nearest,
  )

  let pinnedSymbol = PinnedSymbol(
    position: .centered(),
    collider: .shape(.rectangle(center: .zero, size: canvasSize)),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: canvasSize.width, height: canvasSize.height)
  }

  let tessera = Tessera(
    Pattern(
      symbols: [],
      placement: .organic(
        minimumSpacing: 10,
        density: 0,
        maximumCount: 0,
      ),
    ),
  )
  .mode(.canvas(edgeBehavior: .finite))
  .seed(.fixed(1))
  .region(region)
  .regionRendering(.unclipped)
  .pinnedSymbols([pinnedSymbol])

  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString
  let exportedURL = try await tessera.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: cgImage.width - 1, y: cgImage.height - 1)
  let interiorPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

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

private func makeCircularMaskImage(size: CGSize) throws -> CGImage {
  let width = max(Int(size.width), 1)
  let height = max(Int(size.height), 1)
  let bytesPerPixel = 4
  let bytesPerRow = width * bytesPerPixel

  var pixelBytes = [UInt8](repeating: 0, count: height * bytesPerRow)
  guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    throw CocoaError(.coderReadCorrupt)
  }

  let bitmapInfo = CGBitmapInfo.byteOrder32Big
    .union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
  guard let context = CGContext(
    data: &pixelBytes,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue,
  ) else {
    throw CocoaError(.coderReadCorrupt)
  }

  context.clear(CGRect(x: 0, y: 0, width: width, height: height))
  context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))

  let diameter = min(CGFloat(width), CGFloat(height)) * 0.7
  let circleRect = CGRect(
    x: (CGFloat(width) - diameter) / 2,
    y: (CGFloat(height) - diameter) / 2,
    width: diameter,
    height: diameter,
  )
  context.fillEllipse(in: circleRect)

  guard let image = context.makeImage() else {
    throw CocoaError(.coderReadCorrupt)
  }

  return image
}
