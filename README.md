# Tessera

Tessera is a Swift package that turns a single generated tile composed of arbitrary SwiftUI views into an endlessly repeating, seamlessly wrapping pattern.

## Features

- Easy to use: Create arbitrary repeatable patterns by composing simple SwiftUI views.
- Declarative API: describe a `Tessera` (tile size, items, density, spacing, seed) and drop it into `TesseraPattern`.
- Even spacing: Shape-aware placement with wrap‑around edges avoids clustering and seams.
- Deterministic: Provide a seed for reproducible artwork; omit to randomize.

## Table of Contents

- [Quick Start](#quick-start)
- [API Overview](#api-overview)
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

    let tessera = Tessera(
      size: CGSize(width: 256, height: 256),
      items: items,
      minimumSpacing: 50,
      density: 0.5
    )

    TesseraPattern(tessera, seed: 20)
      .ignoresSafeArea()
  }
}
```

## API Overview

- `Tessera`  
  Describes one tile: `size`, `items`, `seed`, `minimumSpacing`, `density`, `baseScaleRange`.

- `TesseraItem`  
  A drawable symbol with `weight`, `allowedRotationRange`, optional `scaleRange`, and view builder content. Includes presets like `.squareOutline`, `.partyPopper`, `.equals`, etc.

- `TesseraPattern`  
  A SwiftUI view that repeats a tessera to fill available space. Accepts an optional `seed` override for the view instance.

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
