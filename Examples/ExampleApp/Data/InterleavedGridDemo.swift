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
    Symbol(
      id: InterleavedGridSymbolIDs.primary,
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.circle(center: .zero, radius: 13)),
    ) {
      Circle()
        .stroke(DemoPalette.blue.opacity(0.9), lineWidth: 3)
        .frame(width: 24, height: 24)
    }
  }

  static var interleavedGridSecondary: Symbol {
    Symbol(
      id: InterleavedGridSymbolIDs.secondary,
      rotation: .degrees(0)...(.degrees(0)),
      collider: .shape(.rectangle(center: .zero, size: CGSize(width: 14, height: 14))),
    ) {
      RoundedRectangle(cornerRadius: 3, style: .continuous)
        .fill(DemoPalette.amber.opacity(0.88))
        .frame(width: 12, height: 12)
    }
  }
}

struct InterleavedGridCanvas: View {
  var body: some View {
    ZStack {
      DemoPalette.canvasBackground

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
}

private enum InterleavedGridSymbolIDs {
  static let primary = UUID(uuidString: "3AA5E7C7-E610-41AA-B647-C83B0A98720B")!
  static let secondary = UUID(uuidString: "845731F3-85D7-4313-8FA9-C8B95DDF3E8F")!
}
