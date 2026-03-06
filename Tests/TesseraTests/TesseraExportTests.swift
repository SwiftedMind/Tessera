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
