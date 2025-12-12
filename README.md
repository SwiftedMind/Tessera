# 🔷 Tessera

Tessera is a Swift package that turns a single generated tile composed of arbitrary SwiftUI views into an endlessly repeating, seamlessly wrapping pattern.

## Features

- Easy to use: Create arbitrary repeatable patterns by composing simple SwiftUI views.
- Declarative API: describe a `TesseraConfiguration` (items, density, spacing, seed) and provide a tile size or canvas size at render time.
- Even spacing: Shape-aware placement with wrap‑around edges avoids clustering and seams.
- Deterministic: Provide a seed for reproducible artwork; omit to randomize.

## Table of Contents

- [Quick Start](#quick-start)
- [API Overview](#api-overview)
- [Exporting](#exporting)
- [Custom Items](#custom-items)
- [Notes](#notes)
- [License](#license)

## Quick Start

```swift
import Tessera
import SwiftUI

struct Demo: View {
  var body: some View {
    let items: [TesseraItem] = [
      .squareOutline,
      .roundedOutline,
      .partyPopper,
      .minus,
      .equals,
      .circleOutline
    ]

    let configuration = TesseraConfiguration(
      items: items,
      minimumSpacing: 50,
      density: 0.5
    )

    TesseraPattern(
      configuration,
      tileSize: CGSize(width: 256, height: 256),
      seed: 20
    )
      .ignoresSafeArea()
  }
}
```

## API Overview

- `TesseraConfiguration`  
  Describes how items are generated: `items`, `seed`, `minimumSpacing`, `density`, `baseScaleRange`, `patternOffset`, `maximumItemCount`.

- `TesseraTile`  
  A SwiftUI view that renders a single tile from a configuration and an explicit `tileSize`.

- `TesseraItem`  
  A drawable symbol with `weight`, `allowedRotationRange`, optional `scaleRange`, and view builder content. Includes presets like `.squareOutline`, `.partyPopper`, `.equals`, etc.

- `TesseraPattern`  
  A SwiftUI view that repeats a tile to fill available space. Requires a configuration and an explicit `tileSize`.

- `TesseraCanvas`  
  A SwiftUI view that fills a finite canvas once. Requires a configuration and an explicit `canvasSize`, and can accept fixed placements.

## Exporting

Render a single tile to PNG or vector-friendly PDF using the built-in exporter (powered by `ImageRenderer`):

```swift
let demoItems: [TesseraItem] = [
  .squareOutline, .roundedOutline, .partyPopper, .minus, .equals, .circleOutline
]

let demoConfiguration = TesseraConfiguration(
  items: demoItems,
  seed: 0,
  minimumSpacing: 10,
  density: 0.8,
  baseScaleRange: 0.5...1.2
)

let demoTile = TesseraTile(
  demoConfiguration,
  tileSize: CGSize(width: 256, height: 256)
)

let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

// Ask for an exact pixel size; scale is derived automatically. Extension is added for you.
let pngURL = try demoTile.renderPNG(
  to: downloads,
  fileName: "tessera",
  options: .init(targetPixelSize: CGSize(width: 2000, height: 2000))
)

// PDF keeps vector content; pageSize is in points. Extension is added automatically.
let pdfURL = try demoTile.renderPDF(
  to: downloads,
  fileName: "tessera",
  pageSize: CGSize(width: 256, height: 256)
)

// Prefer a fixed scale instead of pixel size:
_ = try demoTile.renderPNG(
  to: downloads,
  fileName: "tessera@3x",
  options: .init(scale: 3)
)
```

Rendering options:
- `targetPixelSize`: desired output in pixels (derives scale from the content size).
- `scale`: explicit rasterization scale when `targetPixelSize` is nil (defaults to 2).
- `isOpaque`, `colorMode`: forwarded to `ImageRenderer`.

## Custom Items

```swift
let bolt = TesseraItem(
  weight: 2,
  allowedRotationRange: .degrees(-15)...(.degrees(15)),
  scaleRange: 0.8...1.2
) {
  Image(systemName: "bolt.fill")
    .foregroundStyle(.yellow)
    .font(.system(size: 36))
}
```

## Notes
- Tessera uses Canvas symbols for performance; your item views should be lightweight.
- Rotation ranges are inclusive; use `Angle.fullCircle` for free rotation.
- Use different seeds to generate distinct but deterministic layouts.

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
