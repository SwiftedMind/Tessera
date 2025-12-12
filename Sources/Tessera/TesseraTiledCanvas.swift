// By Dennis Müller

import SwiftUI

/// A view that repeats a tessera tile to fill the available space by tiling a single generated tile.
public struct TesseraTiledCanvas: View {
  public var configuration: TesseraConfiguration
  public var tileSize: CGSize
  public var seed: UInt64

  /// Creates a tiled tessera canvas view.
  /// - Parameters:
  ///   - configuration: The tessera configuration to render.
  ///   - tileSize: Size of the tile that will be repeated.
  ///   - seed: Optional seed overriding the configuration's seed for this view instance.
  public init(
    _ configuration: TesseraConfiguration,
    tileSize: CGSize,
    seed: UInt64? = nil,
  ) {
    self.configuration = configuration
    self.tileSize = tileSize
    self.seed = seed ?? configuration.seed
  }

  public var body: some View {
    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
      guard let tile = context.resolveSymbol(id: 0) else { return }

      let columns = Int(ceil(size.width / tileSize.width))
      let rows = Int(ceil(size.height / tileSize.height))

      for row in 0..<rows {
        for column in 0..<columns {
          let x = CGFloat(column) * tileSize.width + tileSize.width / 2
          let y = CGFloat(row) * tileSize.height + tileSize.height / 2
          context.draw(tile, at: CGPoint(x: x, y: y), anchor: .center)
        }
      }
    } symbols: {
      TesseraCanvasTile(configuration: configuration, tileSize: tileSize, seed: seed)
        .frame(width: tileSize.width, height: tileSize.height)
        .tag(0)
    }
  }
}
