// By Dennis Müller

/// Defines the complete, user-facing catalog of demo examples.
enum DemoCatalog {
  static let sections: [DemoCatalogSection] = [
    DemoCatalogSection(
      id: "canvases",
      title: "Canvases",
      summary: "Core canvas and region rendering demos.",
      examples: [
        DemoCatalogExample(
          destination: .tiledCanvas,
          title: "Tiled Canvas",
          summary: "Seamless repeatable background",
          systemImage: "square.grid.3x3.fill",
        ),
        DemoCatalogExample(
          destination: .finiteCanvas,
          title: "Finite Canvas",
          summary: "Pinned symbols and organic fill",
          systemImage: "rectangle.and.pencil.and.ellipsis",
        ),
        DemoCatalogExample(
          destination: .gridPlacement,
          title: "Grid Placement",
          summary: "Interleaved lattice via symbol phases",
          systemImage: "square.grid.2x2",
        ),
        DemoCatalogExample(
          destination: .gridColumnMajor,
          title: "Grid Column Major",
          summary: "Top-to-bottom symbol assignment order",
          systemImage: "arrow.down.to.line.compact",
        ),
        DemoCatalogExample(
          destination: .gridSubgrids,
          title: "Grid Subgrids",
          summary: "Dedicated symbol pools in sub-areas",
          systemImage: "square.grid.3x3",
        ),
        DemoCatalogExample(
          destination: .choiceSymbols,
          title: "Choice Symbols",
          summary: "One symbol resolves weighted variants",
          systemImage: "dice",
        ),
        DemoCatalogExample(
          destination: .choiceIndexSequence,
          title: "Choice Index Sequence",
          summary: "Explicit child index placement order",
          systemImage: "list.number",
        ),
        DemoCatalogExample(
          destination: .polygonRegion,
          title: "Polygon Region",
          summary: "Fill an arbitrary outline",
          systemImage: "scribble.variable",
        ),
        DemoCatalogExample(
          destination: .alphaMaskRegion,
          title: "Alpha Mask Region",
          summary: "Fill the shape of a view",
          systemImage: "circle.hexagonpath.fill",
        ),
      ],
    ),
    DemoCatalogSection(
      id: "spatial-steering",
      title: "Spatial Steering",
      summary: "Gradient and radial steering controls for spacing, scale, and rotation.",
      examples: [
        DemoCatalogExample(
          destination: .organicSpacingGradient,
          title: "Organic Spacing Gradient",
          summary: "Dense top, spacious bottom",
          systemImage: "arrow.down.to.line.compact",
        ),
        DemoCatalogExample(
          destination: .organicScaleGradient,
          title: "Organic Scale Gradient",
          summary: "Small left, large right",
          systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
        ),
        DemoCatalogExample(
          destination: .gridScaleGradient,
          title: "Grid Scale Gradient",
          summary: "Diagonal size steering",
          systemImage: "arrow.down.right.and.arrow.up.left",
        ),
        DemoCatalogExample(
          destination: .organicRadialScale,
          title: "Organic Radial Scale",
          summary: "Center small, edges large",
          systemImage: "circle.lefthalf.filled",
        ),
        DemoCatalogExample(
          destination: .organicRotationGradient,
          title: "Organic Rotation Gradient",
          summary: "Top-to-bottom rotation offset",
          systemImage: "arrow.clockwise.circle",
        ),
        DemoCatalogExample(
          destination: .gridRadialRotation,
          title: "Grid Radial Rotation",
          summary: "Center calm, edges rotated",
          systemImage: "scope",
        ),
        DemoCatalogExample(
          destination: .gridRotationGradient,
          title: "Grid Rotation Gradient",
          summary: "Left-to-right rotation multiplier",
          systemImage: "arrow.left.and.right.circle",
        ),
      ],
    ),
    DemoCatalogSection(
      id: "tools",
      title: "Tools",
      summary: "Utility screens that help inspect and tune symbols.",
      examples: [
        DemoCatalogExample(
          destination: .collisionShapeEditor,
          title: "Collision Shape Editor",
          summary: "Edit symbol collision geometry",
          systemImage: "viewfinder",
        ),
      ],
    ),
  ]
}
