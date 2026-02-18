// By Dennis Müller

import SwiftUI
import Tessera

extension DemoDestination {
  @ViewBuilder
  func tiledCanvasView() -> some View {
    DemoExampleScreen(title: "Tiled Canvas") {
      Tessera(DemoConfigurations.organic)
        .mode(.tiled(tileSize: CGSize(width: 256, height: 256)))
        .seed(.fixed(0))
    }
  }

  @ViewBuilder
  func finiteCanvasView() -> some View {
    DemoExampleScreen(title: "Finite Canvas") {
      Tessera(DemoConfigurations.organic)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(0))
        .pinnedSymbols(DemoPinnedSymbols.hero)
        .background(.black)
    }
  }

  @ViewBuilder
  func gridPlacementView() -> some View {
    DemoExampleScreen(title: "Grid Placement") {
      InterleavedGridCanvas()
    }
  }

  @ViewBuilder
  func mergedGridCellsView() -> some View {
    DemoExampleScreen(title: "Merged Grid Cells") {
      Tessera(DemoConfigurations.gridMergedCells)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(222))
        .background(.black)
    }
  }

  @ViewBuilder
  func choiceSymbolsView() -> some View {
    ChoiceSymbolsExampleView()
  }

  @ViewBuilder
  func choiceIndexSequenceView() -> some View {
    ChoiceIndexSequenceExampleView()
  }

  @ViewBuilder
  func polygonRegionView() -> some View {
    DemoExampleScreen(title: "Polygon Region") {
      Tessera(DemoConfigurations.polygon)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(14))
        .region(DemoRegions.mosaic)
        .regionRendering(.unclipped)
        .background(.black)
    }
  }

  @ViewBuilder
  func alphaMaskRegionView() -> some View {
    DemoExampleScreen(title: "Alpha Mask Region") {
      Tessera(DemoConfigurations.alphaMask)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(7))
        .region(DemoExampleAssets.alphaMaskRegion)
        .regionRendering(.clipped)
        .background(.black)
    }
  }
}
