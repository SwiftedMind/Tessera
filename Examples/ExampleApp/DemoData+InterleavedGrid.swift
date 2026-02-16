// By Dennis Müller

import SwiftUI
import Tessera

extension DemoConfigurations {
  static var interleavedGridPrimaryLayer: Pattern {
    Pattern(
      symbols: [.interleavedGridPrimary],
      placement: .grid(
        columns: InterleavedGridConstants.columns,
        rows: InterleavedGridConstants.rows,
        seed: 42,
        showsGridOverlay: true,
      ),
    )
  }

  static var interleavedGridSecondaryLayer: Pattern {
    Pattern(
      symbols: [.interleavedGridSecondary],
      placement: .grid(
        columns: InterleavedGridConstants.columns,
        rows: InterleavedGridConstants.rows,
        seed: 42,
        symbolPhases: [
          InterleavedGridSymbolIDs.secondary: .init(x: 0.5, y: 0.5),
        ],
        showsGridOverlay: true,
      ),
    )
  }
}

extension Symbol {
  static var interleavedGridPrimary: Symbol {
    interleavedGridNode(
      id: InterleavedGridSymbolIDs.primary,
      strokeColor: Color(red: 0.95, green: 0.34, blue: 0.27),
    )
  }

  static var interleavedGridSecondary: Symbol {
    interleavedGridNode(
      id: InterleavedGridSymbolIDs.secondary,
      strokeColor: Color(red: 0.90, green: 0.82, blue: 0.42),
    )
  }

  private static func interleavedGridNode(id: UUID, strokeColor: Color) -> Symbol {
    Symbol(
      id: id,
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 0, height: 0))),
    ) {
      InterleavedGridNodeGlyph(strokeColor: strokeColor)
        .frame(width: InterleavedGridConstants.symbolSize, height: InterleavedGridConstants.symbolSize)
    }
  }
}

struct InterleavedGridCanvas: View {
  var body: some View {
    ZStack {
      Color(red: 0.15, green: 0.16, blue: 0.20)

      Tessera(DemoConfigurations.interleavedGridPrimaryLayer)
        .mode(.tiled(tileSize: InterleavedGridConstants.tileSize))

      Tessera(DemoConfigurations.interleavedGridSecondaryLayer)
        .mode(.tiled(tileSize: InterleavedGridConstants.tileSize))
    }
  }
}

private enum InterleavedGridConstants {
  static let columns = 8
  static let rows = 8
  static let tileSize = CGSize(width: 320, height: 320)
  static let symbolSize: CGFloat = 40
}

private enum InterleavedGridSymbolIDs {
  static let primary = UUID(uuidString: "3AA5E7C7-E610-41AA-B647-C83B0A98720B")!
  static let secondary = UUID(uuidString: "845731F3-85D7-4313-8FA9-C8B95DDF3E8F")!
}

private struct InterleavedGridNodeGlyph: View {
  var strokeColor: Color

  var body: some View {
    GeometryReader { proxy in
      let size = min(proxy.size.width, proxy.size.height)
      let lineWidth = max(2, size * 0.05)
      let circleDiameter = size * 0.55
      let segmentLength = max(0, (size - circleDiameter) / 2)

      ZStack {
        VStack(spacing: 0) {
          Rectangle()
            .fill(strokeColor)
            .frame(width: lineWidth, height: segmentLength)
          Color.clear
            .frame(width: lineWidth, height: circleDiameter)
          Rectangle()
            .fill(strokeColor)
            .frame(width: lineWidth, height: segmentLength)
        }

        HStack(spacing: 0) {
          Rectangle()
            .fill(strokeColor)
            .frame(width: segmentLength, height: lineWidth)
          Color.clear
            .frame(width: circleDiameter, height: lineWidth)
          Rectangle()
            .fill(strokeColor)
            .frame(width: segmentLength, height: lineWidth)
        }

        Circle()
          .stroke(strokeColor, lineWidth: lineWidth)
          .frame(width: circleDiameter, height: circleDiameter)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
