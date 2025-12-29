// By Dennis Müller

import SwiftUI

/// Renders a single tessera tile into a cached symbol.
struct TesseraCanvasTile: View {
  var configuration: TesseraConfiguration
  var tileSize: CGSize
  var seed: UInt64
  /// Whether to render wrapped duplicates inside the tile for seamless edge previews.
  var showsWrappedDuplicates: Bool
  var onComputationStateChange: ((Bool) -> Void)?

  @State private var cachedPlacedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor] = []
  /// Cached overlap counts for debugging seamless placement.
  @State private var cachedOverlapCounts: CollisionOverlapCounts = .empty

  init(
    configuration: TesseraConfiguration,
    tileSize: CGSize,
    seed: UInt64,
    showsWrappedDuplicates: Bool,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.tileSize = tileSize
    self.seed = seed
    self.showsWrappedDuplicates = showsWrappedDuplicates
    self.onComputationStateChange = onComputationStateChange
  }

  var body: some View {
    let configuration = configuration
    let tileSize = tileSize
    let placedSymbolDescriptors = cachedPlacedSymbolDescriptors
    let overlapCounts = cachedOverlapCounts
    let onComputationStateChange = onComputationStateChange
    let isCollisionOverlayEnabled = configuration.showsCollisionOverlay
    let overlayShapesBySymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? configuration.symbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]

    let canvas = Canvas(rendersAsynchronously: true) { context, size in
      let wrappedOffset = CGSize(
        width: configuration.patternOffset.width.truncatingRemainder(dividingBy: size.width),
        height: configuration.patternOffset.height.truncatingRemainder(dividingBy: size.height),
      )

      let offsets: [CGSize] = showsWrappedDuplicates ? [
        .zero,
        CGSize(width: size.width, height: 0),
        CGSize(width: -size.width, height: 0),
        CGSize(width: 0, height: size.height),
        CGSize(width: 0, height: -size.height),
        CGSize(width: size.width, height: size.height),
        CGSize(width: size.width, height: -size.height),
        CGSize(width: -size.width, height: size.height),
        CGSize(width: -size.width, height: -size.height),
      ] : [.zero]

      for placedSymbol in placedSymbolDescriptors {
        guard let symbol = context.resolveSymbol(id: placedSymbol.symbolId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width + wrappedOffset.width, y: offset.height + wrappedOffset.height)
          symbolContext.translateBy(x: placedSymbol.position.x, y: placedSymbol.position.y)
          symbolContext.rotate(by: .radians(placedSymbol.rotationRadians))
          symbolContext.scaleBy(x: placedSymbol.scale, y: placedSymbol.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)

          if isCollisionOverlayEnabled,
             let overlayShape = overlayShapesBySymbolId[placedSymbol.symbolId] {
            CollisionOverlayRenderer.draw(overlayShape: overlayShape, in: &symbolContext)
          }
        }
      }
    } symbols: {
      ForEach(configuration.symbols) { symbol in
        symbol.makeView().tag(symbol.id)
      }
    }
    .frame(width: tileSize.width, height: tileSize.height)

    Group {
      if showsWrappedDuplicates {
        canvas
      } else {
        canvas.clipped()
      }
    }
    .overlay {
      if isCollisionOverlayEnabled {
        Rectangle()
          .stroke(Color.red.opacity(0.6), lineWidth: 1)
      }
    }
    .overlay(alignment: .topLeading) {
      if isCollisionOverlayEnabled {
        let wrapText = showsWrappedDuplicates ? "Tile Wrap: On" : "Tile Wrap: Off"
        Text("\(wrapText) · Local: \(overlapCounts.local) · Seam: \(overlapCounts.seam)")
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 4)
          .background(Color.red.opacity(0.85))
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .padding(6)
      }
    }
    .task(id: currentComputationKey) {
      await MainActor.run {
        onComputationStateChange?(true)
      }
      defer {
        if Task.isCancelled == false {
          Task { @MainActor in
            onComputationStateChange?(false)
          }
        }
      }

      let snapshot = makeComputationSnapshot()
      await computePlacements(using: snapshot)
    }
  }
}

