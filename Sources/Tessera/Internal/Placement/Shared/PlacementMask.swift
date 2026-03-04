// By Dennis Müller

import CoreGraphics
import Foundation

/// Shared containment contract used by placement engines.
protocol PlacementMask: Sendable {
  func contains(_ point: CGPoint) -> Bool
  var filledFraction: Double { get }
  func filledBounds() -> CGRect?
}

/// Raster-backed placement mask that can expose raw samples for sparse sampling.
protocol DiscretePlacementMask: PlacementMask {
  var sampling: TesseraAlphaMaskRegion.Sampling { get }
  var thresholdByte: UInt8 { get }
  var invert: Bool { get }
  var rasterSize: CGSize { get }
  var rasterPixelsWide: Int { get }
  var rasterPixelsHigh: Int { get }
  var nearestAccessor: NearestMaskAccessor? { get }
  func forEachRasterSample(_ body: (_ fullIndex: Int, _ sample: UInt8) -> Void)
}

/// Precomputed nearest-neighbor mask sampler to avoid repeated normalization setup.
struct NearestMaskAccessor: Sendable {
  var canvasSize: CGSize
  var fullPixelsWide: Int
  var fullPixelsHigh: Int
  var sliceOriginX: Int
  var sliceOriginY: Int
  var slicePixelsWide: Int
  var slicePixelsHigh: Int
  var alphaBytes: [UInt8]
  var thresholdByte: UInt8
  var invert: Bool

  func contains(_ point: CGPoint) -> Bool {
    guard canvasSize.width > 0, canvasSize.height > 0 else { return false }
    guard fullPixelsWide > 0, fullPixelsHigh > 0 else { return false }
    guard point.x >= 0, point.x <= canvasSize.width, point.y >= 0, point.y <= canvasSize.height else {
      return false
    }

    let pixelX = min(
      max(Int(round(point.x / canvasSize.width * CGFloat(fullPixelsWide - 1))), 0),
      fullPixelsWide - 1,
    )
    let pixelY = min(
      max(Int(round(point.y / canvasSize.height * CGFloat(fullPixelsHigh - 1))), 0),
      fullPixelsHigh - 1,
    )

    let localX = pixelX - sliceOriginX
    let localY = pixelY - sliceOriginY
    guard (0..<slicePixelsWide).contains(localX), (0..<slicePixelsHigh).contains(localY) else {
      return false
    }

    let localIndex = localY * slicePixelsWide + localX
    guard (0..<alphaBytes.count).contains(localIndex) else { return false }

    let sample = alphaBytes[localIndex]
    let visible = sample >= thresholdByte
    return invert ? !visible : visible
  }
}

/// Sparse, local-window alpha mask over a full-canvas raster grid.
struct SliceAlphaMask: DiscretePlacementMask {
  var rasterSize: CGSize
  var rasterPixelsWide: Int
  var rasterPixelsHigh: Int
  var sliceOriginX: Int
  var sliceOriginY: Int
  var slicePixelsWide: Int
  var slicePixelsHigh: Int
  var alphaBytes: [UInt8]
  var thresholdByte: UInt8
  var sampling: TesseraAlphaMaskRegion.Sampling
  var invert: Bool
  var cachedFilledFraction: Double
  var cachedFilledBounds: CGRect?

