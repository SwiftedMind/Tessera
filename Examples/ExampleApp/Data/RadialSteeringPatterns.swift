// By Dennis Müller

import SwiftUI
import Tessera

extension DemoConfigurations {
  static var organicRadialScale: Pattern {
    Pattern(
      symbols: DemoSymbols.organic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 203,
          minimumSpacing: 6,
          density: 0.6,
          baseScaleRange: 0.9...1.05,
          maximumSymbolCount: 220,
          steering: .init(
            scaleMultiplier: .radial(
              values: 0.75...1.45,
              center: .center,
              radius: .shortestSideFraction(0.58),
              easing: .smoothStep,
            ),
          ),
        ),
      ),
    )
  }

  static var gridRadialRotation: Pattern {
    Pattern(
      symbols: DemoSymbols.rotationBars,
      placement: .grid(
        TesseraPlacement.Grid(
          sizing: .count(columns: 9, rows: 9),
          seed: 303,
          steering: .init(
            rotationOffsetDegrees: .radial(
              values: 0...32,
              center: .center,
              radius: .autoFarthestCorner,
              easing: .easeInOut,
            ),
          ),
          showsGridOverlay: true,
        ),
      ),
    )
  }
}
