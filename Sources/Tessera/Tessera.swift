// By Dennis Müller

import SwiftUI

/// Primary Tessera rendering entry point.
///
/// Build a `Pattern` once, then progressively configure rendering behavior with chained modifiers.
///
/// Example:
/// ```swift
/// Tessera(pattern)
///   .mode(.tiled(tileSize: .init(width: 256, height: 256)))
///   .seed(.fixed(42))
/// ```
public struct Tessera: View {
  /// The pattern definition to render.
  public var pattern: Pattern
  /// Whether rendering should produce a single tile, repeated tiling, or a finite canvas.
  public var mode: Mode
  /// Deterministic seed behavior.
  public var seed: Seed
  /// Placement and clipping region.
  public var region: Region
  /// Symbols pinned as fixed obstacles/content in canvas and tile modes.
  public var pinnedSymbols: [PinnedSymbol]
  /// Region clipping strategy.
  public var regionRendering: RegionRendering
  /// Whether drawing should be done asynchronously in the underlying SwiftUI canvas.
  public var rendersAsynchronously: Bool
  /// Optional debug overlay rendered beneath symbols.
  public var debugOverlay: TesseraDebugOverlay
  /// Callback that reports whether Tessera is actively computing placements.
  public var onComputationStateChange: ((Bool) -> Void)?

  @State private var automaticSeed: UInt64 = Pattern.randomSeed()
  @State private var snapshot: TesseraSnapshot?

  /// Creates a Tessera renderer for a pattern.
  ///
  /// Defaults:
  /// - mode: `.tiled(tileSize: 256x256)`
  /// - seed: `.automatic`
  /// - region: `.rectangle`
  /// - region rendering: `.clipped`
  ///
  /// - Parameter pattern: The pattern definition containing symbols and placement behavior.
  public init(_ pattern: Pattern) {
    self.pattern = pattern
    mode = .tiled()
    seed = .automatic
    region = .rectangle
    pinnedSymbols = []
    regionRendering = .clipped
    rendersAsynchronously = false
    debugOverlay = .none
    onComputationStateChange = nil
  }

  /// Renders Tessera using the current mode and options.
  public var body: some View {
    Group {
      switch mode {
      case let .canvas(size: nil, edgeBehavior: edgeBehavior):
        GeometryReader { proxy in
          snapshotBackedContent(
            resolvedMode: .canvas(size: proxy.size, edgeBehavior: edgeBehavior),
          )
        }
      default:
        snapshotBackedContent(resolvedMode: mode)
      }
    }
  }

  @ViewBuilder
  private func snapshotBackedContent(resolvedMode: Mode) -> some View {
    let resolvedSize = resolvedMode.snapshotResolvedSize
    let pattern = pattern
    let resolvedSeedMode = resolvedSeedMode
    let resolvedSeedValue = resolveSeedValue(for: resolvedSeedMode, pattern: pattern)
    let region = region
    let regionRendering = regionRendering
    let pinnedSymbols = pinnedSymbols
    let debugOverlay = resolvedSnapshotDebugOverlay
    let onComputationStateChange = onComputationStateChange
    let requestKey = SnapshotRequestKey.make(
      mode: resolvedMode,
      resolvedSeed: resolvedSeedValue,
      region: region,
      regionRendering: regionRendering,
      pinnedSymbols: pinnedSymbols,
    )
    let taskKey = SnapshotTaskKey(
      requestFingerprint: TesseraFingerprintBuilder.fingerprint(
        pattern: pattern,
        requestKey: requestKey,
      ),
    )

    Group {
      if let snapshot {
        TesseraSnapshotView(
          snapshot: snapshot,
          rendersAsynchronously: rendersAsynchronously,
          debugOverlay: debugOverlay,
        )
      } else {
        Color.clear
      }
    }
    .frame(
      width: resolvedMode.frameSize?.width,
      height: resolvedMode.frameSize?.height,
    )
    .task(id: taskKey) {
      guard resolvedSize.width > 0, resolvedSize.height > 0 else { return }

      onComputationStateChange?(true)
      defer { onComputationStateChange?(false) }

      do {
        let renderer = TesseraRenderer(pattern)
        let computedSnapshot = try await renderer.makeSnapshot(
          mode: resolvedMode,
          seed: resolvedSeedMode,
          region: region,
          regionRendering: regionRendering,
          pinnedSymbols: pinnedSymbols,
        )
        guard Task.isCancelled == false else { return }

        snapshot = computedSnapshot
      } catch {
        // Keep the previous snapshot visible on failures.
      }
    }
  }

