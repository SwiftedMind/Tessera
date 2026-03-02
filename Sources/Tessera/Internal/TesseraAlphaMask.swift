// By Dennis Müller

import CoreGraphics
import SwiftUI

struct TesseraAlphaMask: Sendable {
  var size: CGSize
  var pixelsWide: Int
  var pixelsHigh: Int
  var alphaBytes: [UInt8]
  var thresholdByte: UInt8
  var sampling: TesseraAlphaMaskRegion.Sampling
  var invert: Bool

  func contains(_ point: CGPoint) -> Bool {
    let pixelCount = expectedPixelCount
    guard size.width > 0, size.height > 0 else { return false }
    guard pixelCount > 0, alphaBytes.count >= pixelCount else { return false }

    let normalizedX = point.x / size.width
    let normalizedY = point.y / size.height

    if normalizedX < 0 || normalizedX > 1 || normalizedY < 0 || normalizedY > 1 {
      return false
    }

    let sample: UInt8 = switch sampling {
    case .nearest:
      {
        let x = min(max(Int(round(normalizedX * CGFloat(pixelsWide - 1))), 0), pixelsWide - 1)
        let y = min(max(Int(round(normalizedY * CGFloat(pixelsHigh - 1))), 0), pixelsHigh - 1)
        return alphaBytes[y * pixelsWide + x]
      }()
    case .bilinear:
      bilinearSample(normalizedX: normalizedX, normalizedY: normalizedY)
    }

    let visible = sample >= thresholdByte
    return invert ? !visible : visible
  }

  var filledFraction: Double {
    let pixelCount = expectedPixelCount
    guard pixelCount > 0, alphaBytes.count >= pixelCount else { return 0 }

    var count = 0
    for value in alphaBytes.prefix(pixelCount) where value >= thresholdByte {
      count += 1
    }

    let fraction = Double(count) / Double(pixelCount)
    return invert ? 1 - fraction : fraction
  }

  private func bilinearSample(normalizedX: CGFloat, normalizedY: CGFloat) -> UInt8 {
    let x = normalizedX * CGFloat(pixelsWide - 1)
    let y = normalizedY * CGFloat(pixelsHigh - 1)

    let x0 = min(max(Int(floor(x)), 0), pixelsWide - 1)
    let x1 = min(x0 + 1, pixelsWide - 1)
    let y0 = min(max(Int(floor(y)), 0), pixelsHigh - 1)
    let y1 = min(y0 + 1, pixelsHigh - 1)

    let tx = x - CGFloat(x0)
    let ty = y - CGFloat(y0)

    let a00 = Double(alphaBytes[y0 * pixelsWide + x0])
    let a10 = Double(alphaBytes[y0 * pixelsWide + x1])
    let a01 = Double(alphaBytes[y1 * pixelsWide + x0])
    let a11 = Double(alphaBytes[y1 * pixelsWide + x1])

    let a0 = a00 * (1 - Double(tx)) + a10 * Double(tx)
    let a1 = a01 * (1 - Double(tx)) + a11 * Double(tx)
    let a = a0 * (1 - Double(ty)) + a1 * Double(ty)

    return UInt8(max(0, min(255, Int(round(a)))))
  }

  var pixelScale: CGFloat {
    guard size.width > 0 else { return 1 }

    return CGFloat(pixelsWide) / size.width
  }

  func maskImage() -> CGImage? {
    guard pixelsWide > 0, pixelsHigh > 0 else { return nil }

    let pixelCount = expectedPixelCount
    guard pixelCount > 0, alphaBytes.count >= pixelCount else { return nil }

    let bytesPerPixel = 4
    let bytesPerRow = pixelsWide * bytesPerPixel
    var pixelBytes = [UInt8](repeating: 0, count: pixelsHigh * bytesPerRow)

    for index in 0..<pixelCount {
      let sample = alphaBytes[index]
      let visible = sample >= thresholdByte
      let masked = invert ? !visible : visible
      let alphaValue: UInt8 = masked ? 255 : 0

      let byteOffset = index * bytesPerPixel
      pixelBytes[byteOffset] = 255
      pixelBytes[byteOffset + 1] = 255
      pixelBytes[byteOffset + 2] = 255
      pixelBytes[byteOffset + 3] = alphaValue
    }

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

    let bitmapInfo = CGBitmapInfo.byteOrder32Big
      .union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
    guard let context = CGContext(
      data: &pixelBytes,
      width: pixelsWide,
      height: pixelsHigh,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: bitmapInfo.rawValue,
    ) else {
      return nil
    }

    return context.makeImage()
  }

  func maskView() -> AnyView? {
    guard let image = maskImage() else { return nil }

    let scale = max(pixelScale, 0.1)

    return AnyView(
      Image(decorative: image, scale: scale, orientation: .up)
        .interpolation(.none)
        .frame(width: size.width, height: size.height),
    )
  }

  private var expectedPixelCount: Int {
    guard pixelsWide > 0, pixelsHigh > 0 else { return 0 }

    return pixelsWide * pixelsHigh
  }
}

@MainActor
enum TesseraAlphaMaskRenderer {
  static func render(
    _ region: TesseraAlphaMaskRegion,
    canvasSize: CGSize,
  ) -> TesseraAlphaMask? {
    guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

    let pixelScale = max(region.pixelScale, 0.1)
    let pixelSize = CGSize(width: canvasSize.width * pixelScale, height: canvasSize.height * pixelScale)
    let pixelWidth = max(Int(pixelSize.width.rounded(.up)), 1)
    let pixelHeight = max(Int(pixelSize.height.rounded(.up)), 1)

    let renderer = ImageRenderer(content: region.renderView(in: canvasSize))
    renderer.proposedSize = ProposedViewSize(canvasSize)
    renderer.scale = pixelScale
    guard let cgImage = renderer.cgImage else { return nil }

    let alphaBytes = rasterize(cgImage, into: CGSize(width: pixelWidth, height: pixelHeight))
    guard alphaBytes.count == pixelWidth * pixelHeight else { return nil }

    let clampedThreshold = max(0, min(1, Double(region.alphaThreshold)))
    let thresholdByte = UInt8(clamping: Int((clampedThreshold * 255).rounded()))
    return TesseraAlphaMask(
      size: canvasSize,
      pixelsWide: pixelWidth,
      pixelsHigh: pixelHeight,
      alphaBytes: alphaBytes,
      thresholdByte: thresholdByte,
      sampling: region.sampling,
      invert: region.invert,
    )
  }

  private static func rasterize(_ image: CGImage, into pixelSize: CGSize) -> [UInt8] {
    let width = max(Int(pixelSize.width), 1)
    let height = max(Int(pixelSize.height), 1)

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixelBytes = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return [] }

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
      return []
    }

    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var alphaBytes: [UInt8] = []
    alphaBytes.reserveCapacity(width * height)

    for y in 0..<height {
      let rowStart = y * bytesPerRow
      for x in 0..<width {
        let index = rowStart + x * bytesPerPixel + 3
        alphaBytes.append(pixelBytes[index])
      }
    }

    return alphaBytes
  }
}
