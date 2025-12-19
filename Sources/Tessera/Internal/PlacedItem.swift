// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Captures a concrete placement of a tessera symbol, including transform data for collisions.
struct PlacedSymbol {
  /// Symbol definition and its view builder.
  var symbol: TesseraSymbol
  /// Center position within the tile.
  var position: CGPoint
  /// Rotation applied to both drawing and collision checks.
  var rotation: Angle
  /// Uniform scale applied to the symbol.
  var scale: CGFloat

  /// Convenience accessor for collision calculations.
  var collisionTransform: CollisionTransform {
    CollisionTransform(
      position: position,
      rotation: CGFloat(rotation.radians),
      scale: scale,
    )
  }
}