  var resolvedSeedMode: Seed {
    switch seed {
    case .automatic:
      if pattern.placementSeed != nil {
        return .automatic
      }
      return .fixed(automaticSeed)
    case let .fixed(value):
      return .fixed(value)
    }
  }

  func resolveSeedValue(for seedMode: Seed, pattern: Pattern) -> UInt64 {
    switch seedMode {
    case .automatic:
      pattern.placementSeed ?? automaticSeed
    case let .fixed(value):
      value
    }
  }

  var resolvedSnapshotDebugOverlay: TesseraDebugOverlay {
    debugOverlay.addingCollisionShapesIfNeeded(pattern.showsCollisionOverlay)
  }
}

public extension Tessera {
  /// Returns a copy configured with a rendering mode.
  func mode(_ mode: Mode) -> Tessera {
    var copy = self
    copy.mode = mode
    return copy
  }

  /// Returns a copy configured with a deterministic seed mode.
  func seed(_ seed: Seed) -> Tessera {
    var copy = self
    copy.seed = seed
    return copy
  }

  /// Returns a copy configured with a placement and clipping region.
  func region(_ region: Region) -> Tessera {
    var copy = self
    copy.region = region
    return copy
  }

  /// Returns a copy with fixed symbols that are rendered and used as placement obstacles.
  func pinnedSymbols(_ symbols: [PinnedSymbol]) -> Tessera {
    var copy = self
    copy.pinnedSymbols = symbols
    return copy
  }

  /// Returns a copy configured with region rendering behavior.
  func regionRendering(_ rendering: RegionRendering) -> Tessera {
    var copy = self
    copy.regionRendering = rendering
    return copy
  }

  /// Returns a copy configured for asynchronous canvas drawing.
  func rendersAsynchronously(_ enabled: Bool) -> Tessera {
    var copy = self
    copy.rendersAsynchronously = enabled
    return copy
  }

  /// Returns a copy configured with a debug overlay.
  func debugOverlay(_ overlay: TesseraDebugOverlay) -> Tessera {
    var copy = self
    copy.debugOverlay = overlay
    return copy
  }

  /// Returns a copy configured with a computation-state callback.
  func onComputationStateChange(_ action: @escaping (Bool) -> Void) -> Tessera {
    var copy = self
    copy.onComputationStateChange = action
    return copy
  }
}

/// Tessera rendering output mode.
public enum Mode: Hashable, Sendable {
  /// Generate one seamless tile and repeat it to fill available space.
  case tiled(tileSize: CGSize = CGSize(width: 256, height: 256))
  /// Generate exactly one seamless tile at a fixed size.
  case tile(size: CGSize)
  /// Generate one finite canvas composition.
  ///
  /// Pass `size` when using snapshot APIs directly.
  /// In live SwiftUI rendering, `nil` size resolves from layout.
  case canvas(size: CGSize? = nil, edgeBehavior: EdgeBehavior = .finite)
}

/// Seed behavior used for deterministic pattern generation.
public enum Seed: Hashable, Sendable {
  /// Use placement-provided seed when available, otherwise generate one automatically.
  case automatic
  /// Force a specific seed value.
  case fixed(UInt64)
}

private extension Mode {
  var snapshotResolvedSize: CGSize {
    switch self {
    case let .tile(size), let .tiled(tileSize: size):
      size
    case let .canvas(size, _):
      size ?? .zero
    }
  }

  var frameSize: CGSize? {
    switch self {
    case let .tile(size):
      size
    case let .canvas(size, _):
      size
    case .tiled:
      nil
    }
  }
}

private extension Pattern {
  var showsCollisionOverlay: Bool {
    switch placement {
    case let .organic(organicPlacement):
      organicPlacement.showsCollisionOverlay
    case .grid:
      false
    }
  }
}

private struct SnapshotTaskKey: Hashable {
  var requestFingerprint: UInt64
}
