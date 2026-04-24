// By Dennis Müller

import SwiftUI

extension DemoDestination {
  @ViewBuilder
  func makeView() -> some View {
    switch self {
    case .tiledCanvas:
      tiledCanvasView()
    case .finiteCanvas:
      finiteCanvasView()
    case .mosaicCanvas:
      mosaicCanvasView()
    case .mosaicSnapshot:
      mosaicSnapshotView()
    case .gridPlacement:
      gridPlacementView()
    case .fixedCellGrid:
      fixedCellGridView()
    case .gridColumnMajor:
      gridColumnMajorView()
    case .gridSubgrids:
      gridSubgridsView()
    case .denseOrganic:
      denseOrganicView()
    case .denseOrganicRegion:
      denseOrganicRegionView()
    case .choiceSymbols:
      choiceSymbolsView()
    case .choiceIndexSequence:
      choiceIndexSequenceView()
    case .polygonRegion:
      polygonRegionView()
    case .alphaMaskRegion:
      alphaMaskRegionView()
    case .organicSpacingGradient:
      organicSpacingGradientView()
    case .organicScaleGradient:
      organicScaleGradientView()
    case .gridScaleGradient:
      gridScaleGradientView()
    case .organicRadialScale:
      organicRadialScaleView()
    case .organicRotationGradient:
      organicRotationGradientView()
    case .gridRadialRotation:
      gridRadialRotationView()
    case .gridRotationGradient:
      gridRotationGradientView()
    case .collisionShapeEditor:
      collisionShapeEditorView()
    }
  }
}
