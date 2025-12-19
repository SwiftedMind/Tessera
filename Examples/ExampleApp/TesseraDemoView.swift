// By Dennis Müller

import SwiftUI
import Tessera

struct TesseraDemoView: View {
  @State private var selectedView: Int = 2
  @State private var showCollisions: Bool = false

  var body: some View {
    let demoSymbols: [TesseraSymbol] = [
      .squareOutline,
      .roundedOutline,
      .partyPopper,
      .minus,
      .equals,
      .splitLetters,
      .concaveBlock,
      .circleOutline,
    ]

    let demoConfiguration = TesseraConfiguration(
      symbols: demoSymbols,
      seed: 0,
      minimumSpacing: 0,
      density: 0.8,
      baseScaleRange: 0.5...1.2,
      showsCollisionOverlay: showCollisions,
    )

    TabView(selection: $selectedView) {
      // Repeating Tiles
      TesseraTiledCanvas(
        demoConfiguration,
        tileSize: CGSize(width: 256, height: 256),
      )
      .ignoresSafeArea()
      .tabItem {
        Label("Tiled Canvas", systemImage: "square.grid.3x3.fill")
      }
      .tag(0)

      // Finite-sized Canvas
      TesseraCanvas(
        demoConfiguration,
        pinnedSymbols: [
          TesseraPinnedSymbol(
            position: .centered(),
            collisionShape: .circle(center: .zero, radius: 60),
          ) {
            Image(systemName: "swift")
              .resizable()
              .scaledToFit()
              .foregroundStyle(.orange)
              .frame(width: 100, height: 100)
          },
          TesseraPinnedSymbol(
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
      .tag(1)

      // Collision Shape Editor
      CollisionShapeEditorDemo()
        .tabItem {
          Label("Collision Editor", systemImage: "viewfinder")
        }
        .tag(2)
    }
  }
}

#Preview {
  TesseraDemoView()
    .preferredColorScheme(.dark)
}

private struct CollisionShapeEditorDemo: View {
  var body: some View {
    previewSymbol.collisionShapeEditor()
  }

  var previewSymbol: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .polygon(points: [
        CGPoint(x: 15, y: 10),
        CGPoint(x: 32, y: 8),
        CGPoint(x: 60, y: 22),
        CGPoint(x: 30, y: 60),
        CGPoint(x: 0, y: 22),
      ]),
    ) {
      Image(systemName: "shield.fill")
        .font(.system(size: 52, weight: .semibold))
        .foregroundStyle(.primary)
    }
  }
}

extension TesseraSymbol {
  /// A lightly stroked square outline.
  static var squareOutline: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 34, height: 34)),
    ) {
      Rectangle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.8))
        .frame(width: 30, height: 30)
    }
  }

  /// A softly rounded rectangle outline.
  static var roundedOutline: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 34, height: 34)),
    ) {
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 4)
        .frame(width: 30, height: 30)
    }
  }

  /// A celebratory SF Symbol.
  static var partyPopper: TesseraSymbol {
    TesseraSymbol(
      allowedRotationRange: .degrees(-45)...(.degrees(45)),
      collisionShape: .circle(center: .zero, radius: 20),
    ) {
      Image(systemName: "party.popper.fill")
        .foregroundStyle(.red.opacity(0.5))
        .font(.largeTitle)
    }
  }

  /// A minus glyph.
  static var minus: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 4)),
    ) {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// An equals glyph.
  static var equals: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 12)),
    ) {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// A subtle circle outline.
  static var circleOutline: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .circle(center: .zero, radius: 15),
    ) {
      Circle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.2))
        .frame(width: 30, height: 30)
    }
  }

  /// Two glyphs represented by separate polygons.
  static var splitLetters: TesseraSymbol {
    let leftLetterPoints = rectanglePoints(
      centeredAt: CGPoint(x: -6, y: 0),
      size: CGSize(width: 24, height: 22),
    )
    let rightLetterPoints = rectanglePoints(
      centeredAt: CGPoint(x: 12, y: 0),
      size: CGSize(width: 10, height: 22),
    )

    return TesseraSymbol(
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
  static var concaveBlock: TesseraSymbol {
    let points: [CGPoint] = [
      CGPoint(x: 2, y: 2),
      CGPoint(x: 30, y: 2),
      CGPoint(x: 30, y: 10),
      CGPoint(x: 10, y: 10),
      CGPoint(x: 10, y: 30),
      CGPoint(x: 2, y: 30),
    ]

    return TesseraSymbol(
      allowedRotationRange: .degrees(0)...(.degrees(0)),
      collisionShape: .polygon(points: points),
    ) {
      ConcavePolygonShape(points: points)
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

private struct ConcavePolygonShape: Shape {
  var points: [CGPoint]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard let firstPoint = points.first else { return path }

    let start = CGPoint(x: firstPoint.x, y: firstPoint.y)
    path.move(to: start)

    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: point.x, y: point.y))
    }

    path.closeSubpath()
    return path
  }
}
