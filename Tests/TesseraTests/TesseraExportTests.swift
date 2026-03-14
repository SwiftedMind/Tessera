// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import Tessera
import Testing

@Test @MainActor func tilePNGExportContainsVisiblePixels() async throws {
  let tile = makeTestTile()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try await tile.export(
    .png,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  #expect(imageContainsVisiblePixels(cgImage))
}

@Test @MainActor func tilePDFExportContainsVisiblePixels() async throws {
  let tile = makeTestTile()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try await tile.export(
    .pdf,
    options: .init(
      directory: temporaryDirectory,
      fileName: fileName,
    ),
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPDFFile(at: exportedURL)
  #expect(imageContainsVisiblePixels(cgImage))
}

@Test @MainActor func canvasPNGExportUsesTransparentBackgroundByDefault() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let canvas = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPNG(to: temporaryDirectory, fileName: fileName, canvasSize: canvasSize)
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: 0, y: 0)
  #expect(cornerPixel.alpha == 0)
}

@Test @MainActor func canvasPNGExportRendersBackgroundColorWhenProvided() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let canvas = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let greenBackgroundURL = try canvas.renderPNG(
    to: temporaryDirectory,
    fileName: "\(fileName)-green",
    canvasSize: canvasSize,
    backgroundColor: .green,
  )
  defer { try? FileManager.default.removeItem(at: greenBackgroundURL) }

  let blueBackgroundURL = try canvas.renderPNG(
    to: temporaryDirectory,
    fileName: "\(fileName)-blue",
    canvasSize: canvasSize,
    backgroundColor: .blue,
  )
  defer { try? FileManager.default.removeItem(at: blueBackgroundURL) }

  let greenImage = try cgImageFromPNGFile(at: greenBackgroundURL)
  let greenCornerPixel = try pixelComponents(in: greenImage, x: 0, y: 0)
  #expect(greenCornerPixel.alpha > 200)

  let blueImage = try cgImageFromPNGFile(at: blueBackgroundURL)
  let blueCornerPixel = try pixelComponents(in: blueImage, x: 0, y: 0)
  #expect(blueCornerPixel.alpha > 200)

  let greenExcess = Int(greenCornerPixel.green) - Int(greenCornerPixel.blue)
  let blueExcess = Int(blueCornerPixel.green) - Int(blueCornerPixel.blue)
  #expect(greenExcess > 20)
  #expect(blueExcess < -20)
}

@Test @MainActor func canvasPNGExportRendersPinnedSymbolsAboveGeneratedSymbols() async throws {
  let canvasSize = CGSize(width: 128, height: 128)

  let generatedSymbol = TesseraSymbol(
    weight: 1,
    allowedRotationRange: .degrees(0)...(.degrees(0)),
    scaleRange: 1...1,
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 120, height: 120)),
  ) {
    Rectangle()
      .fill(Color.blue)
      .frame(width: 120, height: 120)
  }

  let configuration = TesseraConfiguration(
    symbols: [generatedSymbol],
    placement: .grid(
      PlacementModel.Grid(
        columnCount: 1,
        rowCount: 1,
      ),
    ),
  )

  let pinnedSymbol = TesseraPinnedSymbol(
    position: .centered(),
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 60, height: 60)),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: 60, height: 60)
  }

  let canvas = TesseraCanvas(
    configuration,
    pinnedSymbols: [pinnedSymbol],
    seed: 1,
    edgeBehavior: .finite,
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPNG(to: temporaryDirectory, fileName: fileName, canvasSize: canvasSize)
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 200)
  #expect(Int(centerPixel.red) - Int(centerPixel.green) > 100)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func canvasPNGExportHonorsZIndexAcrossGeneratedAndPinnedSymbols() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let generatedSymbol = makeColoredGeneratedSymbol(color: .blue, size: CGSize(width: 120, height: 120), zIndex: 5)
  let pinnedSymbol = makeColoredPinnedSymbol(color: .red, size: CGSize(width: 80, height: 80), zIndex: 3)
  let canvas = TesseraCanvas(
    TesseraConfiguration(
      symbols: [generatedSymbol],
      placement: .grid(PlacementModel.Grid(columnCount: 1, rowCount: 1)),
    ),
    pinnedSymbols: [pinnedSymbol],
    seed: 1,
    edgeBehavior: .finite,
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPNG(to: temporaryDirectory, fileName: fileName, canvasSize: canvasSize)
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.blue > 200)
  #expect(Int(centerPixel.blue) - Int(centerPixel.red) > 100)
}

