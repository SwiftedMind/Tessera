import SwiftUI

/// Renders a single tessera tile into a cached symbol.
struct TesseraCanvasTile: View {
  var tessera: Tessera
  var seed: UInt64

  var body: some View {
    Canvas { context, size in
      var randomGenerator = SeededGenerator(seed: seed)
      let exclusionRadius = tessera.minimumSpacing * 1.1

      let points = PoissonDiskGenerator.makePoints(
        in: size,
        minimumSpacing: tessera.minimumSpacing,
        fillProbability: tessera.fillProbability,
        randomGenerator: &randomGenerator
      )

      let assignedItems = ItemAssigner.assignItems(
        to: points,
        in: size,
        items: tessera.items,
        exclusionRadius: exclusionRadius,
        randomGenerator: &randomGenerator
      )

      for (point, item) in zip(points, assignedItems) {
        guard let symbol = context.resolveSymbol(id: item.id) else { continue }

        let rotation = randomAngle(in: item.allowedRotationRange, using: &randomGenerator)
        let scaleRange = item.scaleRange ?? tessera.baseScaleRange
        let scale = CGFloat.random(in: scaleRange, using: &randomGenerator)

        // 3x3 offsets for toroidal wrap
        let offsets: [CGSize] = [
          .zero,
          CGSize(width: size.width, height: 0),
          CGSize(width: -size.width, height: 0),
          CGSize(width: 0, height: size.height),
          CGSize(width: 0, height: -size.height),
          CGSize(width: size.width, height: size.height),
          CGSize(width: size.width, height: -size.height),
          CGSize(width: -size.width, height: size.height),
          CGSize(width: -size.width, height: -size.height),
        ]

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width, y: offset.height)
          symbolContext.translateBy(x: point.x, y: point.y)
          symbolContext.rotate(by: rotation)
          symbolContext.scaleBy(x: scale, y: scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(tessera.items) { item in
        item.makeView().tag(item.id)
      }
    }
    .frame(width: tessera.size.width, height: tessera.size.height)
  }

  private func randomAngle(
    in range: ClosedRange<Angle>,
    using randomGenerator: inout some RandomNumberGenerator
  ) -> Angle {
    let lower = range.lowerBound.degrees
    let upper = range.upperBound.degrees
    return .degrees(Double.random(in: lower..<upper, using: &randomGenerator))
  }
}
