# Tessera CollisionShape Placement – Implementation Plan

## 0. Goals & Constraints

**Goal:** Replace the current "point + radius" Poisson placement with a system that:
- Knows about each item’s **approximate shape** (circle / rect / polygon).
- Avoids **overlaps based on shape**, not just distance between centers.
- Stays deterministic for a given **seed**.
- Integrates cleanly with existing `Tessera`, `TesseraItem`, and `TesseraCanvasTile`.

**Non-goals (for now):**
- Perfect packing / optimal density (we’ll use heuristics).
- Deriving shapes automatically from arbitrary SwiftUI views.

---

## 1. Define `CollisionShape`

Create a new file, e.g. `CollisionShape.swift` in the Tessera module.

```swift
import CoreGraphics

public enum CollisionShape: Sendable {
  case circle(radius: CGFloat)
  case rect(size: CGSize)               // centered on origin
  case polygon(points: [CGPoint])       // in local space, centered around origin
}
```

### 1.1. Common helpers

Add helpers for broad-phase and transforms:

```swift
public struct CollisionTransform: Sendable {
  public var position: CGPoint
  public var rotation: CGFloat   // radians
  public var scale: CGFloat
}

public extension CollisionShape {
  /// Conservative radius around the shape, used for fast broad-phase checks.
  func boundingRadius(atScale scale: CGFloat = 1) -> CGFloat {
    switch self {
    case let .circle(radius):
      return radius * scale
    case let .rect(size):
      let halfWidth = size.width * scale / 2
      let halfHeight = size.height * scale / 2
      return hypot(halfWidth, halfHeight)
    case let .polygon(points):
      guard !points.isEmpty else { return 0 }
      let maxDistance = points.map { hypot($0.x, $0.y) }.max() ?? 0
      return maxDistance * scale
    }
  }
}
```

We’ll keep transforms separate (`CollisionTransform`) instead of mutating shapes.

---

## 2. Extend `TesseraItem` to carry a `collisionShape`

Update `TesseraItem` to store a shape:

```swift
public struct TesseraItem: Identifiable {
  public var id: UUID
  public var weight: Double
  public var allowedRotationRange: ClosedRange<Angle>
  public var scaleRange: ClosedRange<CGFloat>?
  public var collisionShape: CollisionShape
  private let builder: () -> AnyView

  public init(
    id: UUID = UUID(),
    weight: Double = 1,
    allowedRotationRange: ClosedRange<Angle> = .degrees(0)...(.degrees(360)),
    scaleRange: ClosedRange<CGFloat>? = nil,
    collisionShape: CollisionShape,
    @ViewBuilder builder: @escaping () -> some View
  ) {
    self.id = id
    self.weight = weight
    self.allowedRotationRange = allowedRotationRange
    self.scaleRange = scaleRange
    self.collisionShape = collisionShape
    self.builder = { AnyView(builder()) }
  }
}
```

### 2.1. Backwards-compatible convenience init

For call sites that don’t care about shape yet, provide a default circle based on an approximate size:

```swift
public extension TesseraItem {
  /// Convenience for callers that don't care about explicit shapes yet.
  init(
    id: UUID = UUID(),
    weight: Double = 1,
    allowedRotationRange: ClosedRange<Angle> = .degrees(0)...(.degrees(360)),
    scaleRange: ClosedRange<CGFloat>? = nil,
    approximateSize: CGSize,
    @ViewBuilder builder: @escaping () -> some View
  ) {
    let radius = hypot(approximateSize.width, approximateSize.height) / 2
    self.init(
      id: id,
      weight: weight,
      allowedRotationRange: allowedRotationRange,
      scaleRange: scaleRange,
      collisionShape: .circle(radius: radius),
      builder: builder
    )
  }
}
```

Use this in old presets initially, then progressively move to more accurate shapes.

### 2.2. Update presets to define meaningful shapes

For your built-in presets in `TesseraItem`:

- **Square outline** → `.rect(size: CGSize(width: 30, height: 30))`.
- **Rounded rect** → same as rect.
- **Circle outline** → `.circle(radius: 15)`.
- **Triangle** (if you add one) → `.polygon(points: [p1, p2, p3])`.

Example:

