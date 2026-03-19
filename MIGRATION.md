# Migration Guide

## 4.0 → 5.0

Tessera 5.0 introduces native mosaics and a snapshot-first rendering pipeline.

### Deprecated 3.x render entry points are removed

The legacy shims are now gone:

- `TesseraCanvas`
- `TesseraTiledCanvas`
- `TesseraCanvas.renderPNG(...)`
- `TesseraCanvas.renderPDF(...)`
- `TesseraCanvas.PlacementSnapshot`

Use `Tessera(...).export(...)`, `TesseraRenderer.makeSnapshot(...)`, and `TesseraSnapshotView` instead.

### Pattern adds mosaics

Before:

```swift
let pattern = Pattern(
  symbols: symbols,
  placement: .organic(minimumSpacing: 10, density: 0.6)
)
```

After:

```swift
let pattern = Pattern(
  symbols: symbols,
  placement: .organic(minimumSpacing: 10, density: 0.6),
  mosaics: [mosaic]
)
```

### New snapshot-first renderer

Use `TesseraRenderer` to compute once and render/export many times:

```swift
let renderer = TesseraRenderer(pattern)
let snapshot = try await renderer.makeSnapshot(
  mode: .canvas(size: CGSize(width: 600, height: 400), edgeBehavior: .finite),
  seed: .fixed(42)
)
let view = TesseraSnapshotView(snapshot: snapshot)
```

### Export API is now async

Before:

```swift
try Tessera(pattern)
  .mode(.tile(size: .init(width: 256, height: 256)))
  .export(.png, options: .init(directory: directory, fileName: "pattern"))
```

After:

```swift
try await Tessera(pattern)
  .mode(.tile(size: .init(width: 256, height: 256)))
  .export(.png, options: .init(directory: directory, fileName: "pattern"))
```

### Canvas mode size in snapshot workflows

For live SwiftUI layout, `.canvas(size: nil, edgeBehavior: ...)` still resolves from layout.
For snapshot workflows, provide `.canvas(size: ...)` so computation has a concrete size.

## 3.x → 4.0

Tessera 4.0 introduces a progressive-disclosure API with a single primary entry point: `Tessera`.

### Type renames

| 3.x | 4.0 |
| --- | --- |
| `TesseraConfiguration` | `Pattern` |
| `TesseraSymbol` | `Symbol` |
| `TesseraPinnedSymbol` | `PinnedSymbol` |
| `TesseraPlacement` | `Placement` |
| `TesseraCanvasRegion` | `Region` |
| `TesseraPlacementPosition` | `PinnedPosition` |
| `TesseraRenderOptions` | `RenderOptions` |
| `TesseraRenderError` | `RenderError` |

### Rendering entry point

Before:

```swift
TesseraTiledCanvas(configuration, tileSize: .init(width: 256, height: 256), seed: 42)
```

After:

```swift
Tessera(pattern)
  .mode(.tiled(tileSize: .init(width: 256, height: 256)))
  .seed(.fixed(42))
```

### Canvas mode

Before:

```swift
TesseraCanvas(configuration, edgeBehavior: .finite, region: region, pinnedSymbols: pinned)
```

After:

```swift
Tessera(pattern)
  .mode(.canvas(edgeBehavior: .finite))
  .region(region)
  .pinnedSymbols(pinned)
```

### Export API

Before:

```swift
try tile.renderPNG(to: directory, fileName: "pattern", options: .init(scale: 3))
```

After:

```swift
try Tessera(pattern)
  .mode(.tile(size: .init(width: 256, height: 256)))
  .export(
    .png,
    options: .init(directory: directory, fileName: "pattern", render: .init(scale: 3))
  )
```

### Compatibility

- 3.x APIs remained available as deprecated shims in 4.x.
- Tessera 5.0 removes the legacy canvas/tiled-canvas render-entry shims.

### Grid symbol order updates

Grid sequence naming now uses `rowMajor` as the canonical default, and grid placement adds a column-first traversal mode:

- `symbolOrder: .rowMajor`: left-to-right across each row, then next row (default).
- `symbolOrder: .columnMajor`: top-to-bottom in each column, then next column.

