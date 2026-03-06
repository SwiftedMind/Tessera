// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Primary region API alias for Tessera v4.
public typealias Region = TesseraCanvasRegion
/// Primary alpha-mask API alias for Tessera v4.
public typealias AlphaMask = TesseraAlphaMaskRegion
/// Primary region-rendering API alias for Tessera v4.
public typealias RegionRendering = TesseraRegionRendering
/// Primary edge-behavior API alias for Tessera v4.
public typealias EdgeBehavior = TesseraEdgeBehavior

public extension Region {
  /// Polygon/mask mapping configuration alias.
  typealias Mapping = TesseraPolygonMapping
  /// Polygon fit-mode alias.
  typealias FitMode = TesseraPolygonFitMode
}

public extension AlphaMask {
  /// Creates an alpha mask from a `CGImage` using v4 naming.
  ///
  /// - Parameters:
  ///   - cacheKey: Stable key used for mask caching.
  ///   - image: Source alpha image.
  ///   - mapping: How the mask maps into canvas coordinates.
  ///   - padding: Insets before mapping.
  ///   - pixelScale: Rasterization scale used for mask sampling.
  ///   - alphaThreshold: Inclusion threshold in `0...1`.
  ///   - sampling: Mask sampling strategy.
  ///   - invert: Invert inside/outside semantics.
  init(
    cacheKey: some Hashable & Sendable,
    image: CGImage,
    mapping: Region.Mapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
    pixelScale: CGFloat = 2,
    alphaThreshold: CGFloat = 0.5,
    sampling: Sampling = .nearest,
    invert: Bool = false,
  ) {
    self.init(
      cacheKey: TesseraRegionID(cacheKey),
      source: .cgImage(image),
      mapping: mapping,
      padding: padding,
      pixelScale: pixelScale,
      alphaThreshold: alphaThreshold,
      sampling: sampling,
      invert: invert,
    )
  }

  /// Creates an alpha mask from a SwiftUI view using v4 naming.
  init(
    cacheKey: some Hashable & Sendable,
    mapping: Region.Mapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
    pixelScale: CGFloat = 2,
    alphaThreshold: CGFloat = 0.5,
    sampling: Sampling = .nearest,
    invert: Bool = false,
    @ViewBuilder view: @escaping () -> some View,
  ) {
    self.init(
      cacheKey: TesseraRegionID(cacheKey),
      source: .view { AnyView(view()) },
      mapping: mapping,
      padding: padding,
      pixelScale: pixelScale,
      alphaThreshold: alphaThreshold,
      sampling: sampling,
      invert: invert,
    )
  }
}