```swift
static var squareOutline: TesseraItem {
  TesseraItem(
    weight: 1,
    allowedRotationRange: .degrees(0)...(.degrees(360)),
    scaleRange: 0.9...1.1,
    collisionShape: .rect(size: CGSize(width: 30, height: 30))
  ) {
    RoundedRectangle(cornerRadius: 4)
      .stroke(lineWidth: 4)
      .foregroundStyle(.gray.opacity(0.2))
      .frame(width: 30, height: 30)
  }
}
```

---

## 3. Introduce `PlacedItem` model

We want a single structure that captures **what we need to draw** and **what we need to collide**.

Create `PlacedItem.swift`:

```swift
import CoreGraphics
import SwiftUI

struct PlacedItem {
  var item: TesseraItem
  var position: CGPoint
  var rotation: Angle
  var scale: CGFloat

  var collisionTransform: CollisionTransform {
    CollisionTransform(
      position: position,
      rotation: CGFloat(rotation.radians),
      scale: scale
    )
  }
}
```

This replaces the loose parallel arrays of points and items.

---

## 4. Collision math helpers

Create a `CollisionMath.swift` to keep the algorithms contained.

### 4.1. Transforming points

```swift
func applyTransform(_ p: CGPoint, _ t: CollisionTransform) -> CGPoint {
  let s = t.scale
  let x = p.x * s
  let y = p.y * s

  let cosA = cos(t.rotation)
  let sinA = sin(t.rotation)

  let rx = x * cosA - y * sinA
  let ry = x * sinA + y * cosA

  return CGPoint(x: rx + t.position.x, y: ry + t.position.y)
}
```

### 4.2. Broad-phase check (bounding circles)

```swift
func boundingCirclesOverlap(
  shapeA: CollisionShape, transformA: CollisionTransform,
  shapeB: CollisionShape, transformB: CollisionTransform
) -> Bool {
  let rA = shapeA.boundingRadius(atScale: transformA.scale)
  let rB = shapeB.boundingRadius(atScale: transformB.scale)

  let dx = transformA.position.x - transformB.position.x
  let dy = transformA.position.y - transformB.position.y
  let distanceSquared = dx * dx + dy * dy
  let radiusSum = rA + rB

  return distanceSquared < radiusSum * radiusSum
}
```

### 4.3. Narrow-phase checks

Implement a small set of pairwise checks:

- **Circle–circle:** exact.
- **Rect–rect:** treat rect as a polygon with 4 corners and use SAT.
- **Polygon–polygon:** SAT.
- For mixed pairs (circle–rect, circle–polygon), either:
  - Convert rect/polygon to a set of edges and do SAT with a circular approximation, or
  - Approximate circle as a many-sided polygon.

To keep it simple and maintainable initially:

1. Convert `.rect` into a `.polygon` (4 points) in a helper.
2. Provide `normalizedPolygon(for shape: CollisionShape)`.
3. Implement **polygon–polygon overlap with SAT** only.
4. For `.circle`, either:
   - Continue to use only broad-phase circle checks (cheap but crude), or
   - Approximate as polygon with, say, 8–12 points.

You can start with:

```swift
func polygonsOverlap(
  _ polyA: [CGPoint], _ transformA: CollisionTransform,
  _ polyB: [CGPoint], _ transformB: CollisionTransform
) -> Bool {
  // 1. Transform all points to world space
  let worldA = polyA.map { applyTransform($0, transformA) }
  let worldB = polyB.map { applyTransform($0, transformB) }

  // 2. Run SAT on edges of A and B
  // (pseudo-code – implement step by step in the actual file)
}
```

In practice, **even crude polygon approximations** will already give you a much better feel than point-based Poisson disk.

---

## 5. Implement a `ShapePlacementEngine`

Instead of `PoissonDiskGenerator + ItemAssigner`, introduce a single engine that produces `[PlacedItem]`.

Create `ShapePlacementEngine.swift`:

```swift
import CoreGraphics
import SwiftUI

enum ShapePlacementEngine {
  static func placeItems(
    in size: CGSize,
    tessera: Tessera,
    randomGenerator: inout some RandomNumberGenerator
  ) -> [PlacedItem] {
    // implementation stub
  }
}
```

### 5.1. Decide on target item count

Estimate a rough **target count** based on tile area and a guessed average item area:

```swift
let tileArea = size.width * size.height
let averageArea = (tessera.minimumSpacing * tessera.minimumSpacing)
let targetCount = Int(tileArea / averageArea * density)
```

This is heuristic; tweak as needed. You can also clamp it to a max (e.g. 256 items) for perf.

### 5.2. Main loop (rejection sampling)

