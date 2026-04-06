// By Dennis Müller

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Snapshot-first Tessera renderer that supports compute-once/render-many workflows.
public struct TesseraRenderer: Sendable {
  /// Pattern used for snapshot computation.
  public var pattern: Pattern

  private let computationActor = SnapshotComputationActor()

  /// Creates a renderer for the provided pattern.
  public init(_ pattern: Pattern) {
    self.pattern = pattern
  }

  /// Computes a reusable snapshot for the given render inputs.
  public func makeSnapshot(
    mode: Mode,
    seed: Seed = .automatic,
    region: Region = .rectangle,
    regionRendering: RegionRendering = .clipped,
    pinnedSymbols: [PinnedSymbol] = [],
  ) async throws -> TesseraSnapshot {
    let pattern = pattern
    let computationActor = computationActor
    let resolvedSize = try resolveSize(for: mode)
    let resolvedSeed = resolveSeed(seed)

    return try await computationActor.compute(
      pattern: pattern,
      mode: mode,
      resolvedSize: resolvedSize,
      resolvedSeed: resolvedSeed,
      region: region,
      regionRendering: regionRendering,
      pinnedSymbols: pinnedSymbols,
    ) { _ in }
  }

  /// Computes a reusable snapshot while emitting progress events.
  public func makeSnapshotEvents(
    mode: Mode,
    seed: Seed = .automatic,
    region: Region = .rectangle,
    regionRendering: RegionRendering = .clipped,
    pinnedSymbols: [PinnedSymbol] = [],
  ) -> AsyncThrowingStream<TesseraComputationEvent, Error> {
    let pattern = pattern
    let computationActor = computationActor
    return AsyncThrowingStream { continuation in
      let continuationBox = EventContinuationBox(continuation)
      let resolvedSize: CGSize
      do {
        resolvedSize = try resolveSize(for: mode)
      } catch {
        continuation.finish(throwing: error)
        return
      }
      let resolvedSeed = resolveSeed(seed)

      let task = Task {
        do {
          _ = try await computationActor.compute(
            pattern: pattern,
            mode: mode,
            resolvedSize: resolvedSize,
            resolvedSeed: resolvedSeed,
            region: region,
            regionRendering: regionRendering,
            pinnedSymbols: pinnedSymbols,
          ) { event in
            continuationBox.continuation.yield(event)
          }
          continuationBox.continuation.finish()
        } catch is CancellationError {
          continuationBox.continuation.finish()
        } catch {
          continuationBox.continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}

public extension TesseraRenderer {
  /// Exports a precomputed snapshot in PNG or PDF format.
  @MainActor
  @discardableResult
  func export(
    _ format: ExportFormat,
    snapshot: TesseraSnapshot,
    options: ExportOptions,
  ) throws -> URL {
    try validate(snapshot: snapshot)

    switch format {
    case .png:
      return try renderPNG(snapshot: snapshot, options: options)
    case .pdf:
      return try renderPDF(snapshot: snapshot, options: options)
    }
  }
}

private extension TesseraRenderer {
  func resolveSeed(_ seed: Seed) -> UInt64 {
    switch seed {
    case .automatic:
      pattern.placementSeed ?? Pattern.randomSeed()
    case let .fixed(value):
      value
    }
  }

  func resolveSize(for mode: Mode) throws -> CGSize {
    switch mode {
    case let .tile(size), let .tiled(tileSize: size):
      return size
    case let .canvas(size, _):
      guard let size else { throw RenderError.missingCanvasSize }

      return size
    }
  }

  func validate(snapshot: TesseraSnapshot) throws {
    let expectedFingerprint = TesseraFingerprint(
      rawValue: TesseraFingerprintBuilder.fingerprint(
        pattern: pattern,
        requestKey: snapshot.requestKey,
      ),
    )
    guard expectedFingerprint == snapshot.fingerprint else {
      throw RenderError.snapshotFingerprintMismatch
    }
  }

  @MainActor
  func renderPNG(
    snapshot: TesseraSnapshot,
    options: ExportOptions,
  ) throws -> URL {
    let destinationURL = resolvedOutputURL(
      directory: options.directory,
      fileName: options.fileName,
      fileExtension: "png",
    )
    let pageSize = snapshot.size
    let rendererContent = makeRendererContent(
      snapshot: snapshot,
      options: options,
      pageSize: pageSize,
    )
    let renderer = ImageRenderer(content: rendererContent)
    renderer.proposedSize = ProposedViewSize(pageSize)
    renderer.scale = options.render.resolvedScale(contentSize: pageSize)
    renderer.isOpaque = options.render.isOpaque
    renderer.colorMode = options.render.colorMode

    guard let cgImage = renderer.cgImage else {
      throw RenderError.failedToCreateImage
    }
    guard let destination = CGImageDestinationCreateWithURL(
      destinationURL as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil,
    ) else {
      throw RenderError.failedToCreateDestination
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw RenderError.failedToFinalizeDestination
    }

    return destinationURL
  }

  @MainActor
  func renderPDF(
    snapshot: TesseraSnapshot,
    options: ExportOptions,
  ) throws -> URL {
    let destinationURL = resolvedOutputURL(
      directory: options.directory,
      fileName: options.fileName,
      fileExtension: "pdf",
    )
    let pageSize = options.pageSize ?? snapshot.size
    var mediaBox = CGRect(origin: .zero, size: pageSize)

    guard
      let consumer = CGDataConsumer(url: destinationURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else {
      throw RenderError.failedToCreateDestination
    }

    let rendererContent = makeRendererContent(
      snapshot: snapshot,
      options: options,
      pageSize: pageSize,
    )
    let renderer = ImageRenderer(content: rendererContent)
    renderer.proposedSize = ProposedViewSize(pageSize)
    renderer.scale = options.render.resolvedScale(contentSize: snapshot.size)
    renderer.isOpaque = options.render.isOpaque
    renderer.colorMode = options.render.colorMode

    let rasterizationScale = options.render.resolvedScale(contentSize: snapshot.size)
    renderer.render(rasterizationScale: rasterizationScale) { _, render in
      context.beginPDFPage(nil)
      render(context)
      context.endPDFPage()
      context.closePDF()
    }

    return destinationURL
  }

  func resolvedOutputURL(directory: URL, fileName: String, fileExtension: String) -> URL {
    let baseName = (fileName as NSString).deletingPathExtension
    return directory
      .appending(path: baseName)
      .appendingPathExtension(fileExtension)
  }

  @MainActor
  func makeRendererContent(
    snapshot: TesseraSnapshot,
    options: ExportOptions,
    pageSize: CGSize,
  ) -> AnyView {
    let content = SnapshotExportRenderView(
      pageSize: pageSize,
      backgroundColor: options.backgroundColor,
      content: TesseraSnapshotView(
        snapshot: snapshot,
        debugOverlay: options.render.showsCollisionOverlay ? .collisionShapes : .none,
      ),
    )
    if let colorScheme = options.colorScheme {
      return AnyView(content.environment(\.colorScheme, colorScheme))
    } else {
      return AnyView(content)
    }
  }
}

private struct SnapshotExportRenderView<Content: View>: View {
  var pageSize: CGSize
  var backgroundColor: Color?
  var content: Content

  var body: some View {
    ZStack {
      if let backgroundColor {
        backgroundColor
      }
      content
    }
    .frame(width: pageSize.width, height: pageSize.height)
    .clipped()
  }
}

/// Actor that serializes snapshot computations and drops stale completions.
actor SnapshotComputationActor {
  private var activeComputationID: UInt64 = 0
  private var activeComputationTask: Task<TesseraSnapshot, Error>?

  func compute(
    pattern: Pattern,
    mode: Mode,
    resolvedSize: CGSize,
    resolvedSeed: UInt64,
    region: Region,
    regionRendering: RegionRendering,
    pinnedSymbols: [PinnedSymbol],
    onEvent: @escaping @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> TesseraSnapshot {
    activeComputationID &+= 1
    let computationID = activeComputationID
    onEvent(.started)
    activeComputationTask?.cancel()

    let planner = MosaicPlacementPlanner(
      inputs: .init(
        pattern: pattern,
        mode: mode,
        resolvedSize: resolvedSize,
        resolvedSeed: resolvedSeed,
        region: region,
        regionRendering: regionRendering,
        pinnedSymbols: pinnedSymbols,
      ),
    )
    let computationTask = Task {
      try await planner.makeSnapshot(onEvent: onEvent)
    }
    activeComputationTask = computationTask

    do {
      let snapshot = try await computationTask.value
      guard computationID == activeComputationID else {
        throw CancellationError()
      }

      onEvent(.completed(snapshot))
      if computationID == activeComputationID {
        activeComputationTask = nil
      }
      return snapshot
    } catch {
      if computationID == activeComputationID {
        activeComputationTask = nil
      }
      throw error
    }
  }
}

/// Sendable box used to yield stream events from async tasks safely.
private final class EventContinuationBox: @unchecked Sendable {
  var continuation: AsyncThrowingStream<TesseraComputationEvent, Error>.Continuation

  init(_ continuation: AsyncThrowingStream<TesseraComputationEvent, Error>.Continuation) {
    self.continuation = continuation
  }
}
