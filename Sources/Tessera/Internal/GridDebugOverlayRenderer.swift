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
    for column in resolvedGrid.columnRange.lowerBound...resolvedGrid.columnRange.upperBound {
      let x = resolvedGrid.x(forLatticeColumn: column)
      baseGridPath.move(to: CGPoint(x: x, y: 0))
      baseGridPath.addLine(to: CGPoint(x: x, y: size.height))
    }
    for row in resolvedGrid.rowRange.lowerBound...resolvedGrid.rowRange.upperBound {
      let y = resolvedGrid.y(forLatticeRow: row)
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
        x: resolvedGrid.x(forLatticeColumn: subgrid.visibleColumnRange.lowerBound),
        y: resolvedGrid.y(forLatticeRow: subgrid.visibleRowRange.lowerBound),
        width: CGFloat(subgrid.visibleColumnRange.count) * cellSize.width,
        height: CGFloat(subgrid.visibleRowRange.count) * cellSize.height,
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
