// By Dennis Müller

import SwiftUI

/// A view that repeats a tessera tile to fill the available space by tiling a single generated tile.
public struct TesseraTiledCanvas: View {
  /// Pattern configuration used to generate symbol placements.
  public var configuration: TesseraConfiguration
  /// Output size of each repeated tile.
  public var tileSize: CGSize
  /// Seed used for deterministic placement.
  public var seed: UInt64
  /// Controls whether the underlying SwiftUI canvas renders asynchronously.
  public var rendersAsynchronously: Bool
  /// Callback that reports whether placement computation is currently running.
  public var onComputationStateChange: ((Bool) -> Void)?

  /// Creates a tiled tessera canvas view.
  /// - Parameters:
  ///   - configuration: The tessera configuration to render.
  ///   - tileSize: Size of the tile that will be repeated.
  ///   - seed: Optional seed override for placement randomness.
  ///   - rendersAsynchronously: Whether the SwiftUI canvas renders asynchronously. Defaults to `false` to keep
  ///     interactive transforms in sync.
  public init(
    _ configuration: TesseraConfiguration,
    tileSize: CGSize,
    seed: UInt64? = nil,
    rendersAsynchronously: Bool = false,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.tileSize = tileSize
    self.seed = seed ?? configuration.placementSeed ?? TesseraConfiguration.randomSeed()
    self.rendersAsynchronously = rendersAsynchronously
    self.onComputationStateChange = onComputationStateChange
  }

  /// Renders repeated tiles to fill all available layout space.
  public var body: some View {
    let rendersAsynchronously = rendersAsynchronously

    // Default to synchronous rendering to avoid stale-frame flashes during interactive transforms.
    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: rendersAsynchronously) { context, size in
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
      TesseraCanvasTile(
        configuration: configuration,
        tileSize: tileSize,
        seed: seed,
        rendersAsynchronously: rendersAsynchronously,
        onComputationStateChange: onComputationStateChange,
      )
      .frame(width: tileSize.width, height: tileSize.height)
      .tag(0)
    }
  }
}

public extension TesseraTiledCanvas {
  /// Returns a copy that controls whether the SwiftUI canvas renders asynchronously.
  func rendersAsynchronously(_ value: Bool) -> TesseraTiledCanvas {
    var copy = self
    copy.rendersAsynchronously = value
    return copy
  }
}