  init(
    rasterSize: CGSize,
    rasterPixelsWide: Int,
    rasterPixelsHigh: Int,
    sliceOriginX: Int,
    sliceOriginY: Int,
    slicePixelsWide: Int,
    slicePixelsHigh: Int,
    alphaBytes: [UInt8],
    thresholdByte: UInt8 = 128,
    sampling: TesseraAlphaMaskRegion.Sampling = .nearest,
    invert: Bool = false,
  ) {
    self.rasterSize = rasterSize
    self.rasterPixelsWide = rasterPixelsWide
    self.rasterPixelsHigh = rasterPixelsHigh
    self.sliceOriginX = sliceOriginX
    self.sliceOriginY = sliceOriginY
    self.slicePixelsWide = slicePixelsWide
    self.slicePixelsHigh = slicePixelsHigh
    self.alphaBytes = alphaBytes
    self.thresholdByte = thresholdByte
    self.sampling = sampling
    self.invert = invert

    let totalPixelCount = max(rasterPixelsWide * rasterPixelsHigh, 1)
    var includedCount = 0
    var minLocalX = slicePixelsWide
    var minLocalY = slicePixelsHigh
    var maxLocalX = -1
    var maxLocalY = -1

    if slicePixelsWide > 0, slicePixelsHigh > 0 {
      for localY in 0..<slicePixelsHigh {
        let rowStart = localY * slicePixelsWide
        for localX in 0..<slicePixelsWide {
          let index = rowStart + localX
          guard index < alphaBytes.count else { continue }

          let sample = alphaBytes[index]
          let visible = sample >= thresholdByte
          let included = invert ? !visible : visible
          guard included else { continue }

          includedCount += 1
          minLocalX = min(minLocalX, localX)
          minLocalY = min(minLocalY, localY)
          maxLocalX = max(maxLocalX, localX)
          maxLocalY = max(maxLocalY, localY)
        }
      }
    }

    cachedFilledFraction = Double(includedCount) / Double(totalPixelCount)
    if maxLocalX >= minLocalX, maxLocalY >= minLocalY, rasterPixelsWide > 0, rasterPixelsHigh > 0 {
      let pixelWidthInPoints = rasterSize.width / CGFloat(rasterPixelsWide)
      let pixelHeightInPoints = rasterSize.height / CGFloat(rasterPixelsHigh)
      let bounds = CGRect(
        x: CGFloat(sliceOriginX + minLocalX) * pixelWidthInPoints,
        y: CGFloat(sliceOriginY + minLocalY) * pixelHeightInPoints,
        width: CGFloat(maxLocalX - minLocalX + 1) * pixelWidthInPoints,
        height: CGFloat(maxLocalY - minLocalY + 1) * pixelHeightInPoints,
      )
      let canvasBounds = CGRect(origin: .zero, size: rasterSize)
      let clampedBounds = bounds.intersection(canvasBounds)
      cachedFilledBounds = (clampedBounds.isNull || clampedBounds.isEmpty) ? nil : clampedBounds
    } else {
      cachedFilledBounds = nil
    }
  }

  var filledFraction: Double {
    cachedFilledFraction
  }

  func filledBounds() -> CGRect? {
    cachedFilledBounds
  }

  var nearestAccessor: NearestMaskAccessor? {
    guard sampling == .nearest else { return nil }

    return NearestMaskAccessor(
      canvasSize: rasterSize,
      fullPixelsWide: rasterPixelsWide,
      fullPixelsHigh: rasterPixelsHigh,
      sliceOriginX: sliceOriginX,
      sliceOriginY: sliceOriginY,
      slicePixelsWide: slicePixelsWide,
      slicePixelsHigh: slicePixelsHigh,
      alphaBytes: alphaBytes,
      thresholdByte: thresholdByte,
      invert: invert,
    )
  }

  func contains(_ point: CGPoint) -> Bool {
    if let nearestAccessor {
      return nearestAccessor.contains(point)
    }

    // The planner currently creates nearest-sampled slice masks only. Fallback is conservative.
    return false
  }

