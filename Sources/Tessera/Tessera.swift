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
  /// Callback that reports whether Tessera is actively computing placements.
  public var onComputationStateChange: ((Bool) -> Void)?

  @State private var automaticSeed: UInt64 = Pattern.randomSeed()

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
    onComputationStateChange = nil
  }

  /// Renders Tessera using the current mode and options.
  public var body: some View {
    switch mode {
    case let .canvas(edgeBehavior):
      TesseraCanvas(
        pattern.legacyConfiguration,
        pinnedSymbols: pinnedSymbols,
        seed: resolvedSeed(fallbackToAutomatic: true),
        edgeBehavior: edgeBehavior,
        region: region,
        regionRendering: regionRendering,
        rendersAsynchronously: rendersAsynchronously,
        onComputationStateChange: onComputationStateChange,
      )
    case let .tile(size):
      tileCanvas(tileSize: size)
    case let .tiled(tileSize):
      tiledCanvas(tileSize: tileSize)
    }
  }

  private func tileCanvas(tileSize: CGSize) -> some View {
    TesseraCanvas(
      pattern.legacyConfiguration,
      pinnedSymbols: pinnedSymbols,
      seed: resolvedSeed(fallbackToAutomatic: true),
      edgeBehavior: .seamlessWrapping,
      region: region,
      regionRendering: regionRendering,
      rendersAsynchronously: rendersAsynchronously,
      onComputationStateChange: onComputationStateChange,
    )
    .frame(width: tileSize.width, height: tileSize.height)
  }

  private func tiledCanvas(tileSize: CGSize) -> some View {
    let rendersAsynchronously = rendersAsynchronously

    return Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: rendersAsynchronously,
    ) { context, size in
      guard tileSize.width > 0, tileSize.height > 0 else { return }
      guard let tile = context.resolveSymbol(id: 0) else { return }

      let columns = Int(ceil(size.width / tileSize.width))
      let rows = Int(ceil(size.height / tileSize.height))

      for row in 0..<rows {
        for column in 0..<columns {
          let x = CGFloat(column) * tileSize.width + tileSize.width / 2
          let y = CGFloat(row) * tileSize.height + tileSize.height / 2
          context.draw(tile, at: CGPoint(x: x, y: y), anchor: .center)
        }
      }
    } symbols: {
      tileCanvas(tileSize: tileSize)
        .frame(width: tileSize.width, height: tileSize.height)
        .tag(0)
    }
  }

  func resolvedSeed(fallbackToAutomatic: Bool) -> UInt64? {
    switch seed {
    case .automatic:
      if let placementSeed = pattern.placementSeed {
        return placementSeed
      }
      return fallbackToAutomatic ? automaticSeed : nil
    case let .fixed(value):
      return value
    }
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
  case canvas(edgeBehavior: EdgeBehavior = .finite)
}

/// Seed behavior used for deterministic pattern generation.
public enum Seed: Hashable, Sendable {
  /// Use placement-provided seed when available, otherwise generate one automatically.
  case automatic
  /// Force a specific seed value.
  case fixed(UInt64)
}
