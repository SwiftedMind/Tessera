// By Dennis Müller

import SwiftUI

public extension TesseraItem {
  /// Returns an editor view for building and exporting collision shapes visually.
  ///
  /// - Parameter initialCollisionShape: Optional shape to edit; defaults to the item's current shape.
  /// - Returns: A collision editor view for the item.
  @MainActor
  func collisionEditor(initialCollisionShape: CollisionShape? = nil) -> some View {
    TesseraItemCollisionEditor(self, initialCollisionShape: initialCollisionShape ?? collisionShape)
  }
}
