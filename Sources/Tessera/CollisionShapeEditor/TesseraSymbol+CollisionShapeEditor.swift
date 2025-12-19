// By Dennis Müller

import SwiftUI

public extension TesseraSymbol {
  /// Returns an interactive editor view for building and exporting collision shapes visually.
  ///
  /// - Parameter initialCollisionShape: Optional shape to edit; defaults to the symbol's current shape.
  /// - Returns: A collision editor view for the symbol.
  @MainActor
  func collisionShapeEditor(initialCollisionShape: CollisionShape? = nil) -> some View {
    CollisionShapeEditor(self, initialCollisionShape: initialCollisionShape ?? collisionShape)
  }
}
