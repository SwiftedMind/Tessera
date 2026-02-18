// By Dennis Müller

import SwiftUI
import Tessera

enum DemoExampleAssets {
  static var alphaMaskRegion: Region {
    .alphaMask(
      AlphaMask(
        cacheKey: "alpha-mask-demo",
        alphaThreshold: 0.2,
        sampling: .bilinear,
      ) {
        AlphaMaskShape()
      },
    )
  }

  static var collisionPreviewSymbol: Symbol {
    Symbol(
      collider: .shape(.polygon(points: [
        CGPoint(x: 6.46, y: 12.57),
        CGPoint(x: 6.74, y: 39.74),
        CGPoint(x: 28.65, y: 56.17),
        CGPoint(x: 49.01, y: 42.06),
        CGPoint(x: 48.73, y: 12.36),
        CGPoint(x: 27.95, y: 4.56),
      ])),
    ) {
      Image(systemName: "shield.fill")
        .font(.system(size: 52, weight: .semibold))
        .foregroundStyle(.primary)
    }
  }
}

private struct AlphaMaskShape: View {
  var body: some View {
    Image(systemName: "sparkles")
      .font(.system(size: 120, weight: .bold))
      .foregroundStyle(.black.opacity(0.7))
      .padding(20)
  }
}
