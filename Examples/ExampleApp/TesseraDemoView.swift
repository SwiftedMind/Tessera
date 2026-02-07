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
              subtitle: "Deterministic grid with offsets",
              systemImage: "square.grid.2x2",
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
    Tessera(DemoConfigurations.grid)
      .mode(.tiled(tileSize: CGSize(width: 250, height: 250)))
      .ignoresSafeArea()
      .navigationTitle("Grid Placement")
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
