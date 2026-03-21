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
