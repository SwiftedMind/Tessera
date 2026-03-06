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
      ZStack {
        HexagonShape()
          .fill(DemoPalette.teal.opacity(0.24))

        HexagonShape()
          .stroke(DemoPalette.teal, lineWidth: 3)

        Circle()
          .fill(DemoPalette.strokePrimary)
          .frame(width: 8, height: 8)
      }
      .frame(width: 56, height: 56)
    }
  }
}

private struct AlphaMaskShape: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .frame(width: 180, height: 180)

      Circle()
        .frame(width: 86, height: 86)
        .offset(y: -30)

      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .frame(width: 112, height: 30)
        .offset(y: 42)
    }
    .foregroundStyle(.black.opacity(0.72))
    .padding(20)
  }
}

private struct HexagonShape: Shape {
  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) * 0.5

    let points = (0..<6).map { index in
      let angle = CGFloat(index) * (.pi / 3) - (.pi / 2)
      return CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y + sin(angle) * radius,
      )
    }

    var path = Path()
    guard let first = points.first else { return path }

    path.move(to: first)
    for point in points.dropFirst() {
      path.addLine(to: point)
    }
    path.closeSubpath()
    return path
  }
}
