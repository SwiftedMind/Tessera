// By Dennis Müller

import SwiftUI
import Tessera

extension DemoDestination {
  func tiledCanvasView() -> some View {
    DemoExampleScreen(title: "Tiled Canvas") {
      Tessera(DemoConfigurations.organic)
        .mode(.tiled(tileSize: CGSize(width: 256, height: 256)))
        .seed(.fixed(0))
        .background(DemoPalette.canvasBackground)
    }
  }

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
  func mosaicCanvasView() -> some View {
    DemoExampleScreen(title: "Mosaic Canvas (Live)") {
      Tessera(DemoConfigurations.mosaicSnapshot)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(2602))
        .debugOverlay(.mosaicMasks(opacity: 0.22))
        .background(DemoPalette.canvasBackground)
    }
  }

  func mosaicSnapshotView() -> some View {
    DemoExampleScreen(title: "Mosaic Snapshot") {
      MosaicSnapshotCanvasExample()
    }
  }

  func gridPlacementView() -> some View {
    DemoExampleScreen(title: "Grid Placement") {
      InterleavedGridCanvas()
    }
  }

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

  func gridColumnMajorView() -> some View {
    DemoExampleScreen(title: "Grid Column Major") {
      Tessera(DemoConfigurations.gridColumnMajor)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(314))
        .background(DemoPalette.canvasBackground)
    }
  }

  func gridSubgridsView() -> some View {
    DemoExampleScreen(title: "Grid Subgrids") {
      Tessera(DemoConfigurations.gridSubgrids)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(222))
        .background(DemoPalette.canvasBackground)
    }
  }

  func denseOrganicView() -> some View {
    DemoExampleScreen(title: "Dense Organic", ignoresSafeArea: false) {
      ViewThatFits {
        HStack(spacing: 14) {
          DenseOrganicPanel(title: "Rejection", pattern: DemoConfigurations.denseOrganicRejection)
          DenseOrganicPanel(title: "Dense", pattern: DemoConfigurations.denseOrganic)
        }
        .padding(18)

        VStack(spacing: 14) {
          DenseOrganicPanel(title: "Rejection", pattern: DemoConfigurations.denseOrganicRejection)
          DenseOrganicPanel(title: "Dense", pattern: DemoConfigurations.denseOrganic)
        }
        .padding(18)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(DemoPalette.canvasBackground.ignoresSafeArea())
    }
  }

  func denseOrganicRegionView() -> some View {
    DemoExampleScreen(title: "Dense Organic Region") {
      Tessera(DemoConfigurations.denseOrganicRegion)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(405))
        .region(DemoRegions.mosaic)
        .regionRendering(.clipped)
        .background(DemoPalette.canvasBackground)
    }
  }

  func choiceSymbolsView() -> some View {
    ChoiceSymbolsExampleView()
  }

  func choiceIndexSequenceView() -> some View {
    ChoiceIndexSequenceExampleView()
  }

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

private struct DenseOrganicPanel: View {
  let title: String
  let pattern: Pattern

  var body: some View {
    VStack(spacing: 10) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(DemoPalette.strokePrimary.opacity(0.82))
        .frame(maxWidth: .infinity, alignment: .leading)

      Tessera(pattern)
        .mode(.canvas(edgeBehavior: .finite))
        .seed(.fixed(404))
        .background(DemoPalette.canvasBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DemoPalette.strokePrimary.opacity(0.16), lineWidth: 1)
        }
    }
    .frame(maxWidth: 360, maxHeight: 520)
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
