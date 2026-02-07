// By Dennis Müller

import CoreGraphics
import SwiftUI

/// High-level collision intent for symbols.
public enum Collider: Hashable, Sendable {
  /// Builds a conservative circular collider from a size hint.
  case automatic(size: CGSize)
  /// Uses an explicit collision shape.
  case shape(CollisionShape)
}

/// Primary symbol API alias for Tessera v4.
public typealias Symbol = TesseraSymbol

public extension Symbol {
  /// Creates a renderable symbol with v4-friendly naming.
  ///
  /// - Parameters:
  ///   - id: Stable identifier for the symbol.
  ///   - weight: Relative sampling weight.
  ///   - rotation: Allowed rotation range.
  ///   - scale: Optional symbol-specific scale override.
  ///   - collider: Collision behavior used for placement checks.
  ///   - content: SwiftUI content drawn for each placed symbol.
  init(
    id: UUID = UUID(),
    weight: Double = 1,
    rotation: ClosedRange<Angle> = Angle.fullCircle,
    scale: ClosedRange<Double>? = nil,
    collider: Collider = .automatic(size: CGSize(width: 30, height: 30)),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    switch collider {
    case let .shape(shape):
      self.init(
        id: id,
        weight: weight,
        allowedRotationRange: rotation,
        scaleRange: scale,
        collisionShape: shape,
        content: content,
      )
    case let .automatic(size):
      self.init(
        id: id,
        weight: weight,
        allowedRotationRange: rotation,
        scaleRange: scale,
        approximateSize: size,
        content: content,
      )
    }
  }

  /// Alias for `allowedRotationRange`.
  var rotation: ClosedRange<Angle> {
    get { allowedRotationRange }
    set { allowedRotationRange = newValue }
  }

  /// Alias for `scaleRange`.
  var scale: ClosedRange<Double>? {
    get { scaleRange }
    set { scaleRange = newValue }
  }

  /// v4 collision representation.
  ///
  /// Reading returns `.shape(collisionShape)`.
  /// Writing `.automatic(size:)` updates `collisionShape` with a derived circle.
  var collider: Collider {
    get { .shape(collisionShape) }
    set {
      switch newValue {
      case let .shape(shape):
        collisionShape = shape
      case let .automatic(size):
        let radius = hypot(size.width, size.height) / 2
        collisionShape = .circle(center: .zero, radius: radius)
      }
    }
  }
}
