// By Dennis Müller

import SwiftUI
import Tessera

enum DemoSymbols {
  static var organic: [Symbol] {
    [.squareOutline, .roundedOutline, .partyPopper, .minus, .equals, .splitLetters, .concaveBlock, .circleOutline]
  }

  static var grid: [Symbol] {
    [.gridPlus, .gridPlusRotated]
  }

  static var gridMergedCells: [Symbol] {
    [.mergedCellDot]
  }

  static var mosaic: [Symbol] {
    [.partyPopper, .circleOutline, .roundedOutline, .equals, .minus]
  }

  static var rotationBars: [Symbol] {
    [.rotationBarBold, .rotationBarLight]
  }
}

extension Symbol {
  static var squareOutline: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 34, height: 34))),
    ) {
      Rectangle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.8))
        .frame(width: 30, height: 30)
    }
  }

  static var roundedOutline: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 34, height: 34))),
    ) {
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 4)
        .frame(width: 30, height: 30)
    }
  }

  static var partyPopper: Symbol {
    Symbol(
      rotation: .degrees(-45)...(.degrees(45)),
      collider: .shape(.circle(center: .zero, radius: 20)),
    ) {
      Image(systemName: "party.popper.fill")
        .foregroundStyle(.red.opacity(0.5))
        .font(.largeTitle)
    }
  }

  static var minus: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 36, height: 4))),
    ) {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  static var equals: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 36, height: 12))),
    ) {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  static var circleOutline: Symbol {
    Symbol(
      collider: .shape(.circle(center: .zero, radius: 15)),
    ) {
      Circle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.2))
        .frame(width: 30, height: 30)
    }
  }

  static var splitLetters: Symbol {
    let leftLetterPoints = rectanglePoints(
      centeredAt: CGPoint(x: -6, y: 0),
      size: CGSize(width: 24, height: 22),
    )
    let rightLetterPoints = rectanglePoints(
      centeredAt: CGPoint(x: 12, y: 0),
      size: CGSize(width: 10, height: 22),
    )

    return Symbol(
      weight: 1,
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.polygons(pointSets: [leftLetterPoints, rightLetterPoints])),
    ) {
      Text("HI")
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .foregroundStyle(.purple.opacity(0.7))
    }
  }

  static var concaveBlock: Symbol {
    let points: [CGPoint] = [
      CGPoint(x: 2, y: 2),
      CGPoint(x: 30, y: 2),
      CGPoint(x: 30, y: 10),
      CGPoint(x: 10, y: 10),
      CGPoint(x: 10, y: 30),
      CGPoint(x: 2, y: 30),
    ]

    return Symbol(
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.polygon(points: points)),
    ) {
      ConcavePolygonShape(points: points)
        .fill(.mint.opacity(0.5))
        .frame(width: 32, height: 32)
    }
  }

  static var gridPlus: Symbol {
    Symbol(
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 0, height: 0))),
    ) {
      Image(systemName: "plus")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 25, height: 25)
    }
  }

  static var gridPlusRotated: Symbol {
    Symbol(
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 0, height: 0))),
    ) {
      Image(systemName: "plus")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 25, height: 25)
        .opacity(0.5)
        .rotationEffect(.degrees(45))
    }
  }

  static var rotationBarBold: Symbol {
    Symbol(
      rotation: .degrees(90)...(.degrees(90)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 34, height: 7))),
    ) {
      Capsule()
        .fill(.white.opacity(0.9))
        .frame(width: 32, height: 5)
    }
  }

  static var rotationBarLight: Symbol {
    Symbol(
      rotation: .degrees(45)...(.degrees(45)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 28, height: 6))),
    ) {
      Capsule()
        .fill(.gray.opacity(0.7))
        .frame(width: 26, height: 4)
    }
  }

  static var mergedCellDot: Symbol {
    Symbol(
      id: DemoSymbolIDs.gridMergedCellDot,
      collider: .shape(.circle(center: .zero, radius: 8)),
    ) {
      Circle()
        .fill(.mint.opacity(0.8))
        .frame(width: 12, height: 12)
    }
  }

  static var mergedCellDiamond: Symbol {
    Symbol(
      id: DemoSymbolIDs.gridMergedCellDiamond,
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 46, height: 46))),
    ) {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(.white.opacity(0.7), lineWidth: 2)
        .frame(width: 34, height: 34)
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
