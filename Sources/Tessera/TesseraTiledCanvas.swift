// By Dennis Müller

import SwiftUI

/// A view that repeats a tessera tile to fill the available space by tiling a single generated tile.
public struct TesseraTiledCanvas: View {
  public var configuration: TesseraConfiguration
  public var tileSize: CGSize
  public var seed: UInt64
  /// Controls whether the underlying SwiftUI canvas renders asynchronously.
  public var rendersAsynchronously: Bool
  /// Rotation applied to the tiled pattern in view space.
  ///
  /// This rotates the *tiling coordinate system* (translation lattice) so adjacent tiles remain edge-aligned.
  public var tileRotation: Angle
  /// Anchor used for rotating the tiling coordinate system in view space.
  public var tileRotationAnchor: UnitPoint
  public var onComputationStateChange: ((Bool) -> Void)?

  /// Creates a tiled tessera canvas view.
  /// - Parameters:
  ///   - configuration: The tessera configuration to render.
  ///   - tileSize: Size of the tile that will be repeated.
  ///   - seed: Optional seed override for placement randomness.
  ///   - rendersAsynchronously: Whether the SwiftUI canvas renders asynchronously. Defaults to `false` to keep
  ///     interactive transforms in sync.
  ///   - tileRotation: Rotation applied to the tiled pattern in view space.
  ///   - tileRotationAnchor: Anchor used for rotating the tiling coordinate system in view space.
  public init(
    _ configuration: TesseraConfiguration,
    tileSize: CGSize,
    seed: UInt64? = nil,
    rendersAsynchronously: Bool = false,
    tileRotation: Angle = .zero,
    tileRotationAnchor: UnitPoint = .center,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.tileSize = tileSize
    self.seed = seed ?? configuration.placementSeed ?? TesseraConfiguration.randomSeed()
    self.rendersAsynchronously = rendersAsynchronously
    self.tileRotation = tileRotation
    self.tileRotationAnchor = tileRotationAnchor
    self.onComputationStateChange = onComputationStateChange
  }

  public var body: some View {
    let rendersAsynchronously = rendersAsynchronously
    let rotationRadians = Self.normalizedRadians(tileRotation.radians)
    let rotationAnchor = tileRotationAnchor
    let tileSize = tileSize

    // Default to synchronous rendering to avoid stale-frame flashes during interactive transforms.
    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: rendersAsynchronously) { context, size in
      guard let tile = context.resolveSymbol(id: 0) else { return }
      guard tileSize.width > 0, tileSize.height > 0 else { return }
      guard size.width > 0, size.height > 0 else { return }

      if rotationRadians == 0 {
        let columns = Int(ceil(size.width / tileSize.width))
        let rows = Int(ceil(size.height / tileSize.height))

        for row in 0..<rows {
          for column in 0..<columns {
            let x = CGFloat(column) * tileSize.width + tileSize.width / 2
            let y = CGFloat(row) * tileSize.height + tileSize.height / 2
            context.draw(tile, at: CGPoint(x: x, y: y), anchor: .center)
          }
        }

        return
      }

      let anchor = CGPoint(
        x: size.width * rotationAnchor.x,
        y: size.height * rotationAnchor.y,
      )

      let inverseBounds = RotationMath.inverseRotatedTileBounds(
        tileSize: size,
        anchor: anchor,
        rotationRadians: rotationRadians,
      )

      var columnRange = RotationMath.indexRangeCoveringBounds(
        min: inverseBounds.minX,
        max: inverseBounds.maxX,
        cellSize: tileSize.width,
      )
      var rowRange = RotationMath.indexRangeCoveringBounds(
        min: inverseBounds.minY,
        max: inverseBounds.maxY,
        cellSize: tileSize.height,
      )

      // Draw an extra ring to avoid under-coverage and hide hairline seams.
      columnRange = (columnRange.lowerBound - 1)...(columnRange.upperBound + 1)
      rowRange = (rowRange.lowerBound - 1)...(rowRange.upperBound + 1)

      columnRange = RotationMath.clampedIndexRange(columnRange, maximumCount: 4096)
      rowRange = RotationMath.clampedIndexRange(rowRange, maximumCount: 4096)

      var viewport = Path()
      viewport.addRect(CGRect(origin: .zero, size: size))
      let maximumTileDrawCount = 250_000
      let columnCount = max(1, columnRange.upperBound - columnRange.lowerBound + 1)
      let rowCount = max(1, rowRange.upperBound - rowRange.lowerBound + 1)
      let totalTileDrawCount = columnCount * rowCount
      if totalTileDrawCount > maximumTileDrawCount {
        let clamped = Self.clampedRangesForMaximumTotalCells(
          columnRange: columnRange,
          rowRange: rowRange,
          maximumTotalCells: maximumTileDrawCount,
        )
        columnRange = clamped.columnRange
        rowRange = clamped.rowRange
      }

      context.drawLayer { layer in
        layer.clip(to: viewport)
        layer.translateBy(x: anchor.x, y: anchor.y)
        layer.rotate(by: .radians(rotationRadians))
        layer.translateBy(x: -anchor.x, y: -anchor.y)

        for row in rowRange {
          let y = (CGFloat(row) + 0.5) * tileSize.height
          for column in columnRange {
            let x = (CGFloat(column) + 0.5) * tileSize.width
            layer.draw(tile, at: CGPoint(x: x, y: y), anchor: .center)
          }
        }
      }
    } symbols: {
      TesseraCanvasTile(
        configuration: configuration,
        tileSize: tileSize,
        seed: seed,
        rendersAsynchronously: rendersAsynchronously,
        onComputationStateChange: onComputationStateChange,
      )
      .frame(width: tileSize.width, height: tileSize.height)
      .tag(0)
    }
  }
}

