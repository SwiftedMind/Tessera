// By Dennis Müller

import SwiftUI

/// A view that repeats a tessera tile to fill the available space.
public struct TesseraPattern: View {
  public var tessera: Tessera
  public var seed: UInt64

  /// Creates a tessera pattern view.
  /// - Parameters:
  ///   - tessera: The tessera configuration to render.
  ///   - seed: Optional seed overriding the tessera's seed for this view instance.
  public init(_ tessera: Tessera, seed: UInt64? = nil) {
    self.tessera = tessera
    self.seed = seed ?? tessera.seed
  }

  public var body: some View {
    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
      guard let tile = context.resolveSymbol(id: 0) else { return }

      let columns = Int(ceil(size.width / tessera.size.width))
      let rows = Int(ceil(size.height / tessera.size.height))

      for row in 0..<rows {
        for column in 0..<columns {
          let x = CGFloat(column) * tessera.size.width + tessera.size.width / 2
          let y = CGFloat(row) * tessera.size.height + tessera.size.height / 2
          context.draw(tile, at: CGPoint(x: x, y: y), anchor: .center)
        }
      }
    } symbols: {
      TesseraCanvasTile(tessera: tessera, seed: seed)
        .frame(width: tessera.size.width, height: tessera.size.height)
        .tag(0)
    }
  }
}
