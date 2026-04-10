// By Dennis Müller

import CoreGraphics
import Foundation

/// Stable request identity used for snapshot fingerprinting and compatibility checks.
struct SnapshotRequestKey: Hashable {
  /// Hashable representation of a pinned symbol used in request identity.
  struct PinnedSymbolKey: Hashable {
    /// Position encoding used in request keys.
    enum PositionKind: Hashable {
      case absolute
      case relative
    }

    var id: UUID
    var positionKind: PositionKind
    var absoluteX: Double
    var absoluteY: Double
    var unitPointX: Double
    var unitPointY: Double
    var offsetWidth: Double
    var offsetHeight: Double
    var zIndex: Double
    var rotationRadians: Double
    var scale: CGFloat
    var collisionShape: CollisionShape
  }

  var mode: Mode
  var resolvedSeed: UInt64
  var region: TesseraCanvasRegion
  var regionRendering: TesseraRegionRendering
  var pinnedSymbolKeys: [PinnedSymbolKey]
}

/// Render-ready placement entry used by snapshot views.
struct SnapshotPlacementDescriptor: Hashable {
  var symbolId: UUID
  var renderSymbolId: UUID
  var zIndex: Double
  var sourceOrder: Int
  var position: CGPoint
  var rotationRadians: Double
  var scale: CGFloat
  var clipRect: CGRect?
}

/// One resolved mosaic render layer inside a snapshot.
struct SnapshotMosaicLayer: Identifiable, @unchecked Sendable {
  var id: UUID
  var symbols: [Symbol]
  var placements: [SnapshotPlacementDescriptor]
  var mask: MosaicShapeMask
  var maskDefinition: MosaicMask
  var rendering: MosaicRendering
  var offset: CGSize
}

struct SnapshotPerformanceDiagnostics {
  struct Layer {
    var id: UUID?
    var maskPreparationDurationSeconds: Double?
    var placement: ShapePlacementCollision.Diagnostics.Summary
  }

  var baseLayer: Layer
  var mosaicLayers: [Layer]
}

/// Fully resolved render model backing `TesseraSnapshotView`.
struct SnapshotRenderModel {
  var edgeBehavior: TesseraEdgeBehavior
  var region: TesseraCanvasRegion
  var regionRendering: TesseraRegionRendering
  var baseSymbols: [Symbol]
  var basePlacements: [SnapshotPlacementDescriptor]
  var baseOffset: CGSize
  var mosaics: [SnapshotMosaicLayer]
  var pinnedSymbols: [PinnedSymbol]
  var resolvedRegion: TesseraResolvedPolygonRegion?
  var resolvedGlobalAlphaMask: TesseraAlphaMask?
  var performanceDiagnostics: SnapshotPerformanceDiagnostics
}

extension SnapshotRequestKey {
  /// Creates a stable request key from public render inputs.
  static func make(
    mode: Mode,
    resolvedSeed: UInt64,
    region: TesseraCanvasRegion,
    regionRendering: TesseraRegionRendering,
    pinnedSymbols: [PinnedSymbol],
  ) -> SnapshotRequestKey {
    SnapshotRequestKey(
      mode: mode,
      resolvedSeed: resolvedSeed,
      region: region,
      regionRendering: regionRendering,
      pinnedSymbolKeys: pinnedSymbols.map { pinnedSymbol in
        let positionKey = pinnedSymbol.position.snapshotPositionKey
        return SnapshotRequestKey.PinnedSymbolKey(
          id: pinnedSymbol.id,
          positionKind: positionKey.positionKind,
          absoluteX: positionKey.absoluteX,
          absoluteY: positionKey.absoluteY,
          unitPointX: positionKey.unitPointX,
          unitPointY: positionKey.unitPointY,
          offsetWidth: positionKey.offsetWidth,
          offsetHeight: positionKey.offsetHeight,
          zIndex: ShapePlacementOrdering.sanitizedZIndex(pinnedSymbol.zIndex),
          rotationRadians: pinnedSymbol.rotation.radians,
          scale: pinnedSymbol.scale,
          collisionShape: pinnedSymbol.collisionShape,
        )
      },
    )
  }
}

private extension TesseraPlacementPosition {
  var snapshotPositionKey: (
    positionKind: SnapshotRequestKey.PinnedSymbolKey.PositionKind,
    absoluteX: Double,
    absoluteY: Double,
    unitPointX: Double,
    unitPointY: Double,
    offsetWidth: Double,
    offsetHeight: Double,
  ) {
    switch self {
    case let .absolute(point):
      (
        positionKind: .absolute,
        absoluteX: Double(point.x),
        absoluteY: Double(point.y),
        unitPointX: 0,
        unitPointY: 0,
        offsetWidth: 0,
        offsetHeight: 0,
      )
    case let .relative(unitPoint, offset):
      (
        positionKind: .relative,
        absoluteX: 0,
        absoluteY: 0,
        unitPointX: Double(unitPoint.x),
        unitPointY: Double(unitPoint.y),
        offsetWidth: Double(offset.width),
        offsetHeight: Double(offset.height),
      )
    }
  }
}
