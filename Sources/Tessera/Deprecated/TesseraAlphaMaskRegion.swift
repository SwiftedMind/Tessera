// By Dennis Müller

import CoreGraphics
import SwiftUI

public extension TesseraCanvasRegion {
  /// Creates an alpha mask region from a SwiftUI view.
  ///
  /// - Parameters:
  ///   - cacheKey: Stable identifier for caching the rendered alpha mask. Update this value when the mask content
  ///     changes.
  ///   - pixelScale: Rasterization scale for the alpha mask.
  ///   - alphaThreshold: Alpha threshold (0...1) used to determine inclusion.
  ///   - sampling: Sampling strategy used when querying the mask.
  ///   - invert: When true, inverts the mask (alpha below threshold is treated as inside).
  ///   - mapping: Mapping strategy that fits the mask into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  ///   - content: View builder producing the alpha mask.
  static func alphaMask(
    cacheKey: TesseraRegionID,
    pixelScale: CGFloat = 2,
    alphaThreshold: CGFloat = 0.5,
    sampling: TesseraAlphaMaskRegion.Sampling = .nearest,
    invert: Bool = false,
    mapping: TesseraPolygonMapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
    @ViewBuilder content: @escaping () -> some View,
  ) -> TesseraCanvasRegion {
    .alphaMask(
      TesseraAlphaMaskRegion(
        cacheKey: cacheKey,
        source: .view { AnyView(content()) },
        mapping: mapping,
        padding: padding,
        pixelScale: pixelScale,
        alphaThreshold: alphaThreshold,
        sampling: sampling,
        invert: invert,
      ),
    )
  }

  /// Creates an alpha mask region from a `CGImage`.
  ///
  /// - Parameters:
  ///   - cacheKey: Stable identifier for caching the rendered alpha mask. Update this value when the mask content
  ///     changes.
  ///   - image: Source image used as alpha mask.
  ///   - pixelScale: Rasterization scale for the alpha mask.
  ///   - alphaThreshold: Alpha threshold (0...1) used to determine inclusion.
  ///   - sampling: Sampling strategy used when querying the mask.
  ///   - invert: When true, inverts the mask (alpha below threshold is treated as inside).
  ///   - mapping: Mapping strategy that fits the mask into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  static func alphaMask(
    cacheKey: TesseraRegionID,
    image: CGImage,
    pixelScale: CGFloat = 2,
    alphaThreshold: CGFloat = 0.5,
    sampling: TesseraAlphaMaskRegion.Sampling = .nearest,
    invert: Bool = false,
    mapping: TesseraPolygonMapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
  ) -> TesseraCanvasRegion {
    .alphaMask(
      TesseraAlphaMaskRegion(
        cacheKey: cacheKey,
        source: .cgImage(image),
        mapping: mapping,
        padding: padding,
        pixelScale: pixelScale,
        alphaThreshold: alphaThreshold,
        sampling: sampling,
        invert: invert,
      ),
    )
  }

  /// Creates an alpha mask region from a SwiftUI view.
  ///
  /// - Parameters:
  ///   - id: Stable identifier for caching the rendered alpha mask. Update this value when the mask content changes.
  ///   - pixelScale: Rasterization scale for the alpha mask.
  ///   - alphaThreshold: Alpha threshold (0...1) used to determine inclusion.
  ///   - sampling: Sampling strategy used when querying the mask.
  ///   - invert: When true, inverts the mask (alpha below threshold is treated as inside).
  ///   - mapping: Mapping strategy that fits the mask into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  ///   - content: View builder producing the alpha mask.
  @available(
    *,
    deprecated,
    renamed: "alphaMask(cacheKey:pixelScale:alphaThreshold:sampling:invert:mapping:padding:content:)"
  )
  static func alphaMask(
    id: TesseraRegionID,
    pixelScale: CGFloat = 2,
    alphaThreshold: CGFloat = 0.5,
    sampling: TesseraAlphaMaskRegion.Sampling = .nearest,
    invert: Bool = false,
    mapping: TesseraPolygonMapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
    @ViewBuilder content: @escaping () -> some View,
  ) -> TesseraCanvasRegion {
    alphaMask(
      cacheKey: id,
      pixelScale: pixelScale,
      alphaThreshold: alphaThreshold,
      sampling: sampling,
      invert: invert,
      mapping: mapping,
      padding: padding,
      content: content,
    )
  }

  /// Creates an alpha mask region from a `CGImage`.
  ///
  /// - Parameters:
  ///   - id: Stable identifier for caching the rendered alpha mask. Update this value when the mask content changes.
  ///   - image: Source image used as alpha mask.
  ///   - pixelScale: Rasterization scale for the alpha mask.
  ///   - alphaThreshold: Alpha threshold (0...1) used to determine inclusion.
  ///   - sampling: Sampling strategy used when querying the mask.
  ///   - invert: When true, inverts the mask (alpha below threshold is treated as inside).
  ///   - mapping: Mapping strategy that fits the mask into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  @available(
    *,
    deprecated,
    renamed: "alphaMask(cacheKey:image:pixelScale:alphaThreshold:sampling:invert:mapping:padding:)"
  )
  static func alphaMask(
    id: TesseraRegionID,
    image: CGImage,
    pixelScale: CGFloat = 2,
    alphaThreshold: CGFloat = 0.5,
    sampling: TesseraAlphaMaskRegion.Sampling = .nearest,
    invert: Bool = false,
    mapping: TesseraPolygonMapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
  ) -> TesseraCanvasRegion {
    alphaMask(
      cacheKey: id,
      image: image,
      pixelScale: pixelScale,
      alphaThreshold: alphaThreshold,
      sampling: sampling,
      invert: invert,
      mapping: mapping,
      padding: padding,
    )
  }
}

