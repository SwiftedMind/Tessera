<img width="100" height="100" alt="Tessera Logo" src="https://github.com/user-attachments/assets/78c89bdb-6dfe-4f2a-b628-082cfc8d3328" />

# Tessera

Tessera is a Swift package that turns a single generated tile composed of arbitrary SwiftUI views into an endlessly repeating, seamlessly wrapping pattern.

<p align="center">
<img alt="Frame 1" src="https://github.com/user-attachments/assets/0927a201-d069-4578-9c59-f0079f473fee" />
</p>

## Features

- Compose repeatable patterns from regular SwiftUI views.
- Declarative configuration: describe symbols, spacing, density, and scale; provide a size at render time.
- Even spacing: shape-aware placement that avoids clustering.
- Seamless wrapping: tile edges wrap toroidally so patterns repeat without seams.
- Deterministic output: provide a seed for reproducible layouts; omit to randomize.
- Export: render to PNG or vector-friendly PDF.

## Table of Contents

- [Get Started](#get-started)
- [Pinned Symbols](#pinned-symbols)
- [Exporting](#exporting)
- [Collision Shape Previews](#collision-shape-previews)
- [Terminology](#terminology)
- [Determinism](#determinism)
- [Notes](#notes)
- [License](#license)
- [🙏 Acknowledgments](#-acknowledgments)

## Get Started

### Requirements

- iOS 17+ / macOS 14+

### Add Tessera via Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and add this repository.

In `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/SwiftedMind/Tessera.git", from: "2.0.0"),
]
```

### Render a tiled background (endlessly repeating)

`TesseraTiledCanvas` generates a single tile, caches it as a `Canvas` symbol, then repeats it to fill all available space.

```swift
import SwiftUI
import Tessera

struct PatternBackground: View {
  var body: some View {
    TesseraTiledCanvas(
      configuration,
      tileSize: CGSize(width: 256, height: 256),
      seed: 20
    )
    .ignoresSafeArea()
  }

  var configuration: TesseraConfiguration {
    TesseraConfiguration(
      symbols: symbols,
      minimumSpacing: 10,
      density: 0.6,
      baseScaleRange: 0.9...1.15
    )
  }

  var symbols: [TesseraSymbol] {
    [
      TesseraSymbol(approximateSize: CGSize(width: 30, height: 30)) {
        Image(systemName: "sparkle")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.9))
      },
      TesseraSymbol(approximateSize: CGSize(width: 30, height: 30)) {
        Image(systemName: "circle.grid.cross")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.7))
      },
      TesseraSymbol(
        weight: 0.5,
        allowedRotationRange: .degrees(-15)...(.degrees(15)),
        approximateSize: CGSize(width: 36, height: 36)
      ) {
        Image(systemName: "bolt.fill")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.yellow)
      },
    ]
  }
}
```

### Render a finite canvas

Use `TesseraCanvas` when you want a single generated composition at a specific size (for UI or export). It fills the size provided by the layout, so set a frame.

```swift
import SwiftUI
import Tessera

struct Poster: View {
  var body: some View {
    TesseraCanvas(configuration, edgeBehavior: .finite)
      .frame(width: 600, height: 400)
  }

  var configuration: TesseraConfiguration {
    TesseraConfiguration(symbols: symbols, minimumSpacing: 10, density: 0.65)
  }

  var symbols: [TesseraSymbol] {
    [
      TesseraSymbol(approximateSize: CGSize(width: 34, height: 34)) {
        Image(systemName: "scribble.variable")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.8))
      }
    ]
  }
}
```

## Pinned Symbols

Pinned symbols let you place specific content (like a logo or headline) on a fixed-sized canvas while Tessera fills the space around it with repeating Tessera symbols. Fixed symbols participate in collision checks, so generated symbols keep their distance.

```swift
import SwiftUI
import Tessera

struct HeroCard: View {
  var body: some View {
    TesseraCanvas(
      configuration,
      pinnedSymbols: [logo],
      edgeBehavior: .finite
    )
    .frame(width: 600, height: 360)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  var configuration: TesseraConfiguration {
    TesseraConfiguration(symbols: symbols, minimumSpacing: 10, density: 0.7)
  }

  var symbols: [TesseraSymbol] {
    [
      TesseraSymbol(approximateSize: CGSize(width: 28, height: 28)) {
        Image(systemName: "hexagon.fill")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.blue.opacity(0.55))
      }
    ]
  }

  var logo: TesseraPinnedSymbol {
    TesseraPinnedSymbol(
      position: .centered(),
      approximateSize: CGSize(width: 160, height: 160)
    ) {
      Image(systemName: "t.square.fill")
        .font(.system(size: 120, weight: .heavy))
        .foregroundStyle(.primary)
    }
  }
}
```

## Exporting

Export a tile or tiled canvas to PNG or vector-friendly PDF using the built-in exporter (powered by `ImageRenderer`).

```swift
import Foundation
import SwiftUI
import Tessera

let symbols: [TesseraSymbol] = [
  TesseraSymbol(approximateSize: CGSize(width: 30, height: 30)) {
    Image(systemName: "sparkle").font(.system(size: 24, weight: .semibold))
  },
  TesseraSymbol(approximateSize: CGSize(width: 30, height: 30)) {
    Image(systemName: "circle.grid.cross").font(.system(size: 24, weight: .semibold))
  },
  TesseraSymbol(
    allowedRotationRange: .degrees(-10)...(.degrees(10)),
    approximateSize: CGSize(width: 36, height: 36)
  ) {
    Image(systemName: "bolt.fill").font(.system(size: 28, weight: .bold))
  },
]

let configuration = TesseraConfiguration(
  symbols: symbols,
  seed: 0,
  minimumSpacing: 10,
  density: 0.8,
  baseScaleRange: 0.5...1.2
)

let tile = TesseraTile(configuration, tileSize: CGSize(width: 256, height: 256))
let outputDirectory = FileManager.default.temporaryDirectory

// Ask for an exact pixel size; scale is derived automatically. Extension is added for you.
let pngURL = try tile.renderPNG(
  to: outputDirectory,
  fileName: "tessera",
  options: .init(targetPixelSize: CGSize(width: 2000, height: 2000))
)

// Exports default to a transparent background; set a background color when needed.
let whiteBackgroundPNGURL = try tile.renderPNG(
  to: outputDirectory,
  fileName: "tessera-white-background",
  backgroundColor: .white,
  options: .init(targetPixelSize: CGSize(width: 2000, height: 2000))
)

// PDF keeps vector content; pageSize is in points. Extension is added automatically.
let pdfURL = try tile.renderPDF(
  to: outputDirectory,
  fileName: "tessera",
  pageSize: CGSize(width: 256, height: 256)
)

// Prefer a fixed scale instead of pixel size:
let pngURL = try tile.renderPNG(
  to: outputDirectory,
  fileName: "tessera@3x",
  options: .init(scale: 3)
)
```

Rendering options (`TesseraRenderOptions`):

- `targetPixelSize`: Desired output size in pixels (derives scale from content size).
- `scale`: Explicit rasterization scale when `targetPixelSize` is `nil` (defaults to 2).
- `showsCollisionOverlay`: Whether to draw collision overlays while exporting (defaults to `false`).
- `isOpaque`, `colorMode`: Forwarded to `ImageRenderer`.
- `backgroundColor` (export function parameter): Optional fill rendered behind the export (defaults to none).

## Collision Shape Editor

Use `TesseraSymbol.collisionShapeEditor()` to get a SwiftUI view containing a fully working collision shape editor that lets you build and export collision shapes easily

## Terminology

- `TesseraConfiguration` - Describes how symbols are generated.
- `TesseraSymbol` - A drawable symbol used to fill a repeatable tile or a finite canvas
- `CollisionShape` - Approximate local-space geometry used for collision checks of symbols.
- `TesseraTile` - A single drawable tile that can be seamlessly repeated.
- `TesseraTiledCanvas` - Repeats a single generated tile to fill the available space (great for backgrounds).
- `TesseraCanvas`- Generates a single composition at a finite size (great for posters, cards, and exports).
- `CollisionShapeEditor` - An interactive editor that lets you visually build and export a collision shape for your symbols.

## Determinism

Tessera is deterministic when you provide a seed. You can set `seed` on `TesseraConfiguration`, or override it per-view:

```swift
TesseraTiledCanvas(configuration, tileSize: CGSize(width: 256, height: 256), seed: 123)
```

To "move" a pattern without changing the layout, modify `patternOffset`:

```swift
var configuration = TesseraConfiguration(symbols: symbols, minimumSpacing: 44, density: 0.6)
configuration.patternOffset = CGSize(width: 40, height: 0)
```

## Notes

- Tessera uses `Canvas` symbols for performance; keep symbol views lightweight.
- Collision geometry is intentionally approximate; use `collisionShape` when an symbol needs a more accurate footprint.
  Complex polygons and multi-polygon shapes can dramatically reduce placement performance.
- `maximumSymbolCount` is a safety cap. If you crank up `density` on large canvases, you may want to raise it.

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

## 🙏 Acknowledgments

Built with the amazing Swift ecosystem and community

Made with ❤️ for the Swift community
