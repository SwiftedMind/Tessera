## [Upcoming]

### Added

### Enhanced
- **Faster Collision Placement**: Improves `ShapePlacementEngine` collision checks by caching polygon axes, avoiding per-test world-polygon allocations, and using a nearest-image torus offset (with a safe fallback) for seamless wrapping.

### Fixed

### Breaking Changes
- **Offset Collision Shapes**: `CollisionShape.circle(center:radius:)` and `CollisionShape.rectangle(center:size:)` add a local-space `center`, so colliders are no longer forced to be centered at the origin.
