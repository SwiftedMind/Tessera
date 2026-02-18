// By Dennis Müller

import Tessera

enum DemoConfigurations {
  static var organic: Pattern {
    Pattern(
      symbols: DemoSymbols.organic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 0,
          minimumSpacing: 0,
          density: 0.8,
          baseScaleRange: 0.5...1.2,
        ),
      ),
    )
  }

  static var grid: Pattern {
    Pattern(
      symbols: DemoSymbols.grid,
      placement: .grid(
        TesseraPlacement.Grid(
          columnCount: 6,
          rowCount: 6,
          offsetStrategy: .rowShift(fraction: 0.5),
          showsGridOverlay: true,
        ),
      ),
    )
  }

  static var gridMergedCells: Pattern {
    Pattern(
      symbols: DemoSymbols.gridMergedCells,
      placement: .grid(
        TesseraPlacement.Grid(
          columnCount: 10,
          rowCount: 10,
          symbolOrder: .sequence,
          seed: 222,
          showsGridOverlay: true,
          mergedCells: [
            .init(
              at: .init(row: 2, column: 2),
              spanning: .init(rows: 2, columns: 2),
              symbol: .mergedCellDiamond,
              symbolSizing: .fitMergedCell,
            ),
            .init(
              at: .init(row: 2, column: 4),
              spanning: .init(rows: 2, columns: 3),
              symbol: .mergedCellDiamond,
              symbolSizing: .fitMergedCell,
            ),
            .init(
              at: .init(row: 5, column: 1),
              spanning: .init(rows: 3, columns: 2),
              symbol: .mergedCellDiamond,
              symbolSizing: .fitMergedCell,
            ),
            .init(
              at: .init(row: 6, column: 6),
              spanning: .init(rows: 3, columns: 3),
              symbol: .mergedCellDiamond,
              symbolSizing: .fitMergedCell,
            ),
          ],
        ),
      ),
    )
  }

  static var polygon: Pattern {
    Pattern(
      symbols: DemoSymbols.mosaic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 14,
          minimumSpacing: 2,
          density: 0.7,
          baseScaleRange: 0.6...1.1,
          maximumSymbolCount: 220,
        ),
      ),
    )
  }

  static var alphaMask: Pattern {
    Pattern(
      symbols: DemoSymbols.mosaic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 7,
          minimumSpacing: 2,
          density: 0.75,
          baseScaleRange: 0.6...1.2,
          maximumSymbolCount: 240,
        ),
      ),
    )
  }

  static var organicSpacingGradient: Pattern {
    Pattern(
      symbols: DemoSymbols.mosaic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 21,
          minimumSpacing: 7,
          density: 0.85,
          baseScaleRange: 0.8...1.15,
          maximumSymbolCount: 280,
          steering: .init(
            minimumSpacingMultiplier: .init(
              values: 0.25...2.0,
              from: .top,
              to: .bottom,
              easing: .smoothStep,
            ),
          ),
        ),
      ),
    )
  }

  static var organicScaleGradient: Pattern {
    Pattern(
      symbols: DemoSymbols.organic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 34,
          minimumSpacing: 3,
          density: 0.85,
          baseScaleRange: 0.8...1.15,
          maximumSymbolCount: 320,
          steering: .init(
            scaleMultiplier: .init(
              values: 0.55...1.7,
              from: .leading,
              to: .trailing,
              easing: .easeInOut,
            ),
          ),
        ),
      ),
    )
  }

  static var gridScaleGradient: Pattern {
    Pattern(
      symbols: DemoSymbols.grid,
      placement: .grid(
        TesseraPlacement.Grid(
          columnCount: 8,
          rowCount: 8,
          seed: 55,
          steering: .init(
            scaleMultiplier: .init(
              values: 0.5...1.2,
              from: .topLeading,
              to: .bottomTrailing,
              easing: .smoothStep,
            ),
          ),
          showsGridOverlay: true,
        ),
      ),
    )
  }

  static var organicRotationGradient: Pattern {
    Pattern(
      symbols: DemoSymbols.rotationBars,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 89,
          minimumSpacing: 10,
          density: 0.7,
          baseScaleRange: 0.9...1.1,
          maximumSymbolCount: 180,
          steering: .init(
            rotationOffsetDegrees: .init(
              values: 0...180,
              from: .top,
              to: .bottom,
              easing: .linear,
            ),
          ),
        ),
      ),
    )
  }

  static var gridRotationGradient: Pattern {
    Pattern(
      symbols: DemoSymbols.rotationBars,
      placement: .grid(
        TesseraPlacement.Grid(
          columnCount: 8,
          rowCount: 8,
          seed: 121,
          steering: .init(
            rotationMultiplier: .init(
              values: 0.5...1.5,
              from: .leading,
              to: .trailing,
              easing: .linear,
            ),
          ),
          showsGridOverlay: true,
        ),
      ),
    )
  }
}