/// An alpha mask used to constrain symbol placement.
///
/// The mask is mapped into the resolved canvas size using `mapping` and `padding`, mirroring polygon mapping.
public struct TesseraAlphaMaskRegion: Hashable, Sendable {
  /// Sampling strategy used when querying the mask.
  public enum Sampling: Sendable, Hashable {
    /// Samples the nearest mask pixel.
    case nearest
    /// Samples the mask using bilinear interpolation.
    case bilinear
  }

  /// Source content that defines the alpha mask.
  public enum Source: Hashable, @unchecked Sendable {
    /// Uses the alpha channel of a `CGImage`.
    case cgImage(CGImage)
    /// Uses the alpha channel of a SwiftUI view.
    ///
    /// The view builder is not considered for equality; update `cacheKey` to invalidate cached masks.
    case view(() -> AnyView)

    /// Compares source identity for caching/equality behavior.
    ///
    /// For `.view`, equality is structural by case only. Update `cacheKey` when view content changes.
    public static func == (lhs: Source, rhs: Source) -> Bool {
      switch (lhs, rhs) {
      case let (.cgImage(lhsImage), .cgImage(rhsImage)):
        lhsImage === rhsImage
      case (.view, .view):
        true
      default:
        false
      }
    }

    /// Hashes source identity for mask caching.
    ///
    /// For `.view`, hashing is case-based and intentionally ignores closure identity.
    public func hash(into hasher: inout Hasher) {
      switch self {
      case let .cgImage(image):
        hasher.combine(ObjectIdentifier(image))
      case .view:
        hasher.combine(0)
      }
    }
  }

  /// Stable identifier for caching the rendered alpha mask.
  public var cacheKey: TesseraRegionID
  /// Source content used to build the alpha mask.
  public var source: Source
  /// Mapping strategy that fits the mask into the resolved canvas size.
  public var mapping: TesseraPolygonMapping
  /// Inset applied to the canvas bounds before mapping.
  public var padding: CGFloat
  /// Rasterization scale for the alpha mask.
  public var pixelScale: CGFloat
  /// Alpha threshold (0...1) used to determine inclusion.
  public var alphaThreshold: CGFloat
  /// Sampling strategy used when querying the mask.
  public var sampling: Sampling
  /// When true, inverts the mask (alpha below threshold is treated as inside).
  public var invert: Bool

  /// Creates an alpha mask region from a view or image source.
  ///
  /// - Parameters:
  ///   - cacheKey: Stable identifier for caching the rendered alpha mask. Update this value when the mask content
  ///     changes.
  ///   - source: The view or image used as the alpha mask.
  ///   - mapping: Mapping strategy that fits the mask into the resolved canvas size.
  ///   - padding: Inset applied to the canvas bounds before mapping.
  ///   - pixelScale: Rasterization scale for the alpha mask.
  ///   - alphaThreshold: Alpha threshold (0...1) used to determine inclusion.
  ///   - sampling: Sampling strategy used when querying the mask.
  ///   - invert: When true, inverts the mask (alpha below threshold is treated as inside).
  public init(
    cacheKey: TesseraRegionID,
    source: Source,
    mapping: TesseraPolygonMapping = .fit(mode: .aspectFit, alignment: .center),
    padding: CGFloat = 0,
    pixelScale: CGFloat = 2,
    alphaThreshold: CGFloat = 0.5,
    sampling: Sampling = .nearest,
    invert: Bool = false,
  ) {
    self.cacheKey = cacheKey
    self.source = source
    self.mapping = mapping
    self.padding = padding
    self.pixelScale = pixelScale
    self.alphaThreshold = alphaThreshold
    self.sampling = sampling
    self.invert = invert
  }