@Test @MainActor func canvasPNGExportHonorsZIndexAcrossPinnedSymbols() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let backPinnedSymbol = makeColoredPinnedSymbol(color: .blue, size: CGSize(width: 80, height: 80), zIndex: 0)
  let frontPinnedSymbol = makeColoredPinnedSymbol(color: .red, size: CGSize(width: 60, height: 60), zIndex: 5)
  let canvas = makePinnedOnlyCanvas(pinnedSymbols: [frontPinnedSymbol, backPinnedSymbol])
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPNG(to: temporaryDirectory, fileName: fileName, canvasSize: canvasSize)
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 200)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func canvasPNGExportUsingPlacementSnapshotMatchesRegularExport() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let canvas = makeSingleSymbolGridCanvas()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let placedSymbolDescriptors = canvas.makeSynchronousPlacedDescriptors(for: canvasSize)
  let placementSnapshot = canvas.makePlacementSnapshot(
    canvasSize: canvasSize,
    placedSymbolDescriptors: placedSymbolDescriptors,
  )

  let baselineURL = try canvas.renderPNG(
    to: temporaryDirectory,
    fileName: "\(fileName)-baseline",
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: baselineURL) }

  let snapshotURL = try canvas.renderPNG(
    to: temporaryDirectory,
    fileName: "\(fileName)-snapshot",
    placementSnapshot: placementSnapshot,
  )
  defer { try? FileManager.default.removeItem(at: snapshotURL) }

  let baselineImage = try cgImageFromPNGFile(at: baselineURL)
  let snapshotImage = try cgImageFromPNGFile(at: snapshotURL)

  #expect(imagesArePixelEqual(baselineImage, snapshotImage))
}

@Test @MainActor func canvasPNGExportUsingPlacementSnapshotPreservesSnapshotOrder() async throws {
  let backID = UUID(uuidString: "00000000-0000-0000-0000-0000000000DB")!
  let frontID = UUID(uuidString: "00000000-0000-0000-0000-0000000000DC")!
  let canvasSize = CGSize(width: 128, height: 128)
  let canvas = TesseraCanvas(
    TesseraConfiguration(
      symbols: [
        TesseraSymbol(
          id: frontID,
          zIndex: 10,
          allowedRotationRange: .zero...(.zero),
          scaleRange: 1.0...1.0,
          collisionShape: .rectangle(center: .zero, size: CGSize(width: 100, height: 100)),
        ) {
          Rectangle()
            .fill(Color.red)
            .frame(width: 100, height: 100)
        },
        TesseraSymbol(
          id: backID,
          zIndex: 0,
          allowedRotationRange: .zero...(.zero),
          scaleRange: 1.0...1.0,
          collisionShape: .rectangle(center: .zero, size: CGSize(width: 100, height: 100)),
        ) {
          Rectangle()
            .fill(Color.blue)
            .frame(width: 100, height: 100)
        },
      ],
      placement: .grid(
        PlacementModel.Grid(
          columnCount: 1,
          rowCount: 1,
        ),
      ),
    ),
    seed: 1,
    edgeBehavior: .finite,
  )
  let placementSnapshot = TesseraCanvas.PlacementSnapshot(
    canvasSize: canvasSize,
    placedSymbols: [
      .init(
        symbolId: frontID,
        renderSymbolId: frontID,
        position: CGPoint(x: 64, y: 64),
        rotationRadians: 0,
        scale: 1,
      ),
      .init(
        symbolId: backID,
        renderSymbolId: backID,
        position: CGPoint(x: 64, y: 64),
        rotationRadians: 0,
        scale: 1,
      ),
    ],
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPNG(
    to: temporaryDirectory,
    fileName: fileName,
    placementSnapshot: placementSnapshot,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.blue > 200)
  #expect(Int(centerPixel.blue) - Int(centerPixel.red) > 100)
}

@Test @MainActor func snapshotPNGExportRendersCollisionOverlayForGeneratedSymbols() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let renderer = makeGeneratedCollisionOverlayRenderer()
  let snapshot = try await renderer.makeSnapshot(
    mode: .canvas(size: canvasSize, edgeBehavior: .finite),
    seed: .fixed(1),
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let baselineURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-baseline",
      render: .init(targetPixelSize: canvasSize),
    ),
  )
  defer { try? FileManager.default.removeItem(at: baselineURL) }

  let overlayURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-overlay",
      render: .init(
        targetPixelSize: canvasSize,
        showsCollisionOverlay: true,
      ),
    ),
  )
  defer { try? FileManager.default.removeItem(at: overlayURL) }

  let baselineImage = try cgImageFromPNGFile(at: baselineURL)
  let overlayImage = try cgImageFromPNGFile(at: overlayURL)
  let baselinePixel = try pixelComponents(
    in: baselineImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )
  let overlayPixel = try pixelComponents(
    in: overlayImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )

  #expect(baselinePixel.alpha == 0)
  #expect(overlayPixel.alpha > 0)
  #expect(overlayPixel.blue > overlayPixel.red)
  #expect(imagesArePixelEqual(baselineImage, overlayImage) == false)
}

