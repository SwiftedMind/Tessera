// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Captures a concrete placement of a tessera item, including transform data for collisions.
struct PlacedItem {
  /// Item definition and its view builder.
  var item: TesseraItem
  /// Center position within the tile.
  var position: CGPoint
  /// Rotation applied to both drawing and collision checks.
  var rotation: Angle
  /// Uniform scale applied to the item.
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
