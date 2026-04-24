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

  static var fixedCellClipping: [Symbol] {
    [.fixedCellBlock, .fixedCellDiamond]
  }

  static var gridSubgrids: [Symbol] {
    [.subgridDot]
  }

  static var mosaic: [Symbol] {
    [.circleRing, .roundedSquareSmall, .singleBar, .diamondOutline, .triangleFill]
  }

  static var mosaicCore: [Symbol] {
    [.mosaicDotFill, .mosaicBarFill, .mosaicDiamondFill]
  }

  static var mosaicAccent: [Symbol] {
    [.mosaicSmallRing, .mosaicTriangleFill]
  }

  static var rotationBars: [Symbol] {
    [.rotationBarBold, .rotationBarLight]
  }

  static var denseOrnamental: [Symbol] {
    [
      .denseLargeLeaf,
      .denseSmallLeaf,
      .denseTeardrop,
      .denseCurl,
      .denseLargeDot,
      .denseSmallDot,
      .denseSpark,
    ]
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
      collider: .shape(.triangle(size: CGSize(width: 28, height: 24))),
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

  static var fixedCellBlock: Symbol {
    Symbol(
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.roundedRectangle(size: CGSize(width: 50, height: 50), cornerRadius: 14)),
    ) {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(DemoPalette.blue.opacity(0.26))
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(DemoPalette.blue.opacity(0.95), lineWidth: 4)
        }
        .frame(width: 44, height: 44)
    }
  }

  static var fixedCellDiamond: Symbol {
    Symbol(
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 48, height: 48))),
    ) {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(DemoPalette.amber.opacity(0.20))
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(DemoPalette.amber.opacity(0.92), lineWidth: 4)
        }
        .frame(width: 40, height: 40)
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

  static var subgridDot: Symbol {
    Symbol(
      id: DemoSymbolIDs.gridSubgridDot,
      collider: .shape(.circle(center: .zero, radius: 8)),
    ) {
      Circle()
        .fill(DemoPalette.blue.opacity(0.9))
        .frame(width: 12, height: 12)
    }
  }

  static var subgridMiniDot: Symbol {
    Symbol(
      id: DemoSymbolIDs.gridSubgridMiniDot,
      collider: .shape(.circle(center: .zero, radius: 4.5)),
    ) {
      Circle()
        .fill(DemoPalette.blue.opacity(0.88))
        .frame(width: 4, height: 4)
    }
  }

  static var subgridDiamond: Symbol {
    Symbol(
      id: DemoSymbolIDs.gridSubgridDiamond,
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 46, height: 46))),
    ) {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(DemoPalette.strokePrimary.opacity(0.88), lineWidth: 2)
        .frame(width: 34, height: 34)
    }
  }

  static var mosaicMaskBlob: Symbol {
    Symbol(collider: .shape(.roundedRectangle(size: CGSize(width: 250, height: 160), cornerRadius: 56))) {
      RoundedRectangle(cornerRadius: 56, style: .continuous)
        .fill(Color.white)
        .frame(width: 250, height: 160)
        .rotationEffect(.degrees(-8))
    }
  }

  static var mosaicMaskDiamond: Symbol {
    Symbol(collider: .shape(.roundedRectangle(size: CGSize(width: 170, height: 170), cornerRadius: 26))) {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(Color.white)
        .frame(width: 170, height: 170)
        .rotationEffect(.degrees(45))
    }
  }

  static var mosaicDotFill: Symbol {
    Symbol(
      collider: .shape(.circle(center: .zero, radius: 8)),
    ) {
      Circle()
        .fill(DemoPalette.blue.opacity(0.88))
        .frame(width: 16, height: 16)
    }
  }

  static var mosaicBarFill: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 24, height: 8))),
    ) {
      Capsule()
        .fill(DemoPalette.amber.opacity(0.86))
        .frame(width: 22, height: 6)
    }
  }

  static var mosaicDiamondFill: Symbol {
    Symbol(
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 20, height: 20))),
    ) {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(DemoPalette.teal.opacity(0.85))
        .frame(width: 14, height: 14)
        .rotationEffect(.degrees(45))
    }
  }

  static var mosaicSmallRing: Symbol {
    Symbol(
      collider: .shape(.circle(center: .zero, radius: 8)),
    ) {
      Circle()
        .stroke(DemoPalette.strokePrimary.opacity(0.9), lineWidth: 2)
        .frame(width: 16, height: 16)
    }
  }

  static var mosaicTriangleFill: Symbol {
    Symbol(
      collider: .shape(.triangle(size: CGSize(width: 18, height: 17))),
    ) {
      TriangleShape()
        .fill(DemoPalette.coral.opacity(0.82))
        .frame(width: 18, height: 17)
    }
  }

  static var denseLargeLeaf: Symbol {
    Symbol(
      weight: 0.7,
      rotation: .degrees(-65)...(.degrees(65)),
      scale: 0.8...1.25,
      collider: .shape(.centeredPolygon(points: [
        CGPoint(x: 0, y: -24),
        CGPoint(x: 12, y: -14),
        CGPoint(x: 16, y: 4),
        CGPoint(x: 0, y: 25),
        CGPoint(x: -16, y: 4),
        CGPoint(x: -12, y: -14),
      ])),
    ) {
      LeafShape()
        .fill(DemoPalette.amber.opacity(0.9))
        .frame(width: 34, height: 52)
    }
  }

  static var denseSmallLeaf: Symbol {
    Symbol(
      weight: 1.25,
      rotation: .degrees(-80)...(.degrees(80)),
      scale: 0.75...1.15,
      collider: .shape(.centeredPolygon(points: [
        CGPoint(x: 0, y: -15),
        CGPoint(x: 8, y: -8),
        CGPoint(x: 10, y: 2),
        CGPoint(x: 0, y: 16),
        CGPoint(x: -10, y: 2),
        CGPoint(x: -8, y: -8),
      ])),
    ) {
      LeafShape()
        .fill(DemoPalette.teal.opacity(0.86))
        .frame(width: 22, height: 32)
    }
  }

  static var denseTeardrop: Symbol {
    Symbol(
      weight: 1,
      rotation: .degrees(-90)...(.degrees(90)),
      scale: 0.75...1.2,
      collider: .shape(.centeredPolygon(points: [
        CGPoint(x: 0, y: -17),
        CGPoint(x: 12, y: -4),
        CGPoint(x: 9, y: 12),
        CGPoint(x: 0, y: 18),
        CGPoint(x: -9, y: 12),
        CGPoint(x: -12, y: -4),
      ])),
    ) {
      TeardropShape()
        .fill(DemoPalette.coral.opacity(0.84))
        .frame(width: 26, height: 38)
    }
  }

  static var denseCurl: Symbol {
    Symbol(
      weight: 0.75,
      rotation: .degrees(-45)...(.degrees(45)),
      scale: 0.8...1.1,
      collider: .shape(.circle(center: .zero, radius: 18)),
    ) {
      CurlShape()
        .stroke(DemoPalette.strokePrimary.opacity(0.82), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .frame(width: 36, height: 36)
    }
  }

  static var denseLargeDot: Symbol {
    Symbol(
      weight: 1.15,
      scale: 0.75...1.25,
      collider: .shape(.circle(center: .zero, radius: 10)),
    ) {
      Circle()
        .fill(DemoPalette.blue.opacity(0.85))
        .frame(width: 19, height: 19)
    }
  }

  static var denseSmallDot: Symbol {
    Symbol(
      weight: 2.8,
      scale: 0.7...1.15,
      collider: .shape(.circle(center: .zero, radius: 4.5)),
    ) {
      Circle()
        .fill(DemoPalette.amber.opacity(0.92))
        .frame(width: 8, height: 8)
    }
  }

  static var denseSpark: Symbol {
    Symbol(
      weight: 1.45,
      rotation: .degrees(-35)...(.degrees(35)),
      scale: 0.7...1.15,
      collider: .shape(.circle(center: .zero, radius: 7)),
    ) {
      CrossGlyph(color: DemoPalette.strokePrimary.opacity(0.7), size: 13, lineWidth: 3)
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

private struct LeafShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY),
      control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.16),
      control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.68),
    )
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.minY),
      control1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.68),
      control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.16),
    )
    path.closeSubpath()
    return path
  }
}

private struct TeardropShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY),
      control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
      control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.82),
    )
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.minY),
      control1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.82),
      control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2),
    )
    path.closeSubpath()
    return path
  }
}

private struct CurlShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.maxX * 0.82, y: rect.midY))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY * 0.82),
      control1: CGPoint(x: rect.maxX * 0.84, y: rect.maxY * 0.74),
      control2: CGPoint(x: rect.maxX * 0.68, y: rect.maxY * 0.88),
    )
    path.addCurve(
      to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.midY),
      control1: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY * 0.76),
      control2: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY * 0.56),
    )
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.22),
      control1: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.22),
      control2: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12),
    )
    path.addCurve(
      to: CGPoint(x: rect.maxX * 0.64, y: rect.midY),
      control1: CGPoint(x: rect.maxX * 0.76, y: rect.minY + rect.height * 0.34),
      control2: CGPoint(x: rect.maxX * 0.72, y: rect.midY),
    )
    return path
  }
}
