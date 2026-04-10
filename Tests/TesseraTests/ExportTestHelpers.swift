// By Dennis Müller

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
@testable import Tessera

@MainActor
func makeTestTile() -> Tessera {
  let symbol = Symbol(
    weight: 1,
    rotation: .degrees(0)...(.degrees(0)),
    scale: 1...1,
    collider: .shape(.circle(center: .zero, radius: 10)),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }

  let pattern = Pattern(
    symbols: [symbol],
    placement: .organic(
      TesseraPlacement.Organic(
        seed: 1,
        minimumSpacing: 2,
        density: 1,
        baseScaleRange: 1...1,
        maximumSymbolCount: 64,
      ),
    ),
  )

  return Tessera(pattern)
    .mode(.tile(size: CGSize(width: 128, height: 128)))
    .seed(.fixed(1))
}

@MainActor
func makeTestCanvasWithCenteredFixedCircle(canvasSize: CGSize) -> Tessera {
  let fixedCircle = PinnedSymbol(
    position: PinnedPosition(CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)),
    rotation: .degrees(0),
    scale: 1,
    collider: .shape(.circle(center: .zero, radius: 10)),
  ) {
    Circle()
      .fill(Color.red)
      .frame(width: 20, height: 20)
  }

  return Tessera(
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
  .pinnedSymbols([fixedCircle])
}

func cgImageFromPNGFile(at url: URL) throws -> CGImage {
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

func cgImageFromPDFFile(at url: URL) throws -> CGImage {
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

struct PixelComponents {
  var red: UInt8
  var green: UInt8
  var blue: UInt8
  var alpha: UInt8
}

func pixelComponents(in cgImage: CGImage, x: Int, y: Int) throws -> PixelComponents {
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

func imageContainsVisiblePixels(_ cgImage: CGImage) -> Bool {
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

@MainActor
func renderedCGImage(
  from content: some View,
  size: CGSize,
  scale: CGFloat = 1,
) throws -> CGImage {
  let renderer = ImageRenderer(
    content: content.frame(width: size.width, height: size.height),
  )
  renderer.proposedSize = ProposedViewSize(size)
  renderer.scale = scale

  guard let cgImage = renderer.cgImage else {
    throw CocoaError(.coderReadCorrupt)
  }

  return cgImage
}

func imagesArePixelEqual(_ lhs: CGImage, _ rhs: CGImage) -> Bool {
  guard lhs.width == rhs.width, lhs.height == rhs.height else {
    return false
  }
  guard let lhsPixels = imagePixelData(lhs), let rhsPixels = imagePixelData(rhs) else {
    return false
  }

  return lhsPixels == rhsPixels
}

struct ImageDifferenceStats {
  var differingPixelCount: Int
  var maximumChannelDifference: UInt8
  var totalPixelCount: Int

  var differingPixelFraction: Double {
    guard totalPixelCount > 0 else { return 0 }

    return Double(differingPixelCount) / Double(totalPixelCount)
  }
}

func imageDifferenceStats(_ lhs: CGImage, _ rhs: CGImage) -> ImageDifferenceStats? {
  guard lhs.width == rhs.width, lhs.height == rhs.height else {
    return nil
  }
  guard let lhsPixels = imagePixelData(lhs), let rhsPixels = imagePixelData(rhs) else {
    return nil
  }

  var differingPixelCount = 0
  var maximumChannelDifference: UInt8 = 0

  for index in stride(from: 0, to: lhsPixels.count, by: 4) {
    let redDifference = abs(Int(lhsPixels[index]) - Int(rhsPixels[index]))
    let greenDifference = abs(Int(lhsPixels[index + 1]) - Int(rhsPixels[index + 1]))
    let blueDifference = abs(Int(lhsPixels[index + 2]) - Int(rhsPixels[index + 2]))
    let alphaDifference = abs(Int(lhsPixels[index + 3]) - Int(rhsPixels[index + 3]))
    let pixelMaximumDifference = UInt8(max(redDifference, greenDifference, blueDifference, alphaDifference))

    if pixelMaximumDifference > 0 {
      differingPixelCount += 1
      maximumChannelDifference = max(maximumChannelDifference, pixelMaximumDifference)
    }
  }

  return ImageDifferenceStats(
    differingPixelCount: differingPixelCount,
    maximumChannelDifference: maximumChannelDifference,
    totalPixelCount: lhs.width * lhs.height,
  )
}

private func imagePixelData(_ cgImage: CGImage) -> [UInt8]? {
  let width = max(cgImage.width, 1)
  let height = max(cgImage.height, 1)

  let bytesPerPixel = 4
  let bytesPerRow = bytesPerPixel * width

  var pixelBytes = [UInt8](repeating: 0, count: height * bytesPerRow)

  guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    return nil
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
    return nil
  }

  context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
  return pixelBytes
}
