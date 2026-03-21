// By Dennis Müller

import CoreGraphics
import SwiftUI
import Tessera

enum DemoConfigurations {
  static var organic: Pattern {
    Pattern(
      symbols: DemoSymbols.organic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 0,
          minimumSpacing: 7,
          density: 0.62,
          baseScaleRange: 0.75...1.1,
          maximumSymbolCount: 220,
        ),
      ),
    )
  }

  static var grid: Pattern {
    Pattern(
      symbols: DemoSymbols.fixedCellClipping,
      placement: .grid(
        TesseraPlacement.Grid(
          sizing: .square(58, origin: CGPoint(x: -24, y: -24)),
          showsGridOverlay: true,
        ),
      ),
    )
  }

  static var gridColumnMajor: Pattern {
    Pattern(
      symbols: [.gridCross, .gridCrossRotated, .subgridDot],
      placement: .grid(
        TesseraPlacement.Grid(
          sizing: .count(columns: 7, rows: 5),
          symbolOrder: .columnMajor,
          seed: 314,
          showsGridOverlay: true,
        ),
      ),
    )
  }

  static var gridSubgrids: Pattern {
    Pattern(
      symbols: DemoSymbols.gridSubgrids,
      placement: .grid(
        TesseraPlacement.Grid(
          sizing: .count(columns: 10, rows: 10),
          symbolOrder: .rowMajor,
          seed: 222,
          showsGridOverlay: true,
          subgrids: [
            .init(
              at: .init(row: 2, column: 2),
              spanning: .init(rows: 2, columns: 2),
              symbols: [.subgridMiniDot],
              symbolOrder: .columnMajor,
              grid: .init(
                sizing: .count(columns: 10, rows: 10),
                offsetStrategy: .rowShift(fraction: 0.5),
                symbolOrder: .shuffle,
                seed: 1202,
              ),
            ),
            .init(
              at: .init(row: 2, column: 4),
              spanning: .init(rows: 2, columns: 3),
              symbols: [.subgridDiamond],
              symbolOrder: .rowMajor,
            ),
            .init(
              at: .init(row: 5, column: 1),
              spanning: .init(rows: 3, columns: 2),
              symbols: [.subgridDiamond],
              symbolOrder: .snake,
            ),
            .init(
              at: .init(row: 6, column: 6),
              spanning: .init(rows: 3, columns: 3),
              symbols: [.subgridDiamond],
              symbolOrder: .shuffle,
              grid: .init(
                sizing: .count(columns: 1, rows: 1),
              ),
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
          minimumSpacing: 6,
          density: 0.58,
          baseScaleRange: 0.75...1.05,
          maximumSymbolCount: 160,
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
          minimumSpacing: 5,
          density: 0.6,
          baseScaleRange: 0.75...1.1,
          maximumSymbolCount: 175,
        ),
      ),
    )
  }

  static var mosaicSnapshot: Pattern {
    Pattern(
      symbols: DemoSymbols.organic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 2602,
          minimumSpacing: 10,
          density: 0.42,
          baseScaleRange: 0.75...1.05,
          maximumSymbolCount: 120,
        ),
      ),
      mosaics: [
        Mosaic(
          mask: MosaicMask(
            symbol: .mosaicMaskBlob,
            position: .centered(offset: CGSize(width: -90, height: -40)),
            rotation: .degrees(-12),
            scale: 1.05,
          ),
          symbols: DemoSymbols.mosaicCore,
          placement: .grid(
            TesseraPlacement.Grid(
              sizing: .count(columns: 10, rows: 10),
              symbolOrder: .rowMajor,
              seed: 2603,
            ),
          ),
          rendering: .clipped,
        ),
        Mosaic(
          mask: MosaicMask(
            symbol: .mosaicMaskDiamond,
            position: .centered(offset: CGSize(width: 118, height: 88)),
            rotation: .degrees(10),
            scale: 0.95,
          ),
          symbols: DemoSymbols.mosaicAccent,
          placement: .organic(
            TesseraPlacement.Organic(
              seed: 2604,
              minimumSpacing: 7,
              density: 0.58,
              baseScaleRange: 0.85...1.5,
              maximumSymbolCount: 100,
            ),
          ),
          rendering: .clipped,
        ),
      ],
    )
  }

  static var organicSpacingGradient: Pattern {
    Pattern(
      symbols: DemoSymbols.mosaic,
      placement: .organic(
        TesseraPlacement.Organic(
          seed: 21,
          minimumSpacing: 10,
          density: 0.58,
          baseScaleRange: 0.85...1.05,
          maximumSymbolCount: 190,
          steering: .init(
            minimumSpacingMultiplier: .init(
              values: 0.35...1.8,
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
          minimumSpacing: 6,
          density: 0.6,
          baseScaleRange: 0.85...1.05,
          maximumSymbolCount: 220,
          steering: .init(
            scaleMultiplier: .init(
              values: 0.65...1.45,
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
          sizing: .count(columns: 8, rows: 8),
          seed: 55,
          steering: .init(
            scaleMultiplier: .init(
              values: 0.65...1.25,
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
          minimumSpacing: 12,
          density: 0.5,
          baseScaleRange: 0.9...1.0,
          maximumSymbolCount: 140,
          steering: .init(
            rotationOffsetDegrees: .init(
              values: 0...140,
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
          sizing: .count(columns: 8, rows: 8),
          seed: 121,
          steering: .init(
            rotationMultiplier: .init(
              values: 0.7...1.3,
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
