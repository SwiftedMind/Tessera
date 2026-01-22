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
    TesseraTiledCanvas(
      DemoConfigurations.organic,
      tileSize: CGSize(width: 256, height: 256),
    )
    .ignoresSafeArea()
    .navigationTitle("Tiled Canvas")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct FiniteCanvasExampleView: View {
  var body: some View {
    TesseraCanvas(
      DemoConfigurations.organic,
      pinnedSymbols: DemoPinnedSymbols.hero,
      edgeBehavior: .finite,
    )
    .background(.black)
    .ignoresSafeArea()
    .navigationTitle("Finite Canvas")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct GridPlacementExampleView: View {
  var body: some View {
    TesseraTiledCanvas(
      DemoConfigurations.grid,
      tileSize: CGSize(width: 250, height: 250),
    )
    .ignoresSafeArea()
    .navigationTitle("Grid Placement")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct PolygonRegionExampleView: View {
  var body: some View {
    TesseraCanvas(
      DemoConfigurations.polygon,
      edgeBehavior: .finite,
      region: DemoRegions.mosaic,
    )
    .background(.black)
    .ignoresSafeArea()
    .navigationTitle("Polygon Region")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct CollisionShapeEditorExampleView: View {
  var body: some View {
    previewSymbol
      .collisionShapeEditor()
      .navigationTitle("Collision Shape Editor")
      .navigationBarTitleDisplayMode(.inline)
  }

  var previewSymbol: TesseraSymbol {
    TesseraSymbol(
      collisionShape: .polygon(points: [
        CGPoint(x: 6.46, y: 12.57),
        CGPoint(x: 6.74, y: 39.74),
        CGPoint(x: 28.65, y: 56.17),
        CGPoint(x: 49.01, y: 42.06),
        CGPoint(x: 48.73, y: 12.36),
        CGPoint(x: 27.95, y: 4.56),
      ]),
    ) {
      Image(systemName: "shield.fill")
        .font(.system(size: 52, weight: .semibold))
        .foregroundStyle(.primary)
    }
  }
}