private extension TesseraCanvasTile {
  struct ComputationKey: Hashable, Sendable {
    var tileSize: CGSize
    var placement: TesseraPlacement
    var patternOffset: CGSize
    var symbolKeys: [SymbolKey]

    struct SymbolKey: Hashable, Sendable {
      var id: UUID
      var weight: Double
      var allowedRotationRangeDegrees: ClosedRange<Double>
      var resolvedScaleRange: ClosedRange<Double>
      var collisionShape: CollisionShape
    }
  }

  struct ComputationSnapshot: Sendable {
    var key: ComputationKey
    var symbolDescriptors: [ShapePlacementEngine.PlacementSymbolDescriptor]
  }

  var resolvedPlacement: TesseraPlacement {
    switch configuration.placement {
    case var .organic(organicPlacement):
      organicPlacement.seed = seed
      return .organic(organicPlacement)
    case .grid:
      return configuration.placement
    }
  }

  var currentComputationKey: ComputationKey {
    let symbolKeys: [ComputationKey.SymbolKey] = configuration.symbols.map { symbol in
      let scaleRange = resolvedScaleRange(for: symbol, placement: resolvedPlacement)
      return ComputationKey.SymbolKey(
        id: symbol.id,
        weight: symbol.weight,
        allowedRotationRangeDegrees: symbol.allowedRotationRange.lowerBound.degrees...symbol.allowedRotationRange
          .upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: symbol.collisionShape,
      )
    }

    return ComputationKey(
      tileSize: tileSize,
      placement: resolvedPlacement,
      patternOffset: configuration.patternOffset,
      symbolKeys: symbolKeys,
    )
  }

  func makeComputationSnapshot() -> ComputationSnapshot {
    let symbolDescriptors: [ShapePlacementEngine.PlacementSymbolDescriptor] = configuration.symbols.map { symbol in
      let scaleRange = resolvedScaleRange(for: symbol, placement: resolvedPlacement)
      return ShapePlacementEngine.PlacementSymbolDescriptor(
        id: symbol.id,
        weight: symbol.weight,
        allowedRotationRangeDegrees: symbol.allowedRotationRange.lowerBound.degrees...symbol.allowedRotationRange
          .upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: symbol.collisionShape,
      )
    }

    return ComputationSnapshot(
      key: currentComputationKey,
      symbolDescriptors: symbolDescriptors,
    )
  }

  func resolvedScaleRange(
    for symbol: TesseraSymbol,
    placement: TesseraPlacement,
  ) -> ClosedRange<Double> {
    switch placement {
    case let .organic(organicPlacement):
      symbol.scaleRange ?? organicPlacement.baseScaleRange
    case .grid:
      symbol.scaleRange ?? 1...1
    }
  }

  func seed(for placement: TesseraPlacement) -> UInt64 {
    switch placement {
    case let .organic(organicPlacement):
      organicPlacement.seed
    case .grid:
      0
    }
  }

  func computePlacements(using snapshot: ComputationSnapshot) async {
    let placementSeed = seed(for: snapshot.key.placement)
    let computeTask = Task.detached(priority: .userInitiated) {
      var randomGenerator = SeededGenerator(seed: placementSeed)
      return ShapePlacementEngine.placeSymbolDescriptors(
        in: snapshot.key.tileSize,
        symbolDescriptors: snapshot.symbolDescriptors,
        edgeBehavior: .seamlessWrapping,
        placement: snapshot.key.placement,
        randomGenerator: &randomGenerator,
      )
    }

    let placedSymbolDescriptors = await withTaskCancellationHandler {
      await computeTask.value
    } onCancel: {
      computeTask.cancel()
    }

    let overlapCounts = configuration.showsCollisionOverlay
      ? CollisionOverlapDiagnostics.overlapCounts(
        in: placedSymbolDescriptors,
        tileSize: snapshot.key.tileSize,
        edgeBehavior: .seamlessWrapping,
      )
      : .empty

    await MainActor.run {
      guard snapshot.key == currentComputationKey else { return }

      cachedPlacedSymbolDescriptors = placedSymbolDescriptors
      cachedOverlapCounts = overlapCounts
    }
  }
}

