// By Dennis Müller

import SwiftUI
import Tessera

enum DemoSymbols {
  static var organic: [Symbol] {
    [
      .roundedSquareLarge,
      .roundedSquareSmall,
      .circleRing,
      .cornerStroke,
      .singleBar,
      .doubleBar,
      .diamondOutline,
      .triangleFill,
    ]
  }

  static var grid: [Symbol] {
    [.gridCross, .gridCrossRotated]
  }

  static var gridMergedCells: [Symbol] {
    [.mergedCellDot]
  }

  static var mosaic: [Symbol] {
    [.circleRing, .roundedSquareSmall, .singleBar, .diamondOutline, .triangleFill]
  }

  static var rotationBars: [Symbol] {
    [.rotationBarBold, .rotationBarLight]
  }
}

extension Symbol {
  static var roundedSquareLarge: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 38, height: 38))),
    ) {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(DemoPalette.strokePrimary, lineWidth: 3.5)
        .frame(width: 32, height: 32)
    }
  }

  static var roundedSquareSmall: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 30, height: 30))),
    ) {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .stroke(DemoPalette.strokeMuted, lineWidth: 3)
        .frame(width: 24, height: 24)
    }
  }

  static var circleRing: Symbol {
    Symbol(
      collider: .shape(.circle(center: .zero, radius: 14)),
    ) {
      Circle()
        .stroke(DemoPalette.strokeMuted.opacity(0.7), lineWidth: 3)
        .frame(width: 28, height: 28)
    }
  }

  static var cornerStroke: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 30, height: 30))),
    ) {
      CornerGlyph(color: DemoPalette.teal)
        .frame(width: 30, height: 30)
    }
  }

  static var singleBar: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 32, height: 6))),
    ) {
      Capsule()
        .fill(DemoPalette.strokeMuted.opacity(0.92))
        .frame(width: 28, height: 4)
    }
  }

  static var doubleBar: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 32, height: 14))),
    ) {
      VStack(spacing: 4) {
        Capsule().fill(DemoPalette.strokeMuted.opacity(0.95)).frame(width: 28, height: 3)
        Capsule().fill(DemoPalette.strokeMuted.opacity(0.80)).frame(width: 20, height: 3)
      }
    }
  }

  static var diamondOutline: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 32, height: 32))),
    ) {
      RoundedRectangle(cornerRadius: 5, style: .continuous)
        .stroke(DemoPalette.amber.opacity(0.9), lineWidth: 3)
        .frame(width: 21, height: 21)
        .rotationEffect(.degrees(45))
    }
  }

  static var triangleFill: Symbol {
    Symbol(
      collider: .shape(.polygon(points: [
        CGPoint(x: 0, y: 12),
        CGPoint(x: 14, y: -12),
        CGPoint(x: -14, y: -12),
      ])),
    ) {
      TriangleShape()
        .fill(DemoPalette.coral.opacity(0.82))
        .frame(width: 26, height: 24)
    }
  }

  static var gridCross: Symbol {
    Symbol(
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 28, height: 28))),
    ) {
      CrossGlyph(color: DemoPalette.blue, size: 24, lineWidth: 4)
    }
  }

  static var gridCrossRotated: Symbol {
    Symbol(
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 28, height: 28))),
    ) {
      CrossGlyph(color: DemoPalette.amber.opacity(0.86), size: 22, lineWidth: 3)
        .rotationEffect(.degrees(45))
    }
  }

  static var rotationBarBold: Symbol {
    Symbol(
      rotation: .degrees(90)...(.degrees(90)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 34, height: 7))),
    ) {
      Capsule()
        .fill(DemoPalette.blue.opacity(0.92))
        .frame(width: 32, height: 5)
    }
  }

  static var rotationBarLight: Symbol {
    Symbol(
      rotation: .degrees(45)...(.degrees(45)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 28, height: 6))),
    ) {
      Capsule()
        .fill(DemoPalette.coral.opacity(0.78))
        .frame(width: 26, height: 4)
    }
  }

  static var mergedCellDot: Symbol {
    Symbol(
      id: DemoSymbolIDs.gridMergedCellDot,
      collider: .shape(.circle(center: .zero, radius: 8)),
    ) {
      Circle()
        .fill(DemoPalette.blue.opacity(0.9))
        .frame(width: 12, height: 12)
    }
  }

  static var mergedCellDiamond: Symbol {
    Symbol(
      id: DemoSymbolIDs.gridMergedCellDiamond,
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 46, height: 46))),
    ) {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(DemoPalette.strokePrimary.opacity(0.88), lineWidth: 2)
        .frame(width: 34, height: 34)
    }
  }
}

private struct CornerGlyph: View {
  let color: Color

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(color)
        .frame(width: 28, height: 6)

      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(color)
        .frame(width: 6, height: 28)
    }
    .frame(width: 28, height: 28)
  }
}

private struct CrossGlyph: View {
  let color: Color
  let size: CGFloat
  let lineWidth: CGFloat

  var body: some View {
    ZStack {
      Capsule()
        .fill(color)
        .frame(width: size, height: lineWidth)

      Capsule()
        .fill(color)
        .frame(width: lineWidth, height: size)
    }
  }
}

private struct TriangleShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
