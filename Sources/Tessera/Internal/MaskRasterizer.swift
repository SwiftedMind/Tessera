// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Renders mosaic mask symbols into alpha masks and combines mask layers.
enum MaskRasterizer {
  /// Rasterizes one mosaic mask symbol into canvas-space alpha bytes.
  ///
  /// Rasterization is main-actor bound because it uses SwiftUI `ImageRenderer`.
  @MainActor
  static func rasterize(
    mosaicMask: MosaicMask,
    canvasSize: CGSize,
  ) throws -> TesseraAlphaMask {
    guard canvasSize.width > 0, canvasSize.height > 0 else {
      throw RenderError.invalidMosaicConfiguration
    }

    let pixelScale = max(mosaicMask.pixelScale, 0.1)
    let pixelSize = CGSize(width: canvasSize.width * pixelScale, height: canvasSize.height * pixelScale)
    let pixelWidth = max(Int(pixelSize.width.rounded(.up)), 1)
    let pixelHeight = max(Int(pixelSize.height.rounded(.up)), 1)
    let position = mosaicMask.position.resolvedPoint(in: canvasSize)

    let content = ZStack {
      mosaicMask.symbol.makeView()
        .rotationEffect(mosaicMask.rotation)
        .scaleEffect(mosaicMask.scale)
        .position(position)
    }
    .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)

    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(canvasSize)
    renderer.scale = pixelScale
    guard let cgImage = renderer.cgImage else {
      throw RenderError.invalidMosaicConfiguration
    }

    let alphaBytes = rasterize(cgImage, into: CGSize(width: pixelWidth, height: pixelHeight))
    guard alphaBytes.count == pixelWidth * pixelHeight else {
      throw RenderError.invalidMosaicConfiguration
    }

    let clampedThreshold = max(0, min(1, Double(mosaicMask.alphaThreshold)))
    let thresholdByte = UInt8(clamping: Int((clampedThreshold * 255).rounded()))

