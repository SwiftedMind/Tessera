// By Dennis Müller

import SwiftUI
import Tessera

struct TesseraDemoView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Canvases") {
          NavigationLink {
            TiledCanvasExampleView()
          } label: {
            ExampleRow(
              title: "Tiled Canvas",
              subtitle: "Seamless repeatable background",
              systemImage: "square.grid.3x3.fill",
            )
          }
          NavigationLink {
            FiniteCanvasExampleView()
          } label: {
            ExampleRow(
              title: "Finite Canvas",
              subtitle: "Pinned symbols and organic fill",
              systemImage: "rectangle.and.pencil.and.ellipsis",
            )
          }
          NavigationLink {
            GridPlacementExampleView()
          } label: {
            ExampleRow(
              title: "Grid Placement",
              subtitle: "Interleaved lattice via symbol phases",
              systemImage: "square.grid.2x2",
            )
          }
          NavigationLink {
            MergedGridCellsExampleView()
          } label: {
            ExampleRow(
              title: "Merged Grid Cells",
              subtitle: "Rectangular grid cell spans",
              systemImage: "square.grid.3x3",
            )
          }
          NavigationLink {
            ChoiceSymbolsExampleView()
          } label: {
            ExampleRow(
              title: "Choice Symbols",
              subtitle: "One symbol resolves weighted variants",
              systemImage: "dice",
            )
          }
          NavigationLink {
            ChoiceIndexSequenceExampleView()
          } label: {
            ExampleRow(
              title: "Choice Index Sequence",
              subtitle: "Explicit child index placement order",
              systemImage: "list.number",
            )
          }
          NavigationLink {
            PolygonRegionExampleView()
          } label: {
            ExampleRow(
              title: "Polygon Region",
              subtitle: "Fill an arbitrary outline",
              systemImage: "scribble.variable",
            )
          }
          NavigationLink {
            AlphaMaskRegionExampleView()
          } label: {
            ExampleRow(
              title: "Alpha Mask Region",
              subtitle: "Fill the shape of a view",
              systemImage: "circle.hexagonpath.fill",
            )
          }
        }
        Section("Spatial Steering") {
          NavigationLink {
            OrganicSpacingSteeringExampleView()
          } label: {
            ExampleRow(
              title: "Organic Spacing Gradient",
              subtitle: "Dense top, spacious bottom",
              systemImage: "arrow.down.to.line.compact",
            )
          }
          NavigationLink {
            OrganicScaleSteeringExampleView()
          } label: {
            ExampleRow(
              title: "Organic Scale Gradient",
              subtitle: "Small left, large right",
              systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
            )
          }
          NavigationLink {
            GridScaleSteeringExampleView()
          } label: {
            ExampleRow(
              title: "Grid Scale Gradient",
              subtitle: "Diagonal size steering",
              systemImage: "arrow.down.right.and.arrow.up.left",
            )
          }
          NavigationLink {
            OrganicRadialScaleSteeringExampleView()
          } label: {
            ExampleRow(
              title: "Organic Radial Scale",
              subtitle: "Center small, edges large",
              systemImage: "circle.lefthalf.filled",
            )
          }
          NavigationLink {
            OrganicRotationSteeringExampleView()
          } label: {
            ExampleRow(
              title: "Organic Rotation Gradient",
              subtitle: "Top-to-bottom rotation offset",
              systemImage: "arrow.clockwise.circle",
            )
          }
          NavigationLink {
            GridRadialRotationSteeringExampleView()
          } label: {
            ExampleRow(
              title: "Grid Radial Rotation",
              subtitle: "Center calm, edges rotated",
              systemImage: "scope",
            )
          }
          NavigationLink {
            GridRotationSteeringExampleView()
          } label: {
            ExampleRow(
              title: "Grid Rotation Gradient",
              subtitle: "Left-to-right rotation multiplier",
              systemImage: "arrow.left.and.right.circle",
            )
          }
        }
        Section("Tools") {
          NavigationLink {
            CollisionShapeEditorExampleView()
          } label: {
            ExampleRow(
              title: "Collision Shape Editor",
              subtitle: "Edit symbol collision geometry",
              systemImage: "viewfinder",
            )
          }
        }
      }
      .navigationTitle("Tessera Examples")
    }
  }
}

#Preview { TesseraDemoView().preferredColorScheme(.dark) }