@Test @MainActor func snapshotPNGExportRendersCollisionOverlayForPinnedSymbols() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let renderer = TesseraRenderer(
    Pattern(
      symbols: [],
      placement: .grid(columns: 1, rows: 1),
    ),
  )
  let snapshot = try await renderer.makeSnapshot(
    mode: .canvas(size: canvasSize, edgeBehavior: .finite),
    seed: .fixed(1),
    pinnedSymbols: [makeCollisionOverlayPinnedSymbol(at: CGPoint(x: 64, y: 64))],
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let baselineURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-baseline",
      render: .init(targetPixelSize: canvasSize),
    ),
  )
  defer { try? FileManager.default.removeItem(at: baselineURL) }

  let overlayURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-overlay",
      render: .init(
        targetPixelSize: canvasSize,
        showsCollisionOverlay: true,
      ),
    ),
  )
  defer { try? FileManager.default.removeItem(at: overlayURL) }

  let baselineImage = try cgImageFromPNGFile(at: baselineURL)
  let overlayImage = try cgImageFromPNGFile(at: overlayURL)
  let baselinePixel = try pixelComponents(
    in: baselineImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )
  let overlayPixel = try pixelComponents(
    in: overlayImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )

  #expect(baselinePixel.alpha == 0)
  #expect(overlayPixel.alpha > 0)
  #expect(overlayPixel.blue > overlayPixel.red)
}

