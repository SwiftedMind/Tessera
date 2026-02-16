// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Draws debug overlays for grid placement.
enum GridDebugOverlayRenderer {
  static func draw(
    in context: inout GraphicsContext,
    size: CGSize,
    configuration: PlacementModel.Grid,
    edgeBehavior: TesseraEdgeBehavior,
    patternOffset: CGSize = .zero,
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

    let mergedCells = GridShapePlacementEngine.resolvePlacementCells(
      mergedCells: configuration.mergedCells,
      grid: resolvedGrid,
    ).filter { resolvedCell in
      resolvedCell.rowSpan > 1 || resolvedCell.columnSpan > 1
    }
    guard mergedCells.isEmpty == false else { return }

    var mergedFillPath = Path()
    var mergedStrokePath = Path()
    for mergedCell in mergedCells {
      let rectangle = CGRect(
        x: CGFloat(mergedCell.columnIndex) * cellSize.width,
        y: CGFloat(mergedCell.rowIndex) * cellSize.height,
        width: CGFloat(mergedCell.columnSpan) * cellSize.width,
        height: CGFloat(mergedCell.rowSpan) * cellSize.height,
      )
      mergedFillPath.addRect(rectangle)
      mergedStrokePath.addRect(rectangle)
    }

    for wrapOffset in wrapOffsets {
      let translation = CGAffineTransform(
        translationX: wrapOffset.x + wrappedOffset.width,
        y: wrapOffset.y + wrappedOffset.height,
      )
      context.fill(mergedFillPath.applying(translation), with: .color(.yellow.opacity(0.08)))
      context.stroke(
        mergedStrokePath.applying(translation),
        with: .color(.yellow.opacity(0.75)),
        style: StrokeStyle(lineWidth: 2),
      )
    }
  }
}
