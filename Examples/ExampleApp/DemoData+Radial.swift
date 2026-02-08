// By Dennis Müller

import SwiftUI
import Tessera

extension DemoConfigurations {
  static var organicRadialScale: Pattern {
    Pattern(
      symbols: DemoSymbols.organic,
      placement: .organic(
        Placement.OrganicOptions(
          seed: 203,
          minimumSpacing: 4,
          density: 0.82,
          baseScaleRange: 0.85...1.1,
          maximumSymbolCount: 320,
          steering: .init(
            scaleMultiplier: .radial(
              values: 0.6...1.65,
              center: .center,
              radius: .shortestSideFraction(0.55),
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
        Placement.GridOptions(
          columnCount: 9,
          rowCount: 9,
          seed: 303,
          steering: .init(
            rotationOffsetDegrees: .radial(
              values: 0...42,
              center: .center,
              radius: .autoFarthestCorner,
              easing: .easeInOut,
            ),
          ),
        ),
      ),
    )
  }
}
