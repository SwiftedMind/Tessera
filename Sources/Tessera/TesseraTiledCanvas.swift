// By Dennis Müller

import Foundation
import SwiftUI

/// A view that repeats a tessera tile to fill the available space by tiling a single generated tile.
public struct TesseraTiledCanvas: View {
  private struct TileResolutionID: Hashable, Sendable {
    var renderID: UUID?
  }

  public var configuration: TesseraConfiguration
  public var tileSize: CGSize
  public var seed: UInt64
  public var onComputationStateChange: ((Bool) -> Void)?
  @State private var renderTick: UInt64 = 0

  /// Creates a tiled tessera canvas view.
  /// - Parameters:
  ///   - configuration: The tessera configuration to render.
  ///   - tileSize: Size of the tile that will be repeated.
  ///   - seed: Optional seed override for organic placement.
  public init(
    _ configuration: TesseraConfiguration,
    tileSize: CGSize,
    seed: UInt64? = nil,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.tileSize = tileSize
    self.seed = seed ?? configuration.organicPlacement?.seed ?? TesseraConfiguration.randomSeed()
    self.onComputationStateChange = onComputationStateChange
  }

  public var body: some View {
    let renderTickValue = renderTick
    let tileID = TileResolutionID(renderID: configuration.renderID)

    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
      _ = renderTickValue
      guard let tile = context.resolveSymbol(id: tileID) else { return }

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
      TesseraCanvasTile(
        configuration: configuration,
        tileSize: tileSize,
        seed: seed,
        onComputationStateChange: onComputationStateChange,
      )
      .frame(width: tileSize.width, height: tileSize.height)
      .tag(tileID)
    }
    .task(id: configuration.renderID) {
      await MainActor.run {
        renderTick &+= 1
      }
    }
  }
}