For `targetCount` iterations:

1. Pick an item by weight (reuse `ItemAssigner.randomItem`).
2. Sample `scale` based on `tessera.baseScaleRange` and `item.scaleRange`.
3. Sample `rotation` within `item.allowedRotationRange`.
4. Try up to `maxAttemptsPerItem` (e.g. 20) random positions:
   - Sample a point uniformly inside the tile:

     ```swift
     let x = CGFloat.random(in: 0..<size.width, using: &randomGenerator)
     let y = CGFloat.random(in: 0..<size.height, using: &randomGenerator)
     let position = CGPoint(x: x, y: y)
     ```

   - Build `CollisionTransform` for candidate.
   - For each existing `PlacedItem`:
     - Run broad-phase `boundingCirclesOverlap`.
     - If that passes, run narrow-phase polygon overlap.
     - If any overlap → reject this candidate and try next position.
   - If no overlaps → accept, append to array, and break out of attempts.

5. If all attempts fail for this item, skip it and move on.

Return the final `[PlacedItem]`.

### 5.3. Optional: use Poisson points as starting candidates

If you like the current Poisson “feel”, you can:

- Generate Poisson points as **candidate centers**.
- Shuffle them.
- For each point, try to assign an item and adjust rotation/scale only.
- Possibly jitter the position slightly when collisions occur.

This keeps the tiling structure but respects shape collisions.

---

## 6. Integrate into `TesseraCanvasTile`

Currently `TesseraCanvasTile` does:

- Generate `points` via `PoissonDiskGenerator.makePoints`.
- Use `ItemAssigner.assignItems` to map points → items.
- For each point/item, choose rotation & scale and draw.

Change this to:

```swift
Canvas { context, size in
  var randomGenerator = SeededGenerator(seed: seed)

  let placedItems = ShapePlacementEngine.placeItems(
    in: size,
    tessera: tessera,
    randomGenerator: &randomGenerator
  )

  for placed in placedItems {
    let resolvedScale = placed.scale
    let resolvedRotation = placed.rotation

    let resolvedSize = CGSize(
      width: tessera.size.width * resolvedScale,
      height: tessera.size.height * resolvedScale
    )

    var resolvedView = placed.item.makeView()
      .frame(width: resolvedSize.width, height: resolvedSize.height)
      .rotationEffect(resolvedRotation)

    let resolvedContext = context.resolve(resolvedView)
    context.draw(
      resolvedContext,
      at: placed.position,
      anchor: .center
    )
  }
}
```

You may already have most of this logic; the key difference is that `placedItems` now encapsulates position/scale/rotation instead of recomputing them ad hoc.

Once integrated, you can remove or deprecate `ItemAssigner` and possibly simplify `PoissonDiskGenerator` (if you fully move to rejection sampling).

---

## 7. Backwards compatibility & incremental rollout

To avoid breaking existing users:

1. Start by **adding** `collisionShape` but:
   - Keep existing `TesseraItem` initializers via an `approximateSize` convenience.
   - Default shapes to `.circle`.
2. Introduce `ShapePlacementEngine` behind a feature flag or configuration:
   - e.g. add a `placementMode` to `Tessera` (`.poissonRadius` vs `.shapeAware`).
3. Gradually migrate:
   - Presets → meaningful shapes.
   - Demo view → `shapeAware` mode.

This keeps the old behavior available and lets you compare visually.

---

## 8. Tuning & debugging

To debug collisions and gaps:

- Add an overlay mode that:
  - Draws each collision shape in semi-transparent colors on top of the tile (e.g. using polygons or circles).
  - Optionally shows bounding circles.
- Log or assert when placement fails too often, so you can adjust:
  - `targetCount`
  - `maxAttemptsPerItem`
  - scale ranges.

Potential tuning knobs:

- Consider a density factor if patterns look too sparse or dense.
- **minimumSpacing**: feed into average area calculation.
- **collisionShape** granularity: number of sides for circle approximations.

---

## 9. Future enhancements

- Per-item spacing multipliers (some items want more “air” around them).
- Different placement strategies (grid seeds, blue-noise patterns, clusters).
- Separate "visual" shape and "collision" shape (e.g. colliders slightly smaller than visible shapes to allow near-misses).

This plan should be enough to:
- Add a robust `CollisionShape` abstraction.
- Implement shape-aware placement with deterministic randomness.
- Gradually migrate your existing Tessera items and keep the system extensible.
