## [Unreleased]

### Added
- **Polygon Canvas Regions**: `TesseraCanvas` can now clip and place symbols inside polygonal regions mapped into the
  resolved canvas size (polygon regions always use finite edges).

### Fixed
- **Grid Rotation Range**: Grid placement now respects each symbol’s allowed rotation range with deterministic variation per cell.

## [3.0.0]

### Added
- **Grid Placement Mode**: Added `TesseraPlacement.grid` with offset strategies for seamless grid-based patterns.

### Enhanced
- **Grid Offset Strategies**: Grid offset fractions now represent cell units, so values greater than 1 shift by whole cells
  (for example `2.5` shifts by 2½ cells), and `1.0` no longer aliases `0.0`.

### Fixed
- **Canvas Placement Computation**: `TesseraCanvas` now computes placements reliably on first render (avoids missing the
  initial layout size during view creation / restoration).
- **Pinned Symbol Render Order**: Pinned symbols now always render above generated symbols in `TesseraCanvas` (including exports).
- **Grid Count Rounding**: Seamless wrapping no longer forces even row/column counts when a grid offset strategy's fraction is zero.

### Breaking Changes
- **Migration Guide**: See [MIGRATION.md](MIGRATION.md) for 2.0.0 → 3.0.0 upgrade steps.
- **Placement Configuration Refactor**: `TesseraConfiguration` now takes a `TesseraPlacement` with per-mode settings
  (for example `TesseraPlacement.Organic`), moving organic-only properties out of the top-level configuration.
- **Grid Placement Counts**: `TesseraPlacement.Grid` now uses `columnCount` and `rowCount`, and the grid cell size is
  derived from the tile size instead of being configured directly.

## [2.0.0]

### Added
- **Collision Overlay Debugging**: `TesseraConfiguration.showsCollisionOverlay` draws collision shapes on canvas views,
  and `TesseraRenderOptions.showsCollisionOverlay` opt-in enables overlays for exports.
- **Compound Collision Shapes**: `CollisionShape.polygons(pointSets:)` and `CollisionShape.anchoredPolygon(pointSets:anchor:size:)` let a single symbol use multiple polygons.
  for collision checks; complex shapes can dramatically reduce placement performance.
- **Collision Shape Previews**: `TesseraSymbol.collisionShapeEditor()` returns a SwiftUI view with a fully-working editor that lets you build and export collision shapes visually. 

### Enhanced
- **Items Renamed To Symbols**: `TesseraItem` and `TesseraFixedItem` have been renamed to `TesseraSymbol` and `TesseraPinnedSymbol`
- **Faster Collision Placement**: Improves `ShapePlacementEngine` collision checks by caching polygon axes, avoiding per-test world-polygon allocations, and using a nearest-image torus offset (with a safe fallback) for seamless wrapping.
- **Concave Polygon Collisions**: Concave polygons are decomposed into convex pieces for more accurate collisions, at a
  higher placement cost for complex shapes.
- **Per-Polygon Broad Phase**: Adds per-piece bounding circle checks to skip expensive narrow-phase tests when compound
  shapes are far apart.

### Fixed

### Breaking Changes
- **Items Renamed To Symbols**: `TesseraItem` and `TesseraFixedItem` have been renamed to `TesseraSymbol` and `TesseraPinnedSymbol`
- **Offset Collision Shapes**: `CollisionShape.circle(center:radius:)` and `CollisionShape.rectangle(center:size:)` add a local-space `center`, so colliders are no longer forced to be centered at the origin.
- **View-Space Polygon Defaults**: `CollisionShape.polygon(points:)` and `CollisionShape.polygons(points:)` now interpret
  points as anchored to the top leading edge of the view, instead of the center.
- **Expanded CollisionShape Cases**: `CollisionShape` adds new polygon variants, so exhaustive `switch` statements must
  handle centered and anchored polygons.
