# Placement

This folder implements symbol placement for a single tile. The public entry point is
`ShapePlacementEngine`, which delegates to one of two placement engines and shares
common collision and wrapping helpers.

## Layout

- `ShapePlacementEngine.swift`
  - The entry point used by the rest of Tessera.
  - Converts `TesseraSymbol` values into internal descriptors, then dispatches to the
    organic or grid engine.
- `OrganicShapePlacementEngine.swift`
  - Rejection-samples positions and checks collisions using a spatial grid.
  - Designed for varied, organic layouts with density and minimum spacing.
- `GridShapePlacementEngine.swift`
  - Places symbols on a deterministic grid with optional row/column offsets.
  - Designed for repeating, predictable layouts.
- `Shared/ShapePlacementEngine+Types.swift`
  - Shared descriptor and helper structs used by both engines.
- `Shared/ShapePlacementCollision.swift`
  - Collision checks that account for spacing and seamless wrapping.
- `Shared/ShapePlacementWrapping.swift`
  - Wrap and index helpers for seamless tiling.

## How it fits together

1. `ShapePlacementEngine.placeSymbols` resolves the public `TesseraSymbol` data into
   `PlacementSymbolDescriptor` values and builds pinned symbol descriptors.
2. It calls `ShapePlacementEngine.placeSymbolDescriptors`, which selects a placement
   engine based on `TesseraPlacement`.
3. The chosen engine creates `PlacedSymbolDescriptor` values and relies on shared
   collision and wrapping helpers to validate placements.
4. The entry point converts the placed descriptors back into `PlacedSymbol` values.

## Example flow (organic)

```swift
let descriptors = ShapePlacementEngine.placeSymbolDescriptors(
  in: tileSize,
  symbolDescriptors: symbols,
  pinnedSymbolDescriptors: pinnedSymbols,
  edgeBehavior: .seamlessWrapping,
  placement: .organic(configuration),
  randomGenerator: &generator
)
```

The organic engine:

1. Estimates a target count from density and minimum spacing.
2. Picks a symbol by weight.
3. Samples positions until a collision-free placement is found.
4. Repeats until the target count is met or attempts are exhausted.

## Example flow (grid)

```swift
let descriptors = ShapePlacementEngine.placeSymbolDescriptors(
  in: tileSize,
  symbolDescriptors: symbols,
  pinnedSymbolDescriptors: pinnedSymbols,
  edgeBehavior: .seamlessWrapping,
  placement: .grid(configuration),
  randomGenerator: &generator
)
```

The grid engine:

1. Resolves a grid size and cell dimensions from the configuration.
2. Computes each cell center and applies any row/column offset.
3. Validates placements against pinned symbols.
4. Returns all accepted placements.

## Notes

- All coordinates are in tile space.
- Seamless wrapping uses a 3x3 lattice of offsets so symbols that cross edges remain
  collision-safe when the tile repeats.