@Test @MainActor func snapshotCollisionOverlayExportMatchesLegacyCanvasRender() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let pinnedSymbol = makeCollisionOverlayPinnedSymbol(at: CGPoint(x: 64, y: 64))
  let renderer = TesseraRenderer(
    Pattern(
      symbols: [],
      placement: .organic(
        minimumSpacing: 10,
        density: 0,
        maximumCount: 0,
      ),
    ),
  )
  let snapshot = try await renderer.makeSnapshot(
    mode: .canvas(size: canvasSize, edgeBehavior: .finite),
    seed: .fixed(1),
    pinnedSymbols: [pinnedSymbol],
  )
  let legacyCanvas = makePinnedCollisionOverlayCanvas(pinnedSymbol: pinnedSymbol)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let legacyURL = try legacyCanvas.renderPNG(
    to: temporaryDirectory,
    fileName: "\(fileName)-legacy",
    canvasSize: canvasSize,
    options: .init(
      targetPixelSize: canvasSize,
      showsCollisionOverlay: true,
    ),
  )
  defer { try? FileManager.default.removeItem(at: legacyURL) }

  let snapshotURL = try renderer.export(
    .png,
    snapshot: snapshot,
    options: .init(
      directory: temporaryDirectory,
      fileName: "\(fileName)-snapshot",
      render: .init(
        targetPixelSize: canvasSize,
        showsCollisionOverlay: true,
      ),
    ),
  )
  defer { try? FileManager.default.removeItem(at: snapshotURL) }

  let legacyImage = try cgImageFromPNGFile(at: legacyURL)
  let snapshotImage = try cgImageFromPNGFile(at: snapshotURL)
  let legacyOverlayPixel = try pixelComponents(
    in: legacyImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )
  let snapshotOverlayPixel = try pixelComponents(
    in: snapshotImage,
    x: collisionOverlaySamplePoint.x,
    y: collisionOverlaySamplePoint.y,
  )
  let legacyCenterPixel = try pixelComponents(in: legacyImage, x: 64, y: 64)
  let snapshotCenterPixel = try pixelComponents(in: snapshotImage, x: 64, y: 64)
  let legacyBackgroundPixel = try pixelComponents(in: legacyImage, x: 8, y: 8)
  let snapshotBackgroundPixel = try pixelComponents(in: snapshotImage, x: 8, y: 8)

  #expect(legacyOverlayPixel.alpha > 0)
  #expect(snapshotOverlayPixel.alpha > 0)
  #expect(legacyCenterPixel.red > legacyCenterPixel.blue)
  #expect(snapshotCenterPixel.red > snapshotCenterPixel.blue)
  #expect(legacyBackgroundPixel.alpha == 0)
  #expect(snapshotBackgroundPixel.alpha == 0)
}

@Test @MainActor func canvasPNGExportWithInvalidPlacementSnapshotThrowsError() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let canvas = makeSingleSymbolGridCanvas()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let placedSymbolDescriptors = canvas.makeSynchronousPlacedDescriptors(for: canvasSize)
  var invalidPlacementSnapshot = canvas.makePlacementSnapshot(
    canvasSize: canvasSize,
    placedSymbolDescriptors: placedSymbolDescriptors,
  )
  #expect(invalidPlacementSnapshot.placedSymbols.isEmpty == false)
  invalidPlacementSnapshot.placedSymbols[0].renderSymbolId = UUID()

  #expect(throws: RenderError.invalidPlacementSnapshot) {
    try canvas.renderPNG(
      to: temporaryDirectory,
      fileName: fileName,
      placementSnapshot: invalidPlacementSnapshot,
    )
  }
}

@Test @MainActor func canvasPlacementSnapshotCallbackEmitsComputedSnapshot() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  var callbackSnapshot: TesseraCanvas.PlacementSnapshot?

  let canvas = makeSingleSymbolGridCanvas().onPlacementSnapshotReady { snapshot in
    callbackSnapshot = snapshot
  }
  let expectedPlacedSymbolDescriptors = canvas.makeSynchronousPlacedDescriptors(
    for: canvasSize,
  )
  let expectedSnapshot = canvas.makePlacementSnapshot(
    canvasSize: canvasSize,
    placedSymbolDescriptors: expectedPlacedSymbolDescriptors,
  )

  #if canImport(UIKit)
  let hostView = canvas.frame(width: canvasSize.width, height: canvasSize.height)
  let hostingController = UIHostingController(rootView: hostView)
  let window = UIWindow(frame: CGRect(origin: .zero, size: canvasSize))
  window.rootViewController = hostingController
  window.makeKeyAndVisible()
  defer {
    window.isHidden = true
    window.rootViewController = nil
  }

  let timeoutDate = Date().addingTimeInterval(2)
  while callbackSnapshot == nil, Date() < timeoutDate {
    try await Task.sleep(nanoseconds: 10_000_000)
  }
  #else
  Issue.record("Callback emission test requires UIKit")
  #endif

  #expect(callbackSnapshot == expectedSnapshot)
}

