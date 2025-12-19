## [Upcoming]

### Added
- **Collision Overlay Debugging**: `TesseraConfiguration.showsCollisionOverlay` draws collision shapes on canvas views,
  and `TesseraRenderOptions.showsCollisionOverlay` opt-in enables overlays for exports.
- **Compound Collision Shapes**: `CollisionShape.polygons(pointSets:)` and `CollisionShape.anchoredPolygon(pointSets:anchor:size:)` let a single item use multiple polygons
  for collision checks; complex shapes can dramatically reduce placement performance.

### Enhanced
- **Faster Collision Placement**: Improves `ShapePlacementEngine` collision checks by caching polygon axes, avoiding per-test world-polygon allocations, and using a nearest-image torus offset (with a safe fallback) for seamless wrapping.
- **Concave Polygon Collisions**: Concave polygons are decomposed into convex pieces for more accurate collisions, at a
  higher placement cost for complex shapes.
- **Per-Polygon Broad Phase**: Adds per-piece bounding circle checks to skip expensive narrow-phase tests when compound
  shapes are far apart.

### Fixed

### Breaking Changes
- **Offset Collision Shapes**: `CollisionShape.circle(center:radius:)` and `CollisionShape.rectangle(center:size:)` add a local-space `center`, so colliders are no longer forced to be centered at the origin.
- **View-Space Polygon Defaults**: `CollisionShape.polygon(points:)` and `CollisionShape.polygons(points:)` now interpret
  points as anchored to the top leading edge of the view, instead of the center.
- **Expanded CollisionShape Cases**: `CollisionShape` adds new polygon variants, so exhaustive `switch` statements must
  handle centered and anchored polygons.