/// Stores overlap counts for local and seam checks.
private struct CollisionOverlapCounts: Sendable {
  var local: Int
  var seam: Int

  static let empty = CollisionOverlapCounts(local: 0, seam: 0)
}

/// Computes overlap counts for placed symbols.
private enum CollisionOverlapDiagnostics {
  /// Counts overlaps inside the tile and across the seam.
  static func overlapCounts(
    in placedSymbols: [ShapePlacementEngine.PlacedSymbolDescriptor],
    tileSize: CGSize,
    edgeBehavior: TesseraEdgeBehavior,
  ) -> CollisionOverlapCounts {
    guard placedSymbols.count > 1 else { return .empty }

    let wrapOffsets = ShapePlacementWrapping.wrapOffsets(for: tileSize, edgeBehavior: edgeBehavior)
    let seamOffsets = wrapOffsets.filter { $0 != .zero }
    let polygonCache: [UUID: [CollisionPolygon]] = placedSymbols.reduce(into: [:]) { cache, symbol in
      cache[symbol.symbolId] = CollisionMath.polygons(for: symbol.collisionShape)
    }

    var localCount = 0
    var seamCount = 0

    for firstIndex in placedSymbols.indices {
      let first = placedSymbols[firstIndex]
      let firstTransform = first.collisionTransform
      let firstBoundingRadius = first.collisionShape.boundingRadius(atScale: firstTransform.scale)
      guard let firstPolygons = polygonCache[first.symbolId] else { continue }

      for secondIndex in placedSymbols.indices where secondIndex > firstIndex {
        let second = placedSymbols[secondIndex]
        let secondBoundingRadius = second.collisionShape.boundingRadius(atScale: second.scale)
        guard let secondPolygons = polygonCache[second.symbolId] else { continue }

        if overlaps(
          first: first,
          firstPolygons: firstPolygons,
          firstRadius: firstBoundingRadius,
          second: second,
          secondPolygons: secondPolygons,
          secondRadius: secondBoundingRadius,
          offset: .zero,
        ) {
          localCount += 1
          continue
        }

        if seamOffsets.contains(where: { offset in
          overlaps(
            first: first,
            firstPolygons: firstPolygons,
            firstRadius: firstBoundingRadius,
            second: second,
            secondPolygons: secondPolygons,
            secondRadius: secondBoundingRadius,
            offset: offset,
          )
        }) {
          seamCount += 1
        }
      }
    }

    return CollisionOverlapCounts(local: localCount, seam: seamCount)
  }

  private static func overlaps(
    first: ShapePlacementEngine.PlacedSymbolDescriptor,
    firstPolygons: [CollisionPolygon],
    firstRadius: CGFloat,
    second: ShapePlacementEngine.PlacedSymbolDescriptor,
    secondPolygons: [CollisionPolygon],
    secondRadius: CGFloat,
    offset: CGPoint,
  ) -> Bool {
    let shiftedPosition = CGPoint(
      x: second.position.x + offset.x,
      y: second.position.y + offset.y,
    )
    let deltaX = first.position.x - shiftedPosition.x
    let deltaY = first.position.y - shiftedPosition.y
    let combinedRadius = firstRadius + secondRadius
    guard deltaX * deltaX + deltaY * deltaY <= combinedRadius * combinedRadius else { return false }

    let shiftedTransform = CollisionTransform(
      position: shiftedPosition,
      rotation: CGFloat(second.rotationRadians),
      scale: second.scale,
    )

    return CollisionMath.polygonsIntersect(
      firstPolygons,
      transformA: first.collisionTransform,
      secondPolygons,
      transformB: shiftedTransform,
    )
  }
}
