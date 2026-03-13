// By Dennis Müller

import CoreGraphics
import Foundation

extension ShapePlacementEngine {
  /// Describes a symbol that can be placed, including its collision metadata.
  struct PlacementSymbolDescriptor: Hashable, Sendable {
    /// Leaf metadata used when this node resolves to a renderable symbol.
    struct RenderDescriptor: Hashable, Sendable {
      /// The unique identifier for the renderable symbol.
      var id: UUID
      /// The allowed rotation range, expressed in degrees.
      var allowedRotationRangeDegrees: ClosedRange<Double>
      /// The resolved scale range for the current placement mode.
      var resolvedScaleRange: ClosedRange<Double>
      /// The collision shape used for overlap testing.
      var collisionShape: CollisionShape
    }

    /// The unique identifier for the symbol.
    var id: UUID
    /// The selection weight used by top-level symbol selection.
    var weight: Double
    /// Draw order for generated symbols. Lower values render behind higher values.
    var zIndex: Double
    /// The source-array position of the top-level symbol.
    var sourceOrder: Int
    /// The strategy used when `choices` is non-empty.
    var choiceStrategy: TesseraSymbolChoiceStrategy
    /// Optional seed salt mixed into choice resolution.
    var choiceSeed: UInt64?
    /// Leaf metadata for renderable symbols. `nil` for pure choice nodes.
    var renderDescriptor: RenderDescriptor?
    /// Child symbols used for nested choices.
    var choices: [PlacementSymbolDescriptor]

    /// Returns all renderable leaf descriptors in this subtree.
    var renderableLeafDescriptors: [RenderDescriptor] {
      if let renderDescriptor {
        return [renderDescriptor]
      }
      return choices.flatMap(\.renderableLeafDescriptors)
    }
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
    /// The identifier of the selected top-level symbol.
    var symbolId: UUID
    /// The identifier of the resolved render symbol (leaf choice).
    var renderSymbolId: UUID
    /// Draw order for generated symbols. Lower values render behind higher values.
    var zIndex: Double
    /// The source-array position of the top-level symbol.
    var sourceOrder: Int
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
    /// Local spacing requirement used for pairwise spacing checks.
    var minimumSpacing: CGFloat
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

extension ShapePlacementEngine.PlacementSymbolDescriptor {
  /// Convenience initializer for a non-choice (leaf) symbol descriptor.
  init(
    id: UUID,
    weight: Double,
    zIndex: Double = 0,
    sourceOrder: Int = 0,
    allowedRotationRangeDegrees: ClosedRange<Double>,
    resolvedScaleRange: ClosedRange<Double>,
    collisionShape: CollisionShape,
  ) {
    self.init(
      id: id,
      weight: weight,
      zIndex: zIndex,
      sourceOrder: sourceOrder,
      choiceStrategy: .weightedRandom,
      choiceSeed: nil,
      renderDescriptor: RenderDescriptor(
        id: id,
        allowedRotationRangeDegrees: allowedRotationRangeDegrees,
        resolvedScaleRange: resolvedScaleRange,
        collisionShape: collisionShape,
      ),
      choices: [],
    )
  }

  var allowedRotationRangeDegrees: ClosedRange<Double> {
    renderDescriptor?.allowedRotationRangeDegrees ?? 0...0
  }

  var resolvedScaleRange: ClosedRange<Double> {
    renderDescriptor?.resolvedScaleRange ?? 1...1
  }

  var collisionShape: CollisionShape {
    renderDescriptor?.collisionShape ?? .circle(center: .zero, radius: 0)
  }
}

extension ShapePlacementEngine.PlacedSymbolDescriptor {
  /// Convenience initializer that uses `symbolId` as the render symbol ID.
  init(
    symbolId: UUID,
    zIndex: Double = 0,
    sourceOrder: Int = 0,
    position: CGPoint,
    rotationRadians: Double,
    scale: CGFloat,
    collisionShape: CollisionShape,
  ) {
    self.init(
      symbolId: symbolId,
      renderSymbolId: symbolId,
      zIndex: zIndex,
      sourceOrder: sourceOrder,
      position: position,
      rotationRadians: rotationRadians,
      scale: scale,
      collisionShape: collisionShape,
    )
  }
}
