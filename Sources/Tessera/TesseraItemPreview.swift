// By Dennis Müller

import SwiftUI

/// A view that renders a `TesseraItem` with an optional collision overlay.
///
/// Use this in SwiftUI previews to iterate on `CollisionShape` polygons and verify the expected footprint.
public struct TesseraItemPreview: View {
  public var item: TesseraItem
  public var showsCollisionOverlay: Bool

  /// Creates a preview for a tessera item.
  ///
  /// - Parameters:
  ///   - item: The tessera item to render.
  ///   - showsCollisionOverlay: Whether to draw the collision overlay on top of the item.
  public init(
    _ item: TesseraItem,
    showsCollisionOverlay: Bool = false,
  ) {
    self.item = item
    self.showsCollisionOverlay = showsCollisionOverlay
  }

  public var body: some View {
    item
      .makeView()
      .overlay {
        if showsCollisionOverlay {
          CollisionOverlayPreview(collisionShape: item.collisionShape)
        }
      }
  }
}

public extension TesseraItem {
  /// Returns a preview view that can optionally draw the collision overlay.
  ///
  /// - Parameter showsCollisionOverlay: Whether to draw the collision overlay on top of the item.
  /// - Returns: A preview view for the item.
  @MainActor
  func preview(showsCollisionOverlay: Bool = false) -> some View {
    TesseraItemPreview(self, showsCollisionOverlay: showsCollisionOverlay)
  }
}

private struct CollisionOverlayPreview: View {
  var collisionShape: CollisionShape

  var body: some View {
    GeometryReader { proxy in
      Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { context, size in
        var overlayContext = context
        overlayContext.translateBy(x: size.width * 0.5, y: size.height * 0.5)
        let overlayShape = CollisionOverlayShape(collisionShape: collisionShape)
        CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &overlayContext)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .allowsHitTesting(false)
  }
}
