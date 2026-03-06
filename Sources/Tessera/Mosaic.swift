// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Rendering strategy for mosaic symbol content at mask boundaries.
///
/// Compatibility note: Tessera currently treats post-cutover rendering semantics as pre-release,
/// so mode behavior may evolve before the next release tag without migration shims.
public enum MosaicRendering: Hashable, Sendable {
  /// Requires sampled collision geometry to stay inside the mask.
  case contained
  /// Clips rendered mosaic content to the mask while only requiring symbol center points to stay inside.
  case clipped
  /// Leaves mosaic content unclipped and only requires symbol center points to stay inside the mask.
  case unclipped
}

extension MosaicRendering {
  /// Indicates whether rendered mosaic content is clipped to the mask.
  var clipsToMask: Bool {
    switch self {
    case .contained, .clipped:
      true
    case .unclipped:
      false
    }
  }
}

/// Describes a collision-shape-derived mask used by a mosaic.
public struct MosaicMask: Identifiable, @unchecked Sendable {
  /// Stable identity for this mask.
  public var id: UUID
  /// Symbol used for mosaic mask behavior.
  ///
  /// Placement planning uses the symbol's collision shape for performance,
  /// while render clipping/debug overlays use the symbol's rendered alpha.
  public var symbol: Symbol
  /// Center position of the mask in canvas/tile coordinates.
  public var position: PinnedPosition
  /// Rotation applied to the mask shape while resolving mask coverage.
  public var rotation: Angle
  /// Scale applied to the mask shape while resolving mask coverage.
  public var scale: CGFloat

  /// Creates a mosaic mask definition.
  public init(
    id: UUID = UUID(),
    symbol: Symbol,
    position: PinnedPosition = .centered(),
    rotation: Angle = .zero,
    scale: CGFloat = 1,
  ) {
    self.id = id
    self.symbol = symbol
    self.position = position
    self.rotation = rotation
    self.scale = scale
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
