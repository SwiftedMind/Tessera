// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Primary pinned-symbol API alias for Tessera v4.
public typealias PinnedSymbol = TesseraPinnedSymbol
/// Primary pinned-position API alias for Tessera v4.
public typealias PinnedPosition = TesseraPlacementPosition

public extension PinnedPosition {
  /// Creates an absolute pinned position in canvas coordinates.
  init(_ point: CGPoint) {
    self = .absolute(point)
  }

  /// Creates a relative pinned position inside the canvas.
  ///
  /// - Parameters:
  ///   - point: Relative anchor point (`.center`, `.topLeading`, ...).
  ///   - offset: Optional offset in points.
  init(_ point: UnitPoint, offset: CGSize = .zero) {
    self = .relative(point, offset: offset)
  }
}

public extension PinnedSymbol {
  /// Creates a pinned symbol using v4 naming.
  ///
  /// Pinned symbols are rendered once and treated as placement obstacles.
  init(
    id: UUID = UUID(),
    position: PinnedPosition,
    zIndex: Double = 0,
    rotation: Angle = .zero,
    scale: CGFloat = 1,
    collider: Collider = .automatic(size: CGSize(width: 30, height: 30)),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    switch collider {
    case let .shape(shape):
      self.init(
        id: id,
        position: position,
        zIndex: zIndex,
        rotation: rotation,
        scale: scale,
        collisionShape: shape,
        content: content,
      )
    case let .automatic(size):
      self.init(
        id: id,
        position: position,
        zIndex: zIndex,
        rotation: rotation,
        scale: scale,
        approximateSize: size,
        content: content,
      )
    }
  }

  /// Convenience constructor for absolute positions.
  static func absolute(
    _ point: CGPoint,
    zIndex: Double = 0,
    rotation: Angle = .zero,
    scale: CGFloat = 1,
    collider: Collider = .automatic(size: CGSize(width: 30, height: 30)),
    @ViewBuilder content: @escaping () -> some View,
  ) -> PinnedSymbol {
    .init(
      position: .absolute(point),
      zIndex: zIndex,
      rotation: rotation,
      scale: scale,
      collider: collider,
      content: content,
    )
  }
}
