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