@Test @MainActor func canvasPDFExportRendersPinnedSymbolsAboveGeneratedSymbols() async throws {
  let canvasSize = CGSize(width: 128, height: 128)

  let generatedSymbol = TesseraSymbol(
    weight: 1,
    allowedRotationRange: .degrees(0)...(.degrees(0)),
    scaleRange: 1...1,
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 120, height: 120)),
  ) {
    Rectangle()
      .fill(Color.blue)
      .frame(width: 120, height: 120)
  }

  let configuration = TesseraConfiguration(
    symbols: [generatedSymbol],
    placement: .grid(
      PlacementModel.Grid(
        columnCount: 1,
        rowCount: 1,
      ),
    ),
  )

  let pinnedSymbol = TesseraPinnedSymbol(
    position: .centered(),
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 60, height: 60)),
  ) {
    Rectangle()
      .fill(Color.red)
      .frame(width: 60, height: 60)
  }

  let canvas = TesseraCanvas(
    configuration,
    pinnedSymbols: [pinnedSymbol],
    seed: 1,
    edgeBehavior: .finite,
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPDF(
    to: temporaryDirectory,
    fileName: fileName,
    canvasSize: canvasSize,
    pageSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPDFFile(at: exportedURL)
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.red > 200)
  #expect(Int(centerPixel.red) - Int(centerPixel.green) > 100)
  #expect(Int(centerPixel.red) - Int(centerPixel.blue) > 100)
}

@Test @MainActor func canvasPDFExportHonorsZIndexAcrossGeneratedAndPinnedSymbols() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let generatedSymbol = makeColoredGeneratedSymbol(color: .blue, size: CGSize(width: 120, height: 120), zIndex: 5)
  let pinnedSymbol = makeColoredPinnedSymbol(color: .red, size: CGSize(width: 80, height: 80), zIndex: 3)
  let canvas = TesseraCanvas(
    TesseraConfiguration(
      symbols: [generatedSymbol],
      placement: .grid(PlacementModel.Grid(columnCount: 1, rowCount: 1)),
    ),
    pinnedSymbols: [pinnedSymbol],
    seed: 1,
    edgeBehavior: .finite,
  )
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPDF(
    to: temporaryDirectory,
    fileName: fileName,
    canvasSize: canvasSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPDFFile(at: exportedURL)
  let centerPixel = try pixelComponents(in: cgImage, x: cgImage.width / 2, y: cgImage.height / 2)

  #expect(centerPixel.alpha > 200)
  #expect(centerPixel.blue > 200)
  #expect(Int(centerPixel.blue) - Int(centerPixel.red) > 100)
}

@Test @MainActor func canvasPDFExportUsesTransparentBackgroundByDefault() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let pageSize = CGSize(width: 256, height: 256)
  let canvas = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try canvas.renderPDF(
    to: temporaryDirectory,
    fileName: fileName,
    canvasSize: canvasSize,
    pageSize: pageSize,
  )
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPDFFile(at: exportedURL)
  let cornerPixel = try pixelComponents(in: cgImage, x: 0, y: 0)
  #expect(cornerPixel.alpha == 0)
}

@Test @MainActor func canvasPDFExportRendersBackgroundColorWhenProvided() async throws {
  let canvasSize = CGSize(width: 128, height: 128)
  let pageSize = CGSize(width: 256, height: 256)
  let canvas = makeTestCanvasWithCenteredFixedCircle(canvasSize: canvasSize)
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let greenBackgroundURL = try canvas.renderPDF(
    to: temporaryDirectory,
    fileName: "\(fileName)-green",
    canvasSize: canvasSize,
    backgroundColor: .green,
    pageSize: pageSize,
  )
  defer { try? FileManager.default.removeItem(at: greenBackgroundURL) }

  let blueBackgroundURL = try canvas.renderPDF(
    to: temporaryDirectory,
    fileName: "\(fileName)-blue",
    canvasSize: canvasSize,
    backgroundColor: .blue,
    pageSize: pageSize,
  )
  defer { try? FileManager.default.removeItem(at: blueBackgroundURL) }

  let greenImage = try cgImageFromPDFFile(at: greenBackgroundURL)
  let greenCornerPixel = try pixelComponents(in: greenImage, x: 0, y: 0)
  #expect(greenCornerPixel.alpha > 200)

  let blueImage = try cgImageFromPDFFile(at: blueBackgroundURL)
  let blueCornerPixel = try pixelComponents(in: blueImage, x: 0, y: 0)
  #expect(blueCornerPixel.alpha > 200)

  let greenExcess = Int(greenCornerPixel.green) - Int(greenCornerPixel.blue)
  let blueExcess = Int(blueCornerPixel.green) - Int(blueCornerPixel.blue)
  #expect(greenExcess > 20)
  #expect(blueExcess < -20)
}

