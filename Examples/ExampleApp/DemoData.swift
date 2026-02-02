// By Dennis Müller

import SwiftUI
import Tessera

enum DemoConfigurations {
  static var organic: TesseraConfiguration {
    TesseraConfiguration(
      symbols: DemoSymbols.organic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 0,
          minimumSpacing: 0,
          density: 0.8,
          baseScaleRange: 0.5...1.2,
        ),
      ),
    )
  }

  static var grid: TesseraConfiguration {
    TesseraConfiguration(
      symbols: DemoSymbols.grid,
      placement: .grid(
        TesseraPlacement.Grid(
          columnCount: 6,
          rowCount: 6,
          offsetStrategy: .rowShift(fraction: 0.5),
          seed: 0,
        ),
      ),
    )
  }

  static var gridPatternRotation: TesseraConfiguration {
    TesseraConfiguration(
      symbols: DemoSymbols.grid,
      placement: .grid(
        TesseraPlacement.Grid(
          columnCount: 6,
          rowCount: 6,
          offsetStrategy: .rowShift(fraction: 0.5),
          seed: 0,
        ),
      ),
      patternRotation: .degrees(45),
    )
  }

  static var polygon: TesseraConfiguration {
    TesseraConfiguration(
      symbols: DemoSymbols.mosaic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 14,
          minimumSpacing: 2,
          density: 0.7,
          baseScaleRange: 0.6...1.1,
          maximumSymbolCount: 220,
        ),
      ),
    )
  }

  static var alphaMask: TesseraConfiguration {
    TesseraConfiguration(
      symbols: DemoSymbols.mosaic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 7,
          minimumSpacing: 2,
          density: 0.75,
          baseScaleRange: 0.6...1.2,
          maximumSymbolCount: 240,
        ),
      ),
    )
  }
}

enum DemoSymbols {
  static var organic: [TesseraSymbol] {
    [.squareOutline, .roundedOutline, .partyPopper, .minus, .equals, .splitLetters, .concaveBlock, .circleOutline]
  }

  static var grid: [TesseraSymbol] {
    [.gridPlus, .gridPlusRotated]
  }

  static var mosaic: [TesseraSymbol] {
    [.partyPopper, .circleOutline, .roundedOutline, .equals, .minus]
  }
}

enum DemoRegions {
  static var mosaic: TesseraCanvasRegion {
    TesseraCanvasRegion.polygon([
      CGPoint(x: 24, y: 6), CGPoint(x: 120, y: 0), CGPoint(x: 188, y: 42), CGPoint(x: 200, y: 130),
      CGPoint(x: 150, y: 204), CGPoint(x: 70, y: 196), CGPoint(x: 0, y: 120),
    ])
  }
}

enum DemoPinnedSymbols {
  static var hero: [TesseraPinnedSymbol] {
    [
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
    ]
  }
}

extension TesseraSymbol {
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

  static var roundedOutline: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 34, height: 34)),
    ) {
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 4)
        .frame(width: 30, height: 30)
    }
  }

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

  static var minus: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 4)),
    ) {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  static var equals: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 12)),
    ) {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

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

  static var gridPlus: TesseraSymbol {
    TesseraSymbol(
      allowedRotationRange: .degrees(0)...(.degrees(0)),
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 0, height: 0)),
    ) {
      Image(systemName: "plus")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 25, height: 25)
    }
  }

  static var gridPlusRotated: TesseraSymbol {
    TesseraSymbol(
      allowedRotationRange: .degrees(0)...(.degrees(0)),
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 0, height: 0)),
    ) {
      Image(systemName: "plus")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 25, height: 25)
        .opacity(0.5)
        .rotationEffect(.degrees(45))
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

    path.move(to: CGPoint(x: firstPoint.x, y: firstPoint.y))

    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: point.x, y: point.y))
    }

    path.closeSubpath()
    return path
  }
}