public extension TesseraTiledCanvas {
  /// Returns a copy that controls whether the SwiftUI canvas renders asynchronously.
  func rendersAsynchronously(_ value: Bool) -> TesseraTiledCanvas {
    var copy = self
    copy.rendersAsynchronously = value
    return copy
  }

  /// Returns a copy that rotates the tiling coordinate system.
  ///
  /// Use this when you want the tiled pattern itself rotated in view space. This differs from applying
  /// `.rotationEffect(...)` to the view, which rotates the final rendered result instead of the translation lattice.
  func tileRotation(_ angle: Angle, anchor: UnitPoint = .center) -> TesseraTiledCanvas {
    var copy = self
    copy.tileRotation = angle
    copy.tileRotationAnchor = anchor
    return copy
  }
}

private extension TesseraTiledCanvas {
  static func normalizedRadians(_ radians: Double) -> Double {
    let twoPi = Double.pi * 2
    let remainder = radians.truncatingRemainder(dividingBy: twoPi)
    return abs(remainder) < 1e-12 ? 0 : remainder
  }

  struct TilingRanges: Sendable {
    var columnRange: ClosedRange<Int>
    var rowRange: ClosedRange<Int>
  }

  static func clampedRangesForMaximumTotalCells(
    columnRange: ClosedRange<Int>,
    rowRange: ClosedRange<Int>,
    maximumTotalCells: Int,
  ) -> TilingRanges {
    let columnCount = max(1, columnRange.upperBound - columnRange.lowerBound + 1)
    let rowCount = max(1, rowRange.upperBound - rowRange.lowerBound + 1)
    let total = columnCount * rowCount
    guard total > maximumTotalCells else {
      return TilingRanges(columnRange: columnRange, rowRange: rowRange)
    }

    let scale = sqrt(Double(maximumTotalCells) / Double(total))
    let clampedColumns = max(1, Int(Double(columnCount) * scale))
    let clampedRows = max(1, Int(Double(rowCount) * scale))
    return TilingRanges(
      columnRange: RotationMath.clampedIndexRange(columnRange, maximumCount: clampedColumns),
      rowRange: RotationMath.clampedIndexRange(rowRange, maximumCount: clampedRows),
    )
  }
}
