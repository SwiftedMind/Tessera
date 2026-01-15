// By Dennis Müller

import CoreGraphics
import Foundation

extension ShapePlacementEngine {
  /// Describes a symbol that can be placed, including its collision metadata.
  struct PlacementSymbolDescriptor: Sendable {
    /// The unique identifier for the symbol.
    var id: UUID
    /// The selection weight used by organic placement.
    var weight: Double
    /// The allowed rotation range, expressed in degrees.
    var allowedRotationRangeDegrees: ClosedRange<Double>
    /// The resolved scale range for the current placement mode.
    var resolvedScaleRange: ClosedRange<Double>
    /// The collision shape used for overlap testing.
    var collisionShape: CollisionShape
  }

  /// Describes a symbol that must appear at a fixed position.
  struct PinnedSymbolDescriptor: Sendable {
    /// The unique identifier for the symbol.
    var id: UUID
    /// The fixed position within the tile.
    var position: CGPoint
    /// The fixed rotation in radians.
    var rotationRadians: Double
    /// The fixed scale to apply.
    var scale: CGFloat
    /// The collision shape used for overlap testing.
    var collisionShape: CollisionShape
  }

  /// Represents a symbol that has been accepted into the tile.
  struct PlacedSymbolDescriptor: Sendable {
    /// The identifier of the placed symbol.
    var symbolId: UUID
    /// The final position of the symbol in tile coordinates.
    var position: CGPoint
    /// The final rotation in radians.
    var rotationRadians: Double
    /// The final scale of the symbol.
    var scale: CGFloat
    /// The collision shape used for overlap testing.
    var collisionShape: CollisionShape

    /// The collision transform derived from the placement values.
    var collisionTransform: CollisionTransform {
      CollisionTransform(
        position: position,
        rotation: CGFloat(rotationRadians),
        scale: scale,
      )
    }
  }

  /// Stores collision data for a placed symbol to speed up overlap checks.
  struct PlacedCollider: Sendable {
    /// The collision shape used for overlap testing.
    var collisionShape: CollisionShape
    /// The transform to apply when testing collisions.
    var collisionTransform: CollisionTransform
    /// The precomputed polygons for the collision shape.
    var polygons: [CollisionPolygon]
    /// The maximum radius of the shape at the applied scale.
    var boundingRadius: CGFloat
  }

  /// Identifies a cell in the spatial grid used by organic placement.
  struct CellCoordinate: Hashable, Sendable {
    /// The column index in the spatial grid.
    var column: Int
    /// The row index in the spatial grid.
    var row: Int
  }

  /// Stores the resolved grid dimensions and derived cell size.
  struct ResolvedGrid: Sendable {
    /// The number of columns in the resolved grid.
    var columnCount: Int
    /// The number of rows in the resolved grid.
    var rowCount: Int
    /// The size of each resolved cell in points.
    var cellSize: CGSize

    /// The total number of cells in the resolved grid.
    var totalCellCount: Int {
      columnCount * rowCount
    }
  }
}
