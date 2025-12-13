// By Dennis Müller

import CoreGraphics
import ImageIO
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
private func makeTestTile() -> TesseraTile {
  let item = TesseraItem(
    weight: 1,
    allowedRotationRange: .degrees(0)...(.degrees(0)),
    scaleRange: 1...1,
    collisionShape: .circle(radius: 10),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }

  let configuration = TesseraConfiguration(
    items: [item],
    seed: 1,
    minimumSpacing: 2,
    density: 1,
    baseScaleRange: 1...1,
    patternOffset: .zero,
    maximumItemCount: 64,
  )

  return TesseraTile(configuration, tileSize: CGSize(width: 128, height: 128))
}

@MainActor
private func makeTestCanvasWithCenteredFixedCircle(canvasSize: CGSize) -> TesseraCanvas {
  let configuration = TesseraConfiguration(
    items: [],
    seed: 1,
    minimumSpacing: 10,
    density: 0,
    baseScaleRange: 1...1,
    patternOffset: .zero,
    maximumItemCount: 0,
  )

  let fixedCircle = TesseraFixedItem(
    position: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
    rotation: .degrees(0),
    scale: 1,
    collisionShape: .circle(radius: 10),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }

  return TesseraCanvas(configuration, fixedItems: [fixedCircle], seed: 1, edgeBehavior: .finite)
}

private func cgImageFromPNGFile(at url: URL) throws -> CGImage {
  let data = try Data(contentsOf: url)
  let options: [CFString: Any] = [
    kCGImageSourceShouldCache: true,
    kCGImageSourceShouldCacheImmediately: true,
  ]

  guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
    throw CocoaError(.coderReadCorrupt)
  }
  guard let image = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
    throw CocoaError(.coderReadCorrupt)
  }

  return image
}

private func cgImageFromPDFFile(at url: URL) throws -> CGImage {
  guard let pdfDocument = CGPDFDocument(url as CFURL) else {
    throw CocoaError(.coderReadCorrupt)
  }
  guard let firstPage = pdfDocument.page(at: 1) else {
    throw CocoaError(.coderReadCorrupt)
  }

  let mediaBox = firstPage.getBoxRect(.mediaBox).integral
  let width = max(Int(mediaBox.width), 1)
  let height = max(Int(mediaBox.height), 1)

  let bytesPerPixel = 4
  let bytesPerRow = bytesPerPixel * width

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

  context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))

  context.saveGState()
  context.translateBy(x: 0, y: CGFloat(height))
  context.scaleBy(x: 1, y: -1)
  context.drawPDFPage(firstPage)
  context.restoreGState()

  guard let rasterizedImage = context.makeImage() else {
    throw CocoaError(.coderReadCorrupt)
  }

  return rasterizedImage
}

private struct PixelComponents: Sendable {
  var red: UInt8
  var green: UInt8
  var blue: UInt8
  var alpha: UInt8
}

private func pixelComponents(in cgImage: CGImage, x: Int, y: Int) throws -> PixelComponents {
  let width = max(cgImage.width, 1)
  let height = max(cgImage.height, 1)

  guard (0..<width).contains(x), (0..<height).contains(y) else {
    throw CocoaError(.coderReadCorrupt)
  }

  let bytesPerPixel = 4
  let bytesPerRow = bytesPerPixel * width

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

  context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

  let byteOffset = (y * bytesPerRow) + (x * bytesPerPixel)
  return PixelComponents(
    red: pixelBytes[byteOffset],
    green: pixelBytes[byteOffset + 1],
    blue: pixelBytes[byteOffset + 2],
    alpha: pixelBytes[byteOffset + 3],
  )
}

private func imageContainsVisiblePixels(_ cgImage: CGImage) -> Bool {
  let width = max(cgImage.width, 1)
  let height = max(cgImage.height, 1)

  let bytesPerPixel = 4
  let bytesPerRow = bytesPerPixel * width

  var pixelBytes = [UInt8](repeating: 0, count: height * bytesPerRow)

  guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    return false
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
    return false
  }

  context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

  for alphaByteIndex in stride(from: 3, to: pixelBytes.count, by: 4) {
    if pixelBytes[alphaByteIndex] != 0 {
      return true
    }
  }

  return false
}
