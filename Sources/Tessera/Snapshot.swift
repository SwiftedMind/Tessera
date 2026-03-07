// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Optional debug overlays for snapshot-backed rendering.
public enum TesseraDebugOverlay: Hashable, Sendable {
  /// No debug overlay.
  case none
  /// Renders collision-shape overlays for symbols and pinned symbols.
  case collisionShapes
  /// Renders translucent fills for each effective mosaic mask.
  case mosaicMasks(opacity: Double = 0.18)
  /// Renders collision shapes and translucent mosaic masks together.
  case collisionShapesAndMosaicMasks(opacity: Double = 0.18)
}

/// Deterministic identity for a computed Tessera snapshot.
public struct TesseraFingerprint: Hashable, Sendable {
  /// Raw fingerprint value.
  public var rawValue: UInt64

  /// Creates a fingerprint from a raw value.
  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }
}

/// Progress events emitted while computing a `TesseraSnapshot`.
public enum TesseraComputationEvent: Sendable {
  /// Snapshot planning started.
  case started
  /// Mosaic mask coverage is being prepared.
  case preparingMasks(completed: Int, total: Int)
  /// Mosaic placement layers are being computed.
  case placingMosaics(completed: Int, total: Int)
  /// Base-layer placement is being computed.
  case placingBaseSymbols
  /// Final snapshot is available.
  case completed(TesseraSnapshot)
}

/// A fully prepared, reusable Tessera render snapshot.
public struct TesseraSnapshot: @unchecked Sendable {
  /// Rendering mode this snapshot was computed for.
  public var mode: Mode
  /// Resolved canvas or tile size.
  public var size: CGSize
  /// Strict compatibility fingerprint.
  public var fingerprint: TesseraFingerprint

  var requestKey: SnapshotRequestKey
  var renderModel: SnapshotRenderModel

  init(
    mode: Mode,
    size: CGSize,
    fingerprint: TesseraFingerprint,
    requestKey: SnapshotRequestKey,
    renderModel: SnapshotRenderModel,
  ) {
    self.mode = mode
    self.size = size
    self.fingerprint = fingerprint
    self.requestKey = requestKey
    self.renderModel = renderModel
  }
}

/// Renders a precomputed `TesseraSnapshot` without re-running placement.
public struct TesseraSnapshotView: View {
  /// Snapshot to render.
  public var snapshot: TesseraSnapshot
  /// Whether drawing should use asynchronous `Canvas` rendering.
  public var rendersAsynchronously: Bool
  /// Optional debug overlay rendered beneath symbols.
  public var debugOverlay: TesseraDebugOverlay

  /// Creates a snapshot-backed render view.
  public init(
    snapshot: TesseraSnapshot,
    rendersAsynchronously: Bool = false,
    debugOverlay: TesseraDebugOverlay = .none,
  ) {
    self.snapshot = snapshot
    self.rendersAsynchronously = rendersAsynchronously
    self.debugOverlay = debugOverlay
  }

  public var body: some View {
    switch snapshot.mode {
    case .tile:
      SnapshotStaticCanvasView(
        snapshot: snapshot,
        rendersAsynchronously: rendersAsynchronously,
        debugOverlay: debugOverlay,
      )
      .frame(width: snapshot.size.width, height: snapshot.size.height)

    case .canvas:
      SnapshotStaticCanvasView(
        snapshot: snapshot,
        rendersAsynchronously: rendersAsynchronously,
        debugOverlay: debugOverlay,
      )
      .frame(width: snapshot.size.width, height: snapshot.size.height)

    case let .tiled(tileSize):
      SnapshotTiledCanvasView(
        tileSize: tileSize,
        tileView: SnapshotStaticCanvasView(
          snapshot: snapshot,
          rendersAsynchronously: rendersAsynchronously,
          debugOverlay: debugOverlay,
        )
        .frame(width: tileSize.width, height: tileSize.height),
        rendersAsynchronously: rendersAsynchronously,
      )
    }
  }
}

extension TesseraDebugOverlay {
  /// Returns whether collision-shape overlays should be drawn.
  var showsCollisionShapes: Bool {
    switch self {
    case .none, .mosaicMasks:
      false
    case .collisionShapes, .collisionShapesAndMosaicMasks:
      true
    }
  }

  /// Returns the effective opacity for mosaic-mask overlays, or `nil` when disabled.
  var resolvedMosaicMaskOpacity: Double? {
    switch self {
    case .none, .collisionShapes:
      nil
    case let .mosaicMasks(opacity):
      max(0, min(opacity, 1))
    case let .collisionShapesAndMosaicMasks(opacity):
      max(0, min(opacity, 1))
    }
  }

  func addingCollisionShapesIfNeeded(_ isEnabled: Bool) -> TesseraDebugOverlay {
    guard isEnabled else { return self }

    switch self {
    case .none:
      return .collisionShapes
    case .collisionShapes:
      return .collisionShapes
    case let .mosaicMasks(opacity):
      return .collisionShapesAndMosaicMasks(opacity: opacity)
    case let .collisionShapesAndMosaicMasks(opacity):
      return .collisionShapesAndMosaicMasks(opacity: opacity)
    }
  }
}