  func forEachRasterSample(_ body: (_ fullIndex: Int, _ sample: UInt8) -> Void) {
    guard slicePixelsWide > 0, slicePixelsHigh > 0, rasterPixelsWide > 0 else { return }
    guard rasterPixelsHigh > 0 else { return }

    let fullPixelCount = rasterPixelsWide * rasterPixelsHigh

    for localY in 0..<slicePixelsHigh {
      for localX in 0..<slicePixelsWide {
        let localIndex = localY * slicePixelsWide + localX
        guard localIndex < alphaBytes.count else { continue }

        let fullX = sliceOriginX + localX
        let fullY = sliceOriginY + localY
        guard (0..<rasterPixelsWide).contains(fullX), (0..<rasterPixelsHigh).contains(fullY) else {
          continue
        }

        let fullIndex = fullY * rasterPixelsWide + fullX
        guard (0..<fullPixelCount).contains(fullIndex) else { continue }

        body(fullIndex, alphaBytes[localIndex])
      }
    }
  }

  func makeDenseAlphaBytes() -> [UInt8] {
    let fullCount = max(rasterPixelsWide * rasterPixelsHigh, 0)
    guard fullCount > 0 else { return [] }

    var dense = [UInt8](repeating: 0, count: fullCount)
    guard slicePixelsWide > 0, slicePixelsHigh > 0, rasterPixelsWide > 0 else { return dense }

    for localY in 0..<slicePixelsHigh {
      let sourceRowStart = localY * slicePixelsWide
      let sourceRowEnd = sourceRowStart + slicePixelsWide
      guard sourceRowEnd <= alphaBytes.count else { break }

      let destinationRowStart = (sliceOriginY + localY) * rasterPixelsWide + sliceOriginX
      let destinationRowEnd = destinationRowStart + slicePixelsWide
      guard destinationRowStart >= 0, destinationRowEnd <= dense.count else { continue }

      dense[destinationRowStart..<destinationRowEnd] = alphaBytes[sourceRowStart..<sourceRowEnd]
    }
    return dense
  }

  var pixelScale: CGFloat {
    guard rasterSize.width > 0 else { return 1 }

    return CGFloat(rasterPixelsWide) / rasterSize.width
  }

  var sliceSizeInPoints: CGSize {
    guard rasterPixelsWide > 0, rasterPixelsHigh > 0 else { return .zero }

    let width = CGFloat(slicePixelsWide) / CGFloat(rasterPixelsWide) * rasterSize.width
    let height = CGFloat(slicePixelsHigh) / CGFloat(rasterPixelsHigh) * rasterSize.height
    return CGSize(width: width, height: height)
  }

  var sliceFrameInCanvas: CGRect {
    guard rasterPixelsWide > 0, rasterPixelsHigh > 0 else { return .zero }

    let originX = CGFloat(sliceOriginX) / CGFloat(rasterPixelsWide) * rasterSize.width
    let originY = CGFloat(sliceOriginY) / CGFloat(rasterPixelsHigh) * rasterSize.height
    let size = sliceSizeInPoints
    return CGRect(origin: CGPoint(x: originX, y: originY), size: size)
  }

  func sliceImage() -> CGImage? {
    guard slicePixelsWide > 0, slicePixelsHigh > 0 else { return nil }

    let pixelCount = slicePixelsWide * slicePixelsHigh
    guard pixelCount > 0, alphaBytes.count >= pixelCount else { return nil }

    let bytesPerRow = slicePixelsWide
    var pixelBytes = [UInt8](repeating: 0, count: pixelCount)
    for index in 0..<pixelCount {
      let sample = alphaBytes[index]
      let visible = sample >= thresholdByte
      let masked = invert ? !visible : visible
      pixelBytes[index] = masked ? 255 : 0
    }

    guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) else { return nil }

    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    guard let context = CGContext(
      data: &pixelBytes,
      width: slicePixelsWide,
      height: slicePixelsHigh,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: bitmapInfo.rawValue,
    ) else {
      return nil
    }

    return context.makeImage()
  }
}

enum PlacementMaskContainment {
  static func containsFunction(for mask: any PlacementMask) -> (CGPoint) -> Bool {
    if let discreteMask = mask as? any DiscretePlacementMask,
       let nearestAccessor = discreteMask.nearestAccessor {
      return nearestAccessor.contains
    }
    return mask.contains
  }
}