@MainActor
private func makeSingleSymbolGridCanvas() -> TesseraCanvas {
  let symbol = TesseraSymbol(
    weight: 1,
    allowedRotationRange: .degrees(0)...(.degrees(0)),
    scaleRange: 1...1,
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 64, height: 64)),
  ) {
    Rectangle()
      .fill(Color.blue)
      .frame(width: 64, height: 64)
  }

  let configuration = TesseraConfiguration(
    symbols: [symbol],
    placement: .grid(
      PlacementModel.Grid(
        columnCount: 1,
        rowCount: 1,
      ),
    ),
  )

  return TesseraCanvas(
    configuration,
    seed: 1,
    edgeBehavior: .finite,
  )
}

private let collisionOverlaySamplePoint = (x: 84, y: 64)

@MainActor
private func makeGeneratedCollisionOverlayRenderer() -> TesseraRenderer {
  let symbol = Symbol(
    weight: 1,
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.rectangle(center: .zero, size: CGSize(width: 60, height: 60))),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }

  return TesseraRenderer(
    Pattern(
      symbols: [symbol],
      placement: .grid(columns: 1, rows: 1),
    ),
  )
}

@MainActor
private func makeColoredGeneratedSymbol(
  color: Color,
  size: CGSize,
  zIndex: Double,
) -> TesseraSymbol {
  TesseraSymbol(
    zIndex: zIndex,
    allowedRotationRange: .degrees(0)...(.degrees(0)),
    scaleRange: 1...1,
    collisionShape: .rectangle(center: .zero, size: size),
  ) {
    Rectangle()
      .fill(color)
      .frame(width: size.width, height: size.height)
  }
}

@MainActor
private func makeColoredPinnedSymbol(
  color: Color,
  size: CGSize,
  zIndex: Double,
) -> TesseraPinnedSymbol {
  TesseraPinnedSymbol(
    position: .centered(),
    zIndex: zIndex,
    collisionShape: .rectangle(center: .zero, size: size),
  ) {
    Rectangle()
      .fill(color)
      .frame(width: size.width, height: size.height)
  }
}

@MainActor
private func makePinnedOnlyCanvas(pinnedSymbols: [TesseraPinnedSymbol]) -> TesseraCanvas {
  TesseraCanvas(
    TesseraConfiguration(
      symbols: [],
      placement: .organic(
        PlacementModel.Organic(
          seed: 1,
          minimumSpacing: 10,
          density: 0,
          baseScaleRange: 1...1,
          maximumSymbolCount: 0,
        ),
      ),
    ),
    pinnedSymbols: pinnedSymbols,
    seed: 1,
    edgeBehavior: .finite,
  )
}

@MainActor
private func makeCollisionOverlayPinnedSymbol(at position: CGPoint) -> TesseraPinnedSymbol {
  TesseraPinnedSymbol(
    position: position,
    rotation: .degrees(0),
    scale: 1,
    collisionShape: .rectangle(center: .zero, size: CGSize(width: 60, height: 60)),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }
}

@MainActor
private func makePinnedCollisionOverlayCanvas(pinnedSymbol: TesseraPinnedSymbol) -> TesseraCanvas {
  TesseraCanvas(
    TesseraConfiguration(
      symbols: [],
      placement: .organic(
        PlacementModel.Organic(
          seed: 1,
          minimumSpacing: 10,
          density: 0,
          baseScaleRange: 1...1,
          maximumSymbolCount: 0,
        ),
      ),
    ),
    pinnedSymbols: [pinnedSymbol],
    seed: 1,
    edgeBehavior: .finite,
  )
}