    return TesseraAlphaMask(
      size: canvasSize,
      pixelsWide: pixelWidth,
      pixelsHigh: pixelHeight,
      alphaBytes: alphaBytes,
      thresholdByte: thresholdByte,
      sampling: mosaicMask.sampling,
      invert: false,
    )
  }

  /// Removes previous mask coverage (declaration-order first-wins) from a raw mask.
  static func subtractingUnion(
    mask: TesseraAlphaMask,
    previousMasks: [TesseraAlphaMask],
    globalMask: TesseraAlphaMask?,
  ) -> TesseraAlphaMask {
    guard previousMasks.isEmpty == false || globalMask != nil else { return mask }

    let pixelCount = mask.pixelsWide * mask.pixelsHigh
    guard mask.alphaBytes.count >= pixelCount else {
      return TesseraAlphaMask(
        size: mask.size,
        pixelsWide: mask.pixelsWide,
        pixelsHigh: mask.pixelsHigh,
        alphaBytes: [UInt8](repeating: 0, count: max(pixelCount, 0)),
        thresholdByte: 128,
        sampling: .nearest,
        invert: false,
      )
    }

    let previousCoverage = combinedAlignedCoverage(for: previousMasks, matching: mask)
    let globalCoverage = globalMask.flatMap { alignedCoverage(for: $0, matching: mask) }
    var output = [UInt8](repeating: 0, count: pixelCount)
    for y in 0..<mask.pixelsHigh {
      for x in 0..<mask.pixelsWide {
        let index = y * mask.pixelsWide + x
        let rawVisible = mask.alphaBytes[index] >= mask.thresholdByte
        guard rawVisible else {
          output[index] = 0
          continue
        }

        if let previousCoverage, previousCoverage[index] != 0 {
          output[index] = 0
          continue
        }
        if let globalCoverage, globalCoverage[index] == 0 {
          output[index] = 0
          continue
        }
        let point = mask.canvasPoint(pixelX: x, pixelY: y)
        if previousCoverage == nil, previousMasks.contains(where: { $0.contains(point) }) {
          output[index] = 0
          continue
        }
        if globalCoverage == nil, let globalMask, globalMask.contains(point) == false {
          output[index] = 0
          continue
        }

        output[index] = 255
      }
    }

    return TesseraAlphaMask(
      size: mask.size,
      pixelsWide: mask.pixelsWide,
      pixelsHigh: mask.pixelsHigh,
      alphaBytes: output,
      thresholdByte: 128,
      sampling: .nearest,
      invert: false,
    )
  }

  /// Builds a union mask from all provided masks using the requested sampling scale.
  static func unionMask(
    masks: [TesseraAlphaMask],
    canvasSize: CGSize,
    pixelScale: CGFloat,
  ) -> TesseraAlphaMask? {
    guard masks.isEmpty == false else { return nil }

    let clampedScale = max(pixelScale, 0.1)
    let width = max(Int((canvasSize.width * clampedScale).rounded(.up)), 1)
    let height = max(Int((canvasSize.height * clampedScale).rounded(.up)), 1)
    if let firstMask = masks.first,
       let alignedCoverage = combinedAlignedCoverage(
         for: masks,
         matching: TesseraAlphaMask(
           size: canvasSize,
           pixelsWide: width,
           pixelsHigh: height,
           alphaBytes: [],
           thresholdByte: 0,
           sampling: .nearest,
           invert: false,
         ),
       ),
       firstMask.size == canvasSize {
      return TesseraAlphaMask(
        size: canvasSize,
        pixelsWide: width,
        pixelsHigh: height,
        alphaBytes: alignedCoverage,
        thresholdByte: 128,
        sampling: .nearest,
        invert: false,
      )
    }

    var bytes = [UInt8](repeating: 0, count: width * height)

    for y in 0..<height {
      for x in 0..<width {
        let index = y * width + x
        let point = CGPoint(
          x: (CGFloat(x) + 0.5) / CGFloat(width) * canvasSize.width,
          y: (CGFloat(y) + 0.5) / CGFloat(height) * canvasSize.height,
        )
        if masks.contains(where: { $0.contains(point) }) {
          bytes[index] = 255
        }
      }
    }

    return TesseraAlphaMask(
      size: canvasSize,
      pixelsWide: width,
      pixelsHigh: height,
      alphaBytes: bytes,
      thresholdByte: 128,
      sampling: .nearest,
      invert: false,
    )
  }

  /// Extracts alpha bytes from a rendered image.
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

  private static func alignedCoverage(
    for mask: TesseraAlphaMask,
    matching reference: TesseraAlphaMask,
  ) -> [UInt8]? {
    guard mask.size == reference.size else { return nil }
    guard mask.pixelsWide == reference.pixelsWide, mask.pixelsHigh == reference.pixelsHigh else { return nil }
    guard mask.sampling == .nearest else { return nil }

    let pixelCount = mask.pixelsWide * mask.pixelsHigh
    guard pixelCount > 0, mask.alphaBytes.count >= pixelCount else { return nil }

    var output = [UInt8](repeating: 0, count: pixelCount)
    for index in 0..<pixelCount {
      let sample = mask.alphaBytes[index]
      let visible = sample >= mask.thresholdByte
      let masked = mask.invert ? !visible : visible
      output[index] = masked ? 255 : 0
    }
    return output
  }

  private static func combinedAlignedCoverage(
    for masks: [TesseraAlphaMask],
    matching reference: TesseraAlphaMask,
  ) -> [UInt8]? {
    guard masks.isEmpty == false else { return nil }

    let pixelCount = reference.pixelsWide * reference.pixelsHigh
    guard pixelCount > 0 else { return nil }

    var combined = [UInt8](repeating: 0, count: pixelCount)
    for mask in masks {
      guard let coverage = alignedCoverage(for: mask, matching: reference) else { return nil }

      for index in 0..<pixelCount where coverage[index] != 0 {
        combined[index] = 255
      }
    }
    return combined
  }
}

private extension TesseraAlphaMask {
  func canvasPoint(pixelX: Int, pixelY: Int) -> CGPoint {
    CGPoint(
      x: (CGFloat(pixelX) + 0.5) / CGFloat(max(pixelsWide, 1)) * size.width,
      y: (CGFloat(pixelY) + 0.5) / CGFloat(max(pixelsHigh, 1)) * size.height,
    )
  }
}
