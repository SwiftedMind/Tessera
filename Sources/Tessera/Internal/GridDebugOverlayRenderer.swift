// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// Draws debug overlays for grid placement.
enum GridDebugOverlayRenderer {
  static func draw(
    in context: inout GraphicsContext,
    size: CGSize,
    configuration: PlacementModel.Grid,
    edgeBehavior: TesseraEdgeBehavior,
    patternOffset: CGSize = .zero,
    knownSymbolIDs: Set<UUID>? = nil,
  ) {
    guard size.width > 0, size.height > 0 else { return }

    let wrappedOffset = CGSize(
      width: patternOffset.width.truncatingRemainder(dividingBy: size.width),
      height: patternOffset.height.truncatingRemainder(dividingBy: size.height),
    )
    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: size, edgeBehavior: edgeBehavior)

    let resolvedGrid = GridShapePlacementEngine.resolveGrid(
      for: size,
      configuration: configuration,
      edgeBehavior: edgeBehavior,
    )
    let cellSize = resolvedGrid.cellSize

    var baseGridPath = Path()
    for column in 0...resolvedGrid.columnCount {
      let x = CGFloat(column) * cellSize.width
      baseGridPath.move(to: CGPoint(x: x, y: 0))
      baseGridPath.addLine(to: CGPoint(x: x, y: size.height))
    }
    for row in 0...resolvedGrid.rowCount {
      let y = CGFloat(row) * cellSize.height
      baseGridPath.move(to: CGPoint(x: 0, y: y))
      baseGridPath.addLine(to: CGPoint(x: size.width, y: y))
    }

    for wrapOffset in wrapOffsets {
      let translation = CGAffineTransform(
        translationX: wrapOffset.x + wrappedOffset.width,
        y: wrapOffset.y + wrappedOffset.height,
      )
      context.stroke(
        baseGridPath.applying(translation),
        with: .color(.white.opacity(0.28)),
        style: StrokeStyle(lineWidth: 1, dash: [4, 4]),
      )
    }

    let subgrids = GridShapePlacementEngine.resolveAcceptedSubgridAreas(
      subgrids: configuration.subgrids,
      grid: resolvedGrid,
      knownSymbolIDs: knownSymbolIDs,
    )
    guard subgrids.isEmpty == false else { return }

    var subgridFillPath = Path()
    var subgridStrokePath = Path()
    for subgrid in subgrids {
      let rectangle = CGRect(
        x: CGFloat(subgrid.columnIndex) * cellSize.width,
        y: CGFloat(subgrid.rowIndex) * cellSize.height,
        width: CGFloat(subgrid.columnCount) * cellSize.width,
        height: CGFloat(subgrid.rowCount) * cellSize.height,
      )
      subgridFillPath.addRect(rectangle)
      subgridStrokePath.addRect(rectangle)
    }

    for wrapOffset in wrapOffsets {
      let translation = CGAffineTransform(
        translationX: wrapOffset.x + wrappedOffset.width,
        y: wrapOffset.y + wrappedOffset.height,
      )
      context.fill(subgridFillPath.applying(translation), with: .color(.cyan.opacity(0.08)))
      context.stroke(
        subgridStrokePath.applying(translation),
        with: .color(.cyan.opacity(0.75)),
        style: StrokeStyle(lineWidth: 2),
      )
    }
  }
}
