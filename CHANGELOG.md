## [Unreleased]

### Added
- **Per-Symbol Draw Order**: `TesseraSymbol` / `Symbol` now include `zIndex`, so lower values render behind higher values for deterministic generated-symbol overlap behavior.
- **Pinned Symbol Draw Order**: `TesseraPinnedSymbol` / `PinnedSymbol` now include `zIndex`, so pinned symbols can be ordered against other pinned symbols and generated symbols.

### Changed
- **Deterministic Overlap Ordering**: Canvas rendering and snapshot rendering now normalize generated symbol draw order by `zIndex`, then source symbol order, then placement sequence. Pinned symbols share the same `zIndex` system, and equal values still keep pinned symbols above generated symbols.
- **Snapshot Mosaic Layering Policy**: Snapshot renders that include mosaics keep pinned symbols in a final overlay layer, so pinned symbols still draw above mosaic content instead of participating in one global mosaic/base/pinned sort.

### Removed
- **Legacy Canvas API**: Removed `TesseraCanvas`, `TesseraTiledCanvas`, placement-snapshot exports, and the old sync `renderPNG` / `renderPDF` entry points. Use `Tessera.export(...)`, `TesseraRenderer`, and `TesseraSnapshotView` instead.

## [4.0.1]

### Fixed
- **Snapshot Collision Overlays**: `TesseraSnapshotView` now renders collision overlays again for generated symbols,
  pinned symbols, and mosaic-backed snapshots.
- **Collision Overlay Exports**: `RenderOptions.showsCollisionOverlay` now affects v4 PNG and PDF exports again.

## [4.0.0]

### Added
- **Grid Subgrids**: Grid placement now supports rectangular `subgrids` with dedicated symbol pools, per-subgrid
  `symbolOrder`, and optional per-subgrid `seed`.
- **Grid Symbol Orders**: `TesseraPlacement.GridSymbolOrder` now supports `.randomWeightedPerCell`, `.shuffle`,
  `.diagonal`, and `.snake` with canonical traversal cases `.rowMajor` and `.columnMajor`.
- **Grid Seed**: `TesseraPlacement.Grid` now includes `seed` to drive deterministic grid symbol assignment.
- **Per-Symbol Grid Phases**: `TesseraPlacement.Grid.symbolPhases` allows deterministic per-symbol phase offsets in
  grid cell units (for interleaved lattices and phase-shifted symbol families).
- **Merged Grid Cells**: Grid placement now supports rectangular merged cells (`mergedCells`) with deterministic
  resolution, optional merged-cell symbol overrides, and `.fitMergedCell` sizing behavior.
- **Grid Debug Overlay**: Added `showsGridOverlay` for visualizing resolved grid lines and merged-cell bounds in
  canvas/tile rendering.
- **Choice Symbols**: `TesseraSymbol`/`Symbol` now support nested `choices` plus `choiceStrategy`
  (`.weightedRandom`, `.sequence`, `.indexSequence([Int])`) so one top-level symbol can resolve controlled
  per-placement variation while staying seed-stable.
- **Choice Index Sequences**: `TesseraSymbolChoiceStrategy` now supports `.indexSequence([Int])` for deterministic
  caller-defined child index placement with repeating sequences.
- **Spatial Steering Fields**: Added `TesseraPlacement.SteeringField` with value range, easing
  (`linear`, `smoothStep`, `easeIn`, `easeOut`, `easeInOut`), and shape selection (`linear`, `radial`) for
  position-based interpolation.
- **Radial Steering Fields**: `TesseraPlacement.SteeringField` now supports radial shape steering via
  `.radial(center:radius:)`, with `.autoFarthestCorner` and `.shortestSideFraction(Double)` radius options.
- **Organic Steering Controls**: `TesseraPlacement.OrganicSteering` now supports
  `minimumSpacingMultiplier`, `scaleMultiplier`, `rotationMultiplier`, and `rotationOffsetDegrees`.