If your existing 4.0 code used `symbolOrder: .sequence`, migrate to `symbolOrder: .rowMajor`.

## 2.0.0 → 3.0.0

This guide covers migrating from Tessera `2.0.0` (current `main` branch) to Tessera `3.0.0` (current `develop` branch).

## 1) Update your SPM dependency

If you were consuming Tessera via a tagged release, update your version requirement to the upcoming `3.0.0` release tag once available.

If you want to try `develop` before a tag exists, pin the branch:

```swift
dependencies: [
  .package(url: "https://github.com/SwiftedMind/Tessera.git", from: "3.0.0"),
]
```

## 2) Placement configuration moved out of `TesseraConfiguration`

In `2.0.0`, `TesseraConfiguration` directly contained organic placement settings (`seed`, `minimumSpacing`, `density`, …).

In `3.0.0`, `TesseraConfiguration` contains:

- `symbols`
- `placement` (new: `TesseraPlacement`)
- `patternOffset` (unchanged)

Organic-only settings now live in `TesseraPlacement.Organic`.

### Before (2.0.0)

```swift
let configuration = TesseraConfiguration(
  symbols: symbols,
  seed: 0,
  minimumSpacing: 10,
  density: 0.6,
  baseScaleRange: 0.9...1.15,
  patternOffset: .zero,
  maximumSymbolCount: 512,
  showsCollisionOverlay: false
)
```

### After (3.0.0)

```swift
let configuration = TesseraConfiguration(
  symbols: symbols,
  placement: .organic(
    TesseraPlacement.Organic(
      seed: 0,
      minimumSpacing: 10,
      density: 0.6,
      baseScaleRange: 0.9...1.15,
      maximumSymbolCount: 512,
      showsCollisionOverlay: false
    )
  ),
  patternOffset: .zero
)
```

## 3) Replace reads/writes of old `TesseraConfiguration` properties

These `2.0.0` properties no longer exist on `TesseraConfiguration`:

| 2.0.0 | 3.0.0 |
| --- | --- |
| `configuration.seed` | `configuration.placement` → `TesseraPlacement.Organic.seed` |
| `configuration.minimumSpacing` | `TesseraPlacement.Organic.minimumSpacing` |
| `configuration.density` | `TesseraPlacement.Organic.density` |
| `configuration.baseScaleRange` | `TesseraPlacement.Organic.baseScaleRange` |
| `configuration.maximumSymbolCount` | `TesseraPlacement.Organic.maximumSymbolCount` |
| `configuration.showsCollisionOverlay` | `TesseraPlacement.Organic.showsCollisionOverlay` |

Recommended pattern for mutation:

```swift
var configuration = configuration

if case var .organic(organic) = configuration.placement {
  organic.density = 0.75
  organic.minimumSpacing = 12
  configuration.placement = .organic(organic)
}
```

If your configuration is not organic (`.grid`), these properties are intentionally unavailable.

## 4) Seeds and determinism

If you previously relied on `configuration.seed`, move that value into `TesseraPlacement.Organic(seed: ...)`.

`TesseraCanvas`, `TesseraTiledCanvas`, and `TesseraTile` still accept a `seed:` parameter. In `3.0.0`, it behaves as an *override* for **organic** placement (useful for “same config, different seed”).

## 5) Collision overlay toggles (on-screen vs export)

- On-screen overlays: now configured via `TesseraPlacement.Organic(showsCollisionOverlay: true)`.
- Export overlays: `TesseraRenderOptions(showsCollisionOverlay: true)` still exists, and now overrides
  `TesseraPlacement.Organic.showsCollisionOverlay` during export.

## 6) Optional: adopt grid placement (new in 3.0.0)

If you want fully deterministic, orderly patterns, use `.grid`:

```swift
let configuration = TesseraConfiguration(
  symbols: symbols,
  placement: .grid(
    TesseraPlacement.Grid(
      columnCount: 8,
      rowCount: 6,
      offsetStrategy: .rowShift(fraction: 0.5)
    )
  )
)
```
