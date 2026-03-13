<img width="100" height="100" alt="Tessera Logo" src="https://github.com/user-attachments/assets/78c89bdb-6dfe-4f2a-b628-082cfc8d3328" />

# Tessera

Tessera is a Swift package for building seamless, repeating patterns from regular SwiftUI views.

<p align="center">
<img alt="TEST 1" src="https://github.com/user-attachments/assets/6b7e9519-5182-4063-b067-b4c853d5c4be" />
</p>

## Features

- Build repeatable patterns from standard SwiftUI views.
- Configure symbols and placement declaratively, then provide a size at render time.
- Use organic placement for shape-aware spacing that avoids clustering.
- Use grid placement for regular layouts with configurable offsets.
- Control deterministic overlap with per-symbol `zIndex`.
- Let a single symbol resolve to multiple child variants with choice symbols.
- Modulate spacing, scale, and rotation from position-based steering fields.
- Wrap tile edges toroidally for seamless repetition.
- Set a seed for deterministic output, or omit it for randomized layouts.
- Fill polygon regions or alpha-mask regions.
- Define native mosaics with collision-shape-derived masks.
- Reuse precomputed snapshots across multiple renders and exports.
- Export to PNG or vector-friendly PDF.

## Table of Contents

- [Get Started](#get-started)
  - [Requirements](#requirements)
  - [Add Tessera via Swift Package Manager](#add-tessera-via-swift-package-manager)
  - [Configuration Basics](#configuration-basics)
  - [Quickstart: Render a tiled background](#quickstart-render-a-tiled-background)
  - [Which mode should I use?](#which-mode-should-i-use)
  - [Render a finite canvas](#render-a-finite-canvas)
  - [Next steps](#next-steps)
- [Advanced guides](#advanced-guides)
  - [Polygon regions](#polygon-regions)
  - [Alpha mask regions](#alpha-mask-regions)
  - [Mosaics](#mosaics)
  - [Grid placement](#grid-placement)
  - [Choice symbols](#choice-symbols)
  - [Spatial steering](#spatial-steering)
  - [Pinned symbols](#pinned-symbols)
  - [Snapshot-first rendering](#snapshot-first-rendering)
  - [Exporting](#exporting)
  - [Collision Shape Editor](#collision-shape-editor)
- [Reference](#reference)
  - [Terminology](#terminology)
  - [Determinism](#determinism)
  - [Performance notes](#performance-notes)
  - [Migration Guide (3.x → 4.0)](MIGRATION.md)
- [Tessera app](#tessera-app)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Get Started

### Requirements

- iOS 17+ / macOS 14+

### Add Tessera via Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and add this repository.

In `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/SwiftedMind/Tessera.git", from: "4.0.0"),
]
```

### Configuration Basics

- `Pattern` describes symbols, placement, and pattern offset.
- `Symbol` wraps a SwiftUI view, collision behavior, and optional overlap order via `zIndex`.
- `Tessera` renders using mode/seed/region modifiers.

### Quickstart: Render a tiled background

```swift
import SwiftUI
import Tessera

struct PatternBackground: View {
  var body: some View {
    Tessera(pattern)
      .mode(.tiled(tileSize: CGSize(width: 256, height: 256)))
      .seed(.fixed(20))
      .ignoresSafeArea()
  }

  var pattern: Pattern {
    Pattern(
      symbols: symbols,
      placement: .organic(minimumSpacing: 10, density: 0.6, scale: 0.9...1.15),
    )
  }

  var symbols: [Symbol] {
    [
      Symbol(collider: .automatic(size: CGSize(width: 30, height: 30))) {
        Image(systemName: "sparkle")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.9))
      },
      Symbol(collider: .automatic(size: CGSize(width: 30, height: 30))) {
        Image(systemName: "circle.grid.cross")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.7))
      },
      Symbol(
        weight: 0.5,
        rotation: .degrees(-15)...(.degrees(15)),
        collider: .automatic(size: CGSize(width: 36, height: 36))
      ) {
        Image(systemName: "bolt.fill")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.yellow)
      },
    ]
  }
}
```

### Which mode should I use?

| Use case | Mode |
| --- | --- |
| Endless background | `.mode(.tiled(tileSize: ...))` |
| Single seamless tile | `.mode(.tile(size: ...))` |
| Finite composition | `.mode(.canvas(edgeBehavior: .finite))` |

### Render a finite canvas

Use `.mode(.canvas(...))` when you want one non-repeating composition for UI or export.

```swift
import SwiftUI
import Tessera

struct Poster: View {
  var body: some View {
    Tessera(pattern)
      .mode(.canvas(edgeBehavior: .finite))
      .frame(width: 600, height: 400)
  }

  var pattern: Pattern {
    Pattern(
      symbols: symbols,
      placement: .organic(minimumSpacing: 10, density: 0.65),
    )
  }

  var symbols: [Symbol] {
    [
      Symbol(collider: .automatic(size: CGSize(width: 34, height: 34))) {
        Image(systemName: "scribble.variable")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.8))
      }
    ]
  }
}
```

### Next steps

- Run the sample app: [`Examples/README.md`](Examples/README.md)
- Review migration notes: [`MIGRATION.md`](MIGRATION.md)
- Jump to advanced guides: [Polygon regions](#polygon-regions), [Grid placement](#grid-placement), [Spatial steering](#spatial-steering)

## Advanced guides

### Polygon regions

- Place symbols inside arbitrary polygons rather than rectangles.
- Points can be defined in source space and mapped into the resolved canvas size.
- Use `.canvasCoordinates` when points are already in canvas space.
- Use `.regionRendering(.unclipped)` to let symbols extend beyond the region while still constraining placement.

```swift
let outlinePoints: [CGPoint] = [
  CGPoint(x: 0, y: 0),
  CGPoint(x: 160, y: 20),
  CGPoint(x: 140, y: 180),
  CGPoint(x: 0, y: 160)
]

let region = Region.polygon(outlinePoints)

Tessera(pattern)
  .mode(.canvas(edgeBehavior: .finite))
  .region(region)
  .frame(width: 400, height: 400)
```

If you already have a `CGPath` (for example from a vector editor or by building it in code), Tessera can flatten it into
polygon points:

```swift
let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 200, height: 120), transform: nil)
let region = Region.polygon(path, flatness: 2)
```

#### Mapping modes

| Mapping | Behavior |
| --- | --- |
| `.fit(mode: .aspectFit, alignment: .center)` | Fits the polygon inside the canvas while preserving aspect ratio. |
| `.fit(mode: .aspectFill, alignment: .center)` | Fills the canvas while preserving aspect ratio, cropping overflow. |
| `.fit(mode: .stretch, alignment: .center)` | Stretches independently on each axis to fill the canvas. |
| `.canvasCoordinates` | Treats points as canvas coordinates with no additional mapping. |

### Alpha mask regions

- Constrain placement using the alpha channel from a SwiftUI view or image.
- Tessera samples the mask at `pixelScale` and treats alpha ≥ `alphaThreshold` as inside.
- Use `.regionRendering(.unclipped)` to draw outside the mask while keeping placement constrained.

```swift
let region = Region.alphaMask(cacheKey: "logo-mask") {
  Image("Logo")
    .resizable()
    .aspectRatio(contentMode: .fit)
}

Tessera(pattern)
  .mode(.canvas(edgeBehavior: .finite))
  .region(region)
  .frame(width: 400, height: 400)
```

If you already have a `CGImage`, pass it directly:

```swift
let region = Region.alphaMask(
  cacheKey: "mask",
  image: cgImage,
  pixelScale: 2,
  alphaThreshold: 0.4,
  sampling: .bilinear
)
```

> Note: For view-based masks, the view is sized by the mapping; use view modifiers such as `.aspectRatio` to preserve
> the shape’s proportions. Increase `pixelScale` when you need sharper edges at the cost of extra placement work.

### Mosaics

A mosaic carves out an area with a mask symbol, fills that area with its own symbols, and leaves the remaining area to the base pattern.

```swift
let mosaicMask = MosaicMask(
  symbol: Symbol(collider: .automatic(size: CGSize(width: 180, height: 180))) {
    Image(systemName: "star.fill")
      .font(.system(size: 180))
      .foregroundStyle(.white)
  },
  position: .centered()
)

let mosaic = Mosaic(
  mask: mosaicMask,
  symbols: [
    Symbol(collider: .automatic(size: CGSize(width: 24, height: 24))) {
      Circle().fill(.yellow).frame(width: 24, height: 24)
    }
  ],
  placement: .grid(columns: 8, rows: 8),
  rendering: .clipped
)

let pattern = Pattern(
  symbols: baseSymbols,
  placement: .organic(minimumSpacing: 10, density: 0.7),
  mosaics: [mosaic]
)
```

### Grid placement

Use grid placement when you want regular, repeatable patterns with optional row/column offsets. `symbolOrder` controls
how cells are traversed (defaults to row-major `.rowMajor`), and cell size comes from the configured row and column
counts. Some seamless wrapping modes with non-zero offsets require even row/column counts, so Tessera rounds up when
needed. Offsets are expressed in cell units, so `2.5` shifts by two and a half cells. Use `.columnMajor` to traverse
top-to-bottom before moving to the next column.

```swift
let pattern = Pattern(
  symbols: symbols,
  placement: .grid(
    columns: 8,
    rows: 6,
    offset: .rowShift(fraction: 0.5),
    symbolOrder: .randomWeightedPerCell,
    seed: 42,
    showsGridOverlay: true
  )
)
```

Use `symbolPhases` to shift specific symbol IDs in cell units when you need interleaved lattices:

```swift
let primaryID = UUID()
let secondaryID = UUID()

let pattern = Pattern(
  symbols: [
    Symbol(id: primaryID) { Circle() },
    Symbol(id: secondaryID) { Circle() },
  ],
  placement: .grid(
    columns: 8,
    rows: 8,
    symbolOrder: .diagonal,
    symbolPhases: [secondaryID: .init(x: 0.5, y: 0.5)]
  )
)
```

`symbolPhases` is a dictionary keyed by each symbol's `id`:

- Key (`UUID`): the `id` of the symbol to shift.
- Value (`SymbolPhase`): `x` and `y` phase in cell units (`0.5` = half a cell).
- Application order: base cell center -> `offsetStrategy` -> matching `symbolPhases` entry.

Typical uses:

- Interleaving two symbol families with stable phase offsets.
- Nudging only one symbol family without changing all grid cells.
- Building offset motifs while keeping deterministic assignment via `seed`.

Use `subgrids` to define rectangular areas that use dedicated symbol pools:

```swift
let hero = Symbol(collider: .automatic(size: CGSize(width: 60, height: 60))) {
  Image(systemName: "sparkles")
}

let pattern = Pattern(
  symbols: regularSymbols,
  placement: .grid(
    columns: 10,
    rows: 10,
    subgrids: [
      .init(
        at: .init(row: 4, column: 3),
        spanning: .init(rows: 2, columns: 2),
        symbols: [hero],
        symbolOrder: .columnMajor,
        seed: 9001
      ),
      .init(
        at: .init(row: 4, column: 5),
        spanning: .init(rows: 2, columns: 1),
        symbols: [hero]
      ),
    ]
  )
)
```

`subgrids` behavior:

- Coordinate space: zero-based base grid row/column indices.
- Rectangle shape: `origin` + `span` (`rows x columns`).
- Symbols: each subgrid owns a dedicated `symbols` list.
- `symbolOrder`: applies locally within the subgrid bounds.
- `seed`: optional subgrid-local seed for random-based orders (`shuffle`, `randomWeightedPerCell`).
- Validation: invalid or overlapping subgrids are ignored; first valid subgrid wins.
- Subgrid symbols are dedicated to subgrids and are excluded from regular-cell assignment.
- In debug builds, Tessera asserts if a subgrid references unknown symbol IDs.
- For seamless wrapping + non-zero offset strategies, Tessera may resolve to adjusted row/column counts (for example
  rounding to even counts). Subgrid validation is performed against those resolved counts.

Use `showsGridOverlay: true` while iterating on layouts to render a debug grid overlay.

Important: a single grid pass still places one symbol per resolved placement cell.
If you need two complete lattices overlaid (both fully populated), render two Tessera layers (one per symbol family)
and phase-shift one of the layers.

### Choice symbols

Choice symbols let one top-level `Symbol` resolve one child symbol per accepted placement.

- `.weightedRandom`: pick a child by child `weight`.
- `.sequence`: cycle children deterministically (`first`, `second`, ... then wrap).
- `.indexSequence([Int])`: resolve child indices in caller-defined order (`indices[0]`, `indices[1]`, ... then wrap).
- `zIndex` lives on the top-level symbol and controls how accepted placements overlap when they draw.
- Lower `zIndex` values render behind higher values.
- When two generated symbols share the same `zIndex`, Tessera falls back to the source `symbols` array order, then to placement sequence.
- Child `weight` values are relative probabilities for `.weightedRandom`.
- `.indexSequence` normalizes each provided index modulo child count (supports negative/out-of-range values).
- `.indexSequence([])` emits an assertion-style warning in debug builds and falls back to `.sequence`.
- `choiceSeed` is an optional per-symbol seed salt mixed with the placement seed.
- Keep `choiceSeed` as `nil` to use only the global seed, or set it for stable per-symbol variation control.

```swift
let sparkle = Symbol(
  id: UUID(uuidString: "80A33AD9-7BC5-4C69-A0A0-511DD6CBEE71")!,
  weight: 2,
  collider: .automatic(size: CGSize(width: 26, height: 26))
) {
  Image(systemName: "sparkles")
}

let slashedCircle = Symbol(
  id: UUID(uuidString: "4D51AD6A-0B07-478C-B053-95B380EC2EA4")!,
  weight: 1,
  collider: .automatic(size: CGSize(width: 26, height: 26))
) {
  Image(systemName: "circle.slash")
}

let choice = Symbol(
  id: UUID(uuidString: "F9514DB4-50B4-4F17-8BE3-26E2A48D6C38")!,
  zIndex: 2,
  choiceStrategy: .indexSequence([0, 1, 0, 1, 1]),
  choiceSeed: 302,
  choices: [sparkle, slashedCircle]
)

let pattern = Pattern(
  symbols: [choice],
  placement: .grid(columns: 8, rows: 8, seed: 42)
)
```

When using grid `symbolPhases` with choice symbols, phase keys should reference the resolved child symbol IDs:

```swift
let pattern = Pattern(
  symbols: [choice],
  placement: .grid(
    columns: 8,
    rows: 8,
    seed: 42,
    symbolPhases: [
      slashedCircle.id: .init(x: 0.5, y: 0.5)
    ]
  )
)
```

### Spatial steering

Spatial steering modulates placement from position using a `SteeringField`.

Key `SteeringField` properties:
- `values`: interpolation range.
- `shape`: `.linear(from:to:)` or `.radial(center:radius:)`.
- `radius` (radial): `.autoFarthestCorner` or `.shortestSideFraction(Double)`.
- `easing`: `linear`, `smoothStep`, `easeIn`, `easeOut`, `easeInOut`.
- Organic steering fields: `minimumSpacingMultiplier`, `scaleMultiplier`, `rotationMultiplier`, `rotationOffsetDegrees`.
- Grid steering fields: `scaleMultiplier`, `rotationMultiplier`, `rotationOffsetDegrees`.

Effective transforms are applied as:

```swift
minimumSpacing = baseMinimumSpacing * minimumSpacingMultiplier  // organic only
scale = baseScale * scaleMultiplier                             // organic + grid
rotation = baseRotation * rotationMultiplier + rotationOffset   // organic + grid
```

#### Organic steering example

```swift
let pattern = Pattern(
  symbols: symbols,
  placement: .organic(
    minimumSpacing: 8,
    density: 0.8,
    scale: 0.85...1.15,
    steering: .init(
      minimumSpacingMultiplier: .init(
        values: 0.3...2.0,
        from: .top,
        to: .bottom,
        easing: .smoothStep
      ),
      scaleMultiplier: .init(
        values: 0.7...1.4,
        from: .leading,
        to: .trailing,
        easing: .easeInOut
      ),
      rotationOffsetDegrees: .init(
        values: 0...180,
        from: .topLeading,
        to: .bottomTrailing,
        easing: .linear
      )
    )
  )
)
```

#### Grid steering example

```swift
let pattern = Pattern(
  symbols: symbols,
  placement: .grid(
    columns: 8,
    rows: 6,
    symbolOrder: .randomWeightedPerCell,
    seed: 42,
    steering: .init(
      scaleMultiplier: .init(
        values: 0.6...1.3,
        from: .topLeading,
        to: .bottomTrailing
      ),
      rotationMultiplier: .init(
        values: 0.5...1.5,
        from: .leading,
        to: .trailing,
        easing: .linear
      ),
      rotationOffsetDegrees: .init(
        values: -20...20,
        from: .top,
        to: .bottom,
        easing: .smoothStep
      )
    )
  )
)
```

#### Radial variants

Organic radial:

```swift
let pattern = Pattern(
  symbols: symbols,
  placement: .organic(
    minimumSpacing: 8,
    density: 0.8,
    scale: 0.85...1.15,
    steering: .init(
      scaleMultiplier: .radial(
        values: 0.65...1.6,
        center: .center,
        radius: .shortestSideFraction(0.55),
        easing: .smoothStep
      )
    )
  )
)
```

Grid radial:

```swift
let pattern = Pattern(
  symbols: symbols,
  placement: .grid(
    columns: 9,
    rows: 9,
    seed: 303,
    steering: .init(
      rotationOffsetDegrees: .radial(
        values: 0...42,
        center: .center,
        radius: .autoFarthestCorner,
        easing: .easeInOut
      )
    )
  )
)
```

> Notes:
> - Steering is evaluated in local tile/canvas space.
> - Radial distance is measured in canvas points after mapping `center` from unit space.
> - In tiled/seamless modes (`.tile` / `.tiled`), gradients repeat per tile.
> - This repeating reset is often most visible with grid scale/rotation steering and is expected.
> - Steering multipliers are clamped to `>= 0` before application.
> - Grid placement does not reject overlaps between generated grid symbols; it only enforces collisions against pinned symbols.
> - For a single non-repeating gradient across the whole output, use `.mode(.canvas(edgeBehavior: .finite))`.

### Pinned symbols

Pinned symbols let you place fixed content (like a logo or headline) on a finite canvas while Tessera fills the
surrounding space with generated symbols. Pinned symbols render above generated symbols and participate in collision
checks, so generated symbols keep their distance.

```swift
import SwiftUI
import Tessera

struct HeroCard: View {
  var body: some View {
    Tessera(pattern)
      .mode(.canvas(edgeBehavior: .finite))
      .pinnedSymbols([logo])
      .frame(width: 600, height: 360)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  var pattern: Pattern {
    Pattern(
      symbols: generatedSymbols,
      placement: .organic(minimumSpacing: 10, density: 0.7),
    )
  }

  var generatedSymbols: [Symbol] {
    [
      Symbol(collider: .automatic(size: CGSize(width: 28, height: 28))) {
        Image(systemName: "hexagon.fill")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.blue.opacity(0.55))
      }
    ]
  }

  var logo: PinnedSymbol {
    PinnedSymbol(
      position: .init(.center),
      collider: .automatic(size: CGSize(width: 160, height: 160))
    ) {
      Image(systemName: "t.square.fill")
        .font(.system(size: 120, weight: .heavy))
        .foregroundStyle(.primary)
    }
  }
}
```

### Snapshot-first rendering

Use `TesseraRenderer` when you want one deterministic placement pass that you can render or export multiple times:

```swift
let renderer = TesseraRenderer(pattern)
let snapshot = try await renderer.makeSnapshot(
  mode: .canvas(size: CGSize(width: 600, height: 400), edgeBehavior: .finite),
  seed: .fixed(42)
)

let view = TesseraSnapshotView(snapshot: snapshot)

// Optional: visualize effective mosaic masks below symbols.
let debugView = TesseraSnapshotView(
  snapshot: snapshot,
  debugOverlay: .mosaicMasks(opacity: 0.22)
)
```

To stream progress:

```swift
for try await event in renderer.makeSnapshotEvents(
  mode: .tile(size: CGSize(width: 256, height: 256))
) {
  print(event)
}
```

### Exporting

Use the built-in exporter (powered by `ImageRenderer`) to render a tile or tiled canvas to PNG or vector-friendly PDF.

```swift
import Foundation
import SwiftUI
import Tessera

let symbols: [Symbol] = [
  Symbol(collider: .automatic(size: CGSize(width: 30, height: 30))) {
    Image(systemName: "sparkle").font(.system(size: 24, weight: .semibold))
  },
  Symbol(collider: .automatic(size: CGSize(width: 30, height: 30))) {
    Image(systemName: "circle.grid.cross").font(.system(size: 24, weight: .semibold))
  },
  Symbol(
    rotation: .degrees(-10)...(.degrees(10)),
    collider: .automatic(size: CGSize(width: 36, height: 36))
  ) {
    Image(systemName: "bolt.fill").font(.system(size: 28, weight: .bold))
  },
]

let pattern = Pattern(
  symbols: symbols,
  placement: .organic(minimumSpacing: 10, density: 0.8, scale: 0.5...1.2)
)

let outputDirectory = FileManager.default.temporaryDirectory
let tessera = Tessera(pattern).mode(.tile(size: CGSize(width: 256, height: 256)))

let pngURL = try tessera.export(
  .png,
  options: .init(
    directory: outputDirectory,
    fileName: "tessera",
    render: .init(targetPixelSize: CGSize(width: 2000, height: 2000))
  )
)

let whiteBackgroundPNGURL = try tessera.export(
  .png,
  options: .init(
    directory: outputDirectory,
    fileName: "tessera-white-background",
    backgroundColor: .white,
    render: .init(targetPixelSize: CGSize(width: 2000, height: 2000))
  )
)

let pdfURL = try tessera.export(
  .pdf,
  options: .init(
    directory: outputDirectory,
    fileName: "tessera",
    pageSize: CGSize(width: 256, height: 256)
  )
)

let pngURLAt3x = try tessera.export(
  .png,
  options: .init(
    directory: outputDirectory,
    fileName: "tessera@3x",
    render: .init(scale: 3)
  )
)
```

Rendering options (`RenderOptions`):

- `targetPixelSize`: Desired output size in pixels (derives scale from content size).
- `scale`: Explicit render scale when `targetPixelSize` is `nil` (defaults to 2).
- `showsCollisionOverlay`: Whether to draw collision overlays while exporting (defaults to `false`).
- `isOpaque`, `colorMode`: Forwarded to `ImageRenderer`.
- `backgroundColor` (export function parameter): Optional fill rendered behind the export (defaults to none).

### Collision Shape Editor

Use `Symbol.collisionShapeEditor()` to open an interactive editor and export collision geometry for reuse.

## Reference

### Terminology

- `Pattern` - Describes how symbols are generated.
- `TesseraPlacement` - Defines organic or grid placement behavior.
- `Symbol` - A drawable symbol used to fill a repeatable tile or a finite canvas.
- `CollisionShape` - Approximate local-space geometry used for collision checks of symbols.
- `Tessera` - Primary rendering entry point with progressive modifiers (`mode`, `seed`, `region`, `pinnedSymbols`).
- `CollisionShapeEditor` - An interactive editor that lets you visually build and export a collision shape for your symbols.

### Determinism

Tessera is deterministic when you provide a fixed seed:

```swift
Tessera(pattern)
  .mode(.tiled(tileSize: CGSize(width: 256, height: 256)))
  .seed(.fixed(123))
```

To "move" a pattern without changing the layout, modify `offset`:

```swift
var pattern = Pattern(
  symbols: symbols,
  placement: .organic(minimumSpacing: 44, density: 0.6)
)
pattern.offset = CGSize(width: 40, height: 0)
```

### Performance notes

- Tessera uses `Canvas` symbols for performance; keep symbol views lightweight.
- Canvas rendering defaults to synchronous updates to keep interactive transforms in sync. Use
  `.rendersAsynchronously(true)` on `Tessera` when you prefer async drawing.
- Collision geometry is intentionally approximate; use `collisionShape` when a symbol needs a more accurate footprint.
  Complex polygons and multi-polygon shapes can dramatically reduce placement performance.
- `TesseraPlacement.Organic.maximumCount` is a safety cap. If you crank up `density` on large canvases, you may want to raise it.

## Tessera app

There is also a companion app called Tessera if you prefer designing patterns in a dedicated UI instead of code.
It supports design, preview, and export workflows on iPad and macOS.

- Website: [tesserapatterns.com](https://tesserapatterns.com)
- App Store: [Tessera - Seamless Patterns](https://apps.apple.com/us/app/tessera-seamless-patterns/id6756501042)

If that workflow fits your project better, you can use the app and keep the package for code-based integrations.

## License

MIT License

Copyright (c) 2025 Dennis Müller

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Acknowledgments

Built with Swift and the open-source community.