- **Grid Steering Controls**: `TesseraPlacement.GridSteering` now supports `scaleMultiplier`, `rotationMultiplier`, and
  `rotationOffsetDegrees`.
- **API v4 Progressive Facade**: New Apple-style primary surface with `Tessera`, `Pattern`, `Symbol`, `PinnedSymbol`,
  `TesseraPlacement`, `Region`, `Seed`, `Mode`, and unified `export(...)` options.
- **Migration Documentation**: Added/expanded `3.x -> 4.0` migration guidance and before/after snippets in
  [MIGRATION.md](MIGRATION.md).

### Changed
- **Grid Sequence Naming**: Grid order now uses `.rowMajor` as the canonical sequence naming; existing `.sequence`
  usage maps to row-major behavior.
- **Seed Override Applies To Grid**: `Tessera.seed(.fixed(...))` now overrides grid placement seeding in all render
  modes (`.tile`, `.tiled`, `.canvas`).
- **Pairwise Organic Spacing**: Organic spacing checks now use per-symbol pairwise buffers (`max(lhs, rhs)`) so
  position-steered minimum spacing remains symmetric and collision-safe.
- **Steering Space**: Spatial steering is evaluated in local tile/canvas coordinates. In tiled modes (`.tile` / `.tiled`),
  steering gradients repeat per tile by design.

### Enhanced
- **Docs + Onboarding**: README quickstart now leads with the v4 single-entry API and progressive disclosure path.
- **Example App Refresh**: Example app and examples docs now use the v4 surface and naming.
- **Steering Demos**: Example app now includes dedicated spatial steering demos for organic spacing, and organic/grid
  scale + rotation gradients, plus radial scale/rotation demos.
- **Steering Documentation**: README now documents steering transform semantics (multiplier vs offset) and
  linear/radial field usage with tile-repeat behavior guidance for grid steering.

### Breaking Changes
- **Primary API Renames**: Core public types now use concise names (`Pattern`, `Symbol`, `PinnedSymbol`, `TesseraPlacement`,
  `Region`, `RenderOptions`, `RenderError`) with `Tessera` as the main entry view.
- **Placement Naming Finalized**: The v4 placement surface is now `TesseraPlacement`; the intermediate `Placement`
  facade and related compatibility shims were removed before release.
- **Mode Consolidation**: `TesseraTile`, `TesseraCanvas`, and `TesseraTiledCanvas` are superseded by
  `Tessera.mode(.tile|.canvas|.tiled)`.



## [3.0.0]

### Added
- **Grid Placement Mode**: Added `TesseraPlacement.grid` with offset strategies for seamless grid-based patterns.
- **Polygon Canvas Regions**: `TesseraCanvas` can now clip and place symbols inside polygonal regions mapped into the
  resolved canvas size (polygon regions always use finite edges).
- **Alpha Mask Regions**: `TesseraCanvas` can now place symbols inside alpha masks derived from views or images, with
  optional clipping and thresholded sampling.
- **Async Canvas Toggle**: `TesseraTile` now exposes `rendersAsynchronously` (default `false`) and forwards it into
  exports.

### Enhanced
- **Grid Offset Strategies**: Grid offset fractions now represent cell units, so values greater than 1 shift by whole cells
  (for example `2.5` shifts by 2½ cells), and `1.0` no longer aliases `0.0`.

### Fixed
- **Grid Rotation Range**: Grid placement now respects each symbol’s allowed rotation range with deterministic variation per cell.
- **Canvas Placement Computation**: `TesseraCanvas` now computes placements reliably on first render (avoids missing the
  initial layout size during view creation / restoration).
- **Pinned Symbol Render Order**: Pinned symbols now always render above generated symbols in `TesseraCanvas` (including exports).
- **Grid Count Rounding**: Seamless wrapping no longer forces even row/column counts when a grid offset strategy's fraction is zero.

### Breaking Changes
- **TesseraCanvasRegion**: Added `.alphaMask`, so exhaustive `switch` statements must handle the new case.
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
