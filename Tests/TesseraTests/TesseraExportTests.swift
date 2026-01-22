// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI
@testable import Tessera
import Testing

@Test @MainActor func tilePNGExportContainsVisiblePixels() async throws {
  let tile = makeTestTile()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try tile.renderPNG(to: temporaryDirectory, fileName: fileName)
  defer { try? FileManager.default.removeItem(at: exportedURL) }

  let cgImage = try cgImageFromPNGFile(at: exportedURL)
  #expect(imageContainsVisiblePixels(cgImage))
}

@Test @MainActor func tilePDFExportContainsVisiblePixels() async throws {
  let tile = makeTestTile()
  let temporaryDirectory = FileManager.default.temporaryDirectory
  let fileName = UUID().uuidString

  let exportedURL = try tile.renderPDF(to: temporaryDirectory, fileName: fileName)
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
      TesseraPlacement.Grid(
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
      TesseraPlacement.Grid(
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
