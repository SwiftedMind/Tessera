// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Rendering strategy for mosaic symbol content at mask boundaries.
public enum MosaicRendering: Hashable, Sendable {
  /// Clips rendered mosaic content to the mask.
  case clipped
  /// Leaves mosaic content unclipped while still constraining placement to the mask.
  case unclipped
}

/// Describes a symbol-derived alpha mask used by a mosaic.
public struct MosaicMask: Identifiable, @unchecked Sendable {
  /// Stable identity for this mask.
  public var id: UUID
  /// Symbol used as the visual source for alpha-mask rasterization.
  public var symbol: Symbol
  /// Center position of the mask in canvas/tile coordinates.
  public var position: PinnedPosition
  /// Rotation applied to the mask symbol while rasterizing.
  public var rotation: Angle
  /// Scale applied to the mask symbol while rasterizing.
  public var scale: CGFloat
  /// Inclusion threshold in the `0...1` range.
  public var alphaThreshold: CGFloat
  /// Rasterization scale used for alpha sampling.
  public var pixelScale: CGFloat
  /// Sampling strategy used while reading alpha values.
  public var sampling: AlphaMask.Sampling

  /// Creates a mosaic mask definition.
  public init(
    id: UUID = UUID(),
    symbol: Symbol,
    position: PinnedPosition = .centered(),
    rotation: Angle = .zero,
    scale: CGFloat = 1,
    alphaThreshold: CGFloat = 0.5,
    pixelScale: CGFloat = 2,
    sampling: AlphaMask.Sampling = .nearest,
  ) {
    self.id = id
    self.symbol = symbol
    self.position = position
    self.rotation = rotation
    self.scale = scale
    self.alphaThreshold = alphaThreshold
    self.pixelScale = pixelScale
    self.sampling = sampling
  }
}

/// Defines a nested pattern rendered inside a symbol-derived mask.
public struct Mosaic: Identifiable, @unchecked Sendable {
  /// Stable identity for this mosaic.
  public var id: UUID
  /// Mask definition used to carve out the mosaic area.
  public var mask: MosaicMask
  /// Symbols used only inside this mosaic.
  public var symbols: [Symbol]
  /// Placement strategy for symbols inside this mosaic.
  public var placement: TesseraPlacement
  /// Rendering strategy at the mask boundary.
  public var rendering: MosaicRendering
  /// Offset applied to generated mosaic symbols before wrapping.
  public var offset: CGSize

  /// Creates a mosaic definition.
  public init(
    id: UUID = UUID(),
    mask: MosaicMask,
    symbols: [Symbol],
    placement: TesseraPlacement = .organic(),
    rendering: MosaicRendering = .clipped,
    offset: CGSize = .zero,
  ) {
    self.id = id
    self.mask = mask
    self.symbols = symbols
    self.placement = placement
    self.rendering = rendering
    self.offset = offset
  }
}