  func renderView(in canvasSize: CGSize) -> AnyView {
    let clampedPadding = max(padding, 0)
    let paddedSize = CGSize(
      width: max(canvasSize.width - clampedPadding * 2, 0),
      height: max(canvasSize.height - clampedPadding * 2, 0),
    )

    switch source {
    case let .cgImage(image):
      return mappedImageView(
        image,
        canvasSize: canvasSize,
        paddedSize: paddedSize,
        padding: clampedPadding,
      )
    case let .view(builder):
      let content = builder()
      return mappedView(
        content,
        canvasSize: canvasSize,
        paddedSize: paddedSize,
        padding: clampedPadding,
      )
    }
  }

  private func mappedView(
    _ content: AnyView,
    canvasSize: CGSize,
    paddedSize: CGSize,
    padding: CGFloat,
  ) -> AnyView {
    switch mapping {
    case .canvasCoordinates:
      let framed = content
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
      guard padding > 0 else { return AnyView(framed) }

      return AnyView(framed.offset(x: padding, y: padding))
    case let .fit(mode, alignment):
      let resolvedAlignment = Alignment(
        horizontal: alignment.horizontalAlignment,
        vertical: alignment.verticalAlignment,
      )
      let mapped = switch mode {
      case .aspectFit:
        AnyView(content.aspectRatio(contentMode: .fit))
      case .aspectFill:
        AnyView(content.aspectRatio(contentMode: .fill))
      case .stretch:
        AnyView(content)
      }
      let framed = mapped.frame(width: paddedSize.width, height: paddedSize.height)
      let clipped = mode == .aspectFill ? AnyView(framed.clipped()) : AnyView(framed)
      return AnyView(
        clipped
          .frame(width: canvasSize.width, height: canvasSize.height, alignment: resolvedAlignment),
      )
    }
  }

  private func mappedImageView(
    _ image: CGImage,
    canvasSize: CGSize,
    paddedSize: CGSize,
    padding: CGFloat,
  ) -> AnyView {
    let baseImage = Image(decorative: image, scale: 1, orientation: .up)

    switch mapping {
    case .canvasCoordinates:
      let framed = baseImage
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
      guard padding > 0 else { return AnyView(framed) }

      return AnyView(framed.offset(x: padding, y: padding))
    case let .fit(mode, alignment):
      let resolvedAlignment = Alignment(
        horizontal: alignment.horizontalAlignment,
        vertical: alignment.verticalAlignment,
      )
      let resized = baseImage.resizable()
      let mapped = switch mode {
      case .aspectFit:
        AnyView(resized.aspectRatio(contentMode: .fit))
      case .aspectFill:
        AnyView(resized.aspectRatio(contentMode: .fill))
      case .stretch:
        AnyView(resized)
      }
      let framed = mapped.frame(width: paddedSize.width, height: paddedSize.height)
      let clipped = mode == .aspectFill ? AnyView(framed.clipped()) : AnyView(framed)
      return AnyView(
        clipped
          .frame(width: canvasSize.width, height: canvasSize.height, alignment: resolvedAlignment),
      )
    }
  }
}

extension TesseraCanvasRegion {
  @MainActor
  func resolvedAlphaMask(
    in canvasSize: CGSize,
  ) -> TesseraAlphaMask? {
    guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
    guard case let .alphaMask(region) = self else { return nil }

    return TesseraAlphaMaskRenderer.render(region, canvasSize: canvasSize)
  }
}

private extension UnitPoint {
  var horizontalAlignment: HorizontalAlignment {
    switch x {
    case ..<0.33:
      .leading
    case 0.33..<0.66:
      .center
    default:
      .trailing
    }
  }

  var verticalAlignment: VerticalAlignment {
    switch y {
    case ..<0.33:
      .top
    case 0.33..<0.66:
      .center
    default:
      .bottom
    }
  }
}
