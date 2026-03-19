// By Dennis Müller

import SwiftUI
import Tessera

extension DemoDestination {
  @ViewBuilder
  func tiledCanvasView() -> some View {
    DemoExampleScreen(title: "Tiled Canvas") {
      Tessera(DemoConfigurations.organic)
        .mode(.tiled(tileSize: CGSize(width: 256, height: 256)))
        .seed(.fixed(0))
        .background(DemoPalette.canvasBackground)
    }
  }

  @ViewBuilder
  func finiteCanvasView() -> some View {
    DemoExampleScreen(title: "Finite Canvas") {
      Tessera(DemoConfigurations.organic)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(0))
        .pinnedSymbols(DemoPinnedSymbols.hero)
        .background(DemoPalette.canvasBackground)
    }
  }

  /// Live canvas example using mosaics without explicit snapshot APIs.
  @ViewBuilder
  func mosaicCanvasView() -> some View {
    DemoExampleScreen(title: "Mosaic Canvas (Live)") {
      Tessera(DemoConfigurations.mosaicSnapshot)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(2602))
        .debugOverlay(.mosaicMasks(opacity: 0.22))
        .background(DemoPalette.canvasBackground)
    }
  }

  @ViewBuilder
  func mosaicSnapshotView() -> some View {
    DemoExampleScreen(title: "Mosaic Snapshot") {
      MosaicSnapshotCanvasExample()
    }
  }

  @ViewBuilder
  func gridPlacementView() -> some View {
    DemoExampleScreen(title: "Grid Placement") {
      InterleavedGridCanvas()
    }
  }

  @ViewBuilder
  func fixedCellGridView() -> some View {
    DemoExampleScreen(title: "Fixed Cell Grid", ignoresSafeArea: false) {
      VStack(spacing: 20) {
        Text("The grid starts outside the visible canvas, so the first and last cells are intentionally clipped.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
          .padding(.top, 24)

        ZStack {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(DemoPalette.canvasBackground)

          Tessera(DemoConfigurations.grid)
            .mode(.canvas(edgeBehavior: .finite))
            .seed(.fixed(0))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(width: 220, height: 220)
        .overlay {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(DemoPalette.strokePrimary.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(DemoPalette.canvasBackground.ignoresSafeArea())
    }
  }

  @ViewBuilder
  func gridColumnMajorView() -> some View {
    DemoExampleScreen(title: "Grid Column Major") {
      Tessera(DemoConfigurations.gridColumnMajor)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(314))
        .background(DemoPalette.canvasBackground)
    }
  }

  @ViewBuilder
  func gridSubgridsView() -> some View {
    DemoExampleScreen(title: "Grid Subgrids") {
      Tessera(DemoConfigurations.gridSubgrids)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(222))
        .background(DemoPalette.canvasBackground)
    }
  }

  @ViewBuilder
  func choiceSymbolsView() -> some View {
    ChoiceSymbolsExampleView()
  }

  @ViewBuilder
  func choiceIndexSequenceView() -> some View {
    ChoiceIndexSequenceExampleView()
  }

  @ViewBuilder
  func polygonRegionView() -> some View {
    DemoExampleScreen(title: "Polygon Region") {
      Tessera(DemoConfigurations.polygon)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(14))
        .region(DemoRegions.mosaic)
        .regionRendering(.unclipped)
        .background(DemoPalette.canvasBackground)
    }
  }

  @ViewBuilder
  func alphaMaskRegionView() -> some View {
    DemoExampleScreen(title: "Alpha Mask Region") {
      Tessera(DemoConfigurations.alphaMask)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(7))
        .region(DemoExampleAssets.alphaMaskRegion)
        .regionRendering(.clipped)
        .background(DemoPalette.canvasBackground)
    }
  }
}

/// Snapshot-first mosaic demo that computes once and then renders from a cached snapshot.
private struct MosaicSnapshotCanvasExample: View {
  private static let cacheVersion = "v3"
  @State private var snapshot: TesseraSnapshot?
  @State private var errorMessage: String?

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        DemoPalette.canvasBackground

        if let snapshot {
          TesseraSnapshotView(
            snapshot: snapshot,
            debugOverlay: .mosaicMasks(opacity: 0.22),
          )
        } else if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(DemoPalette.strokePrimary)
            .padding(24)
        } else {
          ProgressView("Computing Snapshot…")
            .tint(DemoPalette.strokePrimary)
            .foregroundStyle(DemoPalette.strokePrimary)
        }
      }
      .task(id: snapshotTaskID(for: proxy.size)) {
        await updateSnapshot(for: proxy.size)
      }
    }
  }

  private func snapshotTaskID(for size: CGSize) -> String {
    "\(Self.cacheVersion)-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
  }

  @MainActor
  private func updateSnapshot(for size: CGSize) async {
    guard size.width > 2, size.height > 2 else { return }

    let cacheKey = snapshotTaskID(for: size)

    if let cachedSnapshot = await DemoMosaicSnapshotCache.shared.snapshot(for: cacheKey) {
      snapshot = cachedSnapshot
      errorMessage = nil
      return
    }

    do {
      let renderer = TesseraRenderer(DemoConfigurations.mosaicSnapshot)
      let computedSnapshot = try await renderer.makeSnapshot(
        mode: .canvas(size: size, edgeBehavior: .finite),
        seed: .fixed(2602),
      )
      await DemoMosaicSnapshotCache.shared.store(computedSnapshot, for: cacheKey)
      snapshot = computedSnapshot
      errorMessage = nil
    } catch is CancellationError {
      // Ignore stale computations when view size changes quickly.
    } catch {
      errorMessage = "Snapshot failed: \(error.localizedDescription)"
    }
  }
}

/// Per-size snapshot cache used by the demo screen to avoid recomputation while navigating.
private actor DemoMosaicSnapshotCache {
  static let shared = DemoMosaicSnapshotCache()
  private var storage: [String: TesseraSnapshot] = [:]

  func snapshot(for key: String) -> TesseraSnapshot? {
    storage[key]
  }

  func store(_ snapshot: TesseraSnapshot, for key: String) {
    storage[key] = snapshot
  }
}