private struct ExampleRow: View {
  var title: String
  var subtitle: String
  var systemImage: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(.primary)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct TiledCanvasExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.organic)
      .mode(.tiled(tileSize: CGSize(width: 256, height: 256)))
      .seed(.fixed(0))
      .ignoresSafeArea()
      .navigationTitle("Tiled Canvas")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct FiniteCanvasExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.organic)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(0))
      .pinnedSymbols(DemoPinnedSymbols.hero)
      .background(.black)
      .ignoresSafeArea()
      .navigationTitle("Finite Canvas")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct GridPlacementExampleView: View {
  var body: some View {
    InterleavedGridCanvas()
      .ignoresSafeArea()
      .navigationTitle("Grid Placement")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct MergedGridCellsExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.gridMergedCells)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(222))
      .background(.black)
      .ignoresSafeArea()
      .navigationTitle("Merged Grid Cells")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct PolygonRegionExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.polygon)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(14))
      .region(DemoRegions.mosaic)
      .regionRendering(.unclipped)
      .background(.black)
      .ignoresSafeArea()
      .navigationTitle("Polygon Region")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct AlphaMaskRegionExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.alphaMask)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(7))
      .region(alphaMaskRegion)
      .regionRendering(.clipped)
      .background(.black)
      .ignoresSafeArea()
      .navigationTitle("Alpha Mask Region")
      .navigationBarTitleDisplayMode(.inline)
  }

  private var alphaMaskRegion: Region {
    .alphaMask(
      AlphaMask(
        cacheKey: "alpha-mask-demo",
        alphaThreshold: 0.2,
        sampling: .bilinear,
      ) {
        AlphaMaskShape()
      },
    )
  }
}

private struct AlphaMaskShape: View {
  var body: some View {
    Image(systemName: "sparkles")
      .font(.system(size: 120, weight: .bold))
      .foregroundStyle(.black.opacity(0.7))
      .padding(20)
  }
}

private struct CollisionShapeEditorExampleView: View {
  var body: some View {
    previewSymbol
      .collisionShapeEditor()
      .navigationTitle("Collision Shape Editor")
      .navigationBarTitleDisplayMode(.inline)
  }

  var previewSymbol: Symbol {
    Symbol(
      collider: .shape(.polygon(points: [
        CGPoint(x: 6.46, y: 12.57),
        CGPoint(x: 6.74, y: 39.74),
        CGPoint(x: 28.65, y: 56.17),
        CGPoint(x: 49.01, y: 42.06),
        CGPoint(x: 48.73, y: 12.36),
        CGPoint(x: 27.95, y: 4.56),
      ])),
    ) {
      Image(systemName: "shield.fill")
        .font(.system(size: 52, weight: .semibold))
        .foregroundStyle(.primary)
    }
  }
}

private struct OrganicSpacingSteeringExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.organicSpacingGradient)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(21))
      .background(.black)
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Minimum Spacing",
          startLabel: "top: tight",
          endLabel: "bottom: wide",
          axisSymbol: "arrow.down",
        )
      }
      .navigationTitle("Organic Spacing Gradient")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct OrganicScaleSteeringExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.organicScaleGradient)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(34))
      .background(.black)
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Symbol Scale",
          startLabel: "left: small",
          endLabel: "right: large",
          axisSymbol: "arrow.right",
        )
      }
      .navigationTitle("Organic Scale Gradient")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct GridScaleSteeringExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.gridScaleGradient)
      .mode(.tiled(tileSize: CGSize(width: 260, height: 260)))
      .seed(.fixed(55))
      .background(.black)
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Grid Scale",
          startLabel: "top-left: small",
          endLabel: "bottom-right: large",
          axisSymbol: "arrow.down.right",
        )
      }
      .navigationTitle("Grid Scale Gradient")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct OrganicRotationSteeringExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.organicRotationGradient)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(89))
      .background(.black)
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Rotation Offset",
          startLabel: "top: +0°",
          endLabel: "bottom: +180°",
          axisSymbol: "arrow.down.circle",
        )
      }
      .navigationTitle("Organic Rotation Gradient")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct GridRotationSteeringExampleView: View {
  var body: some View {
    Tessera(DemoConfigurations.gridRotationGradient)
      .mode(.canvas(edgeBehavior: .finite))
      .seed(.fixed(121))
      .background(.black)
      .ignoresSafeArea()
      .overlay(alignment: .topLeading) {
        SteeringLegendOverlay(
          title: "Rotation Multiplier",
          startLabel: "left: 0.5×",
          endLabel: "right: 1.5×",
          axisSymbol: "arrow.right.circle",
        )
      }
      .navigationTitle("Grid Rotation Gradient")
      .navigationBarTitleDisplayMode(.inline)
  }
}

struct SteeringLegendOverlay: View {
  var title: String
  var startLabel: String
  var endLabel: String
  var axisSymbol: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
      HStack(spacing: 6) {
        Image(systemName: axisSymbol)
          .font(.caption2.weight(.semibold))
        Text(startLabel)
          .font(.caption2)
      }
      Text(endLabel)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .padding(16)
  }
}
