// By Dennis Müller

import SwiftUI
import Tessera

struct TesseraDemoView: View {
  var body: some View {
    let demoItems: [TesseraItem] = [
      //      .squareOutline,
//      .roundedOutline,
//      .partyPopper,
//      .minus,
//      .equals,
//      .splitLetters,
      .concaveBlock,
//      .circleOutline,
    ]

    let demoConfiguration = TesseraConfiguration(
      items: demoItems,
      seed: 0,
      minimumSpacing: 0,
      density: 0.8,
      baseScaleRange: 0.5...1.2,
      maximumItemCount: 1,
      showsCollisionOverlay: true,
    )

    TabView {
      TesseraTiledCanvas(
        demoConfiguration,
        tileSize: CGSize(width: 256, height: 256),
      )
      .ignoresSafeArea()
      .tabItem {
        Label("Tiled Canvas", systemImage: "square.grid.3x3.fill")
      }

      TesseraCanvas(
        demoConfiguration,
        fixedItems: [
          TesseraFixedItem(
            position: .centered(),
            collisionShape: .circle(center: .zero, radius: 60),
          ) {
            Image(systemName: "swift")
              .resizable()
              .scaledToFit()
              .foregroundStyle(.orange)
              .frame(width: 100, height: 100)
          },
          TesseraFixedItem(
            position: .bottomTrailing(offset: CGSize(width: -120, height: -120)),
            collisionShape: .circle(center: .zero, radius: 140),
          ) {
            Text("Tessera")
              .font(.system(size: 48, weight: .bold, design: .rounded))
              .foregroundStyle(.white.opacity(0.8))
          },
        ],
        edgeBehavior: .finite,
      )
      .background(.black)
      .ignoresSafeArea()
      .tabItem {
        Label("Canvas", systemImage: "rectangle.and.pencil.and.ellipsis")
      }
    }
  }
}

#Preview {
  TesseraDemoView()
    .preferredColorScheme(.dark)
}

extension TesseraItem {
  /// A lightly stroked square outline.
  static var squareOutline: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 34, height: 34)),
    ) {
      Rectangle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.8))
        .frame(width: 30, height: 30)
    }
  }

  /// A softly rounded rectangle outline.
  static var roundedOutline: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 34, height: 34)),
    ) {
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 4)
        .frame(width: 30, height: 30)
    }
  }

  /// A celebratory SF Symbol.
  static var partyPopper: TesseraItem {
    TesseraItem(
      allowedRotationRange: .degrees(-45)...(.degrees(45)),
      collisionShape: .circle(center: .zero, radius: 20),
    ) {
      Image(systemName: "party.popper.fill")
        .foregroundStyle(.red.opacity(0.5))
        .font(.largeTitle)
    }
  }

  /// A minus glyph.
  static var minus: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 4)),
    ) {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// An equals glyph.
  static var equals: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 12)),
    ) {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// A subtle circle outline.
  static var circleOutline: TesseraItem {
    TesseraItem(
      collisionShape: .circle(center: .zero, radius: 15),
    ) {
      Circle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.2))
        .frame(width: 30, height: 30)
    }
  }

  /// Two glyphs represented by separate polygons.
  static var splitLetters: TesseraItem {
    let leftLetterPoints = rectanglePoints(
      centeredAt: CGPoint(x: -6, y: 0),
      size: CGSize(width: 24, height: 22),
    )
    let rightLetterPoints = rectanglePoints(
      centeredAt: CGPoint(x: 12, y: 0),
      size: CGSize(width: 10, height: 22),
    )

    return TesseraItem(
      weight: 1,
      allowedRotationRange: .degrees(0)...(.degrees(0)),
      collisionShape: .polygons(pointSets: [leftLetterPoints, rightLetterPoints]),
    ) {
      Text("HI")
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .foregroundStyle(.purple.opacity(0.7))
    }
  }

  /// A concave polygon rendered as a filled L-shape.
  static var concaveBlock: TesseraItem {
    let concavePoints: [CGPoint] = [
      CGPoint(x: -14, y: -14),
      CGPoint(x: 14, y: -14),
      CGPoint(x: 14, y: -6),
      CGPoint(x: -6, y: -6),
      CGPoint(x: -6, y: 14),
      CGPoint(x: -14, y: 14),
    ]

    return TesseraItem(
      allowedRotationRange: .degrees(0)...(.degrees(0)),
      collisionShape: .polygon(points: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 32, y: 0),
        CGPoint(x: 32, y: 32),
        CGPoint(x: 0, y: 32),
      ]),
    ) {
      CenteredPolygonShape(points: concavePoints)
        .fill(.mint.opacity(0.5))
        .frame(width: 32, height: 32)
    }
  }

  private static func rectanglePoints(
    centeredAt center: CGPoint,
    size: CGSize,
  ) -> [CGPoint] {
    let halfWidth = size.width / 2
    let halfHeight = size.height / 2

    return [
      CGPoint(x: center.x - halfWidth, y: center.y - halfHeight),
      CGPoint(x: center.x + halfWidth, y: center.y - halfHeight),
      CGPoint(x: center.x + halfWidth, y: center.y + halfHeight),
      CGPoint(x: center.x - halfWidth, y: center.y + halfHeight),
    ]
  }
}

private struct CenteredPolygonShape: Shape {
  var points: [CGPoint]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard let firstPoint = points.first else { return path }

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let start = CGPoint(x: center.x + firstPoint.x, y: center.y + firstPoint.y)
    path.move(to: start)

    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: center.x + point.x, y: center.y + point.y))
    }

    path.closeSubpath()
    return path
  }
}
