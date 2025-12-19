// By Dennis Müller

import SwiftUI

public extension TesseraSymbol {
  /// Returns an editor view for building and exporting collision shapes visually.
  ///
  /// - Parameter initialCollisionShape: Optional shape to edit; defaults to the symbol's current shape.
  /// - Returns: A collision editor view for the symbol.
  @MainActor
  func collisionEditor(initialCollisionShape: CollisionShape? = nil) -> some View {
    TesseraSymbolCollisionEditor(self, initialCollisionShape: initialCollisionShape ?? collisionShape)
  }
}
