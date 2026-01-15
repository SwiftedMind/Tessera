// By Dennis Müller

import SwiftUI

/// Renders a single tessera tile into a cached symbol.
struct TesseraCanvasTile: View {
  var configuration: TesseraConfiguration
  var tileSize: CGSize
  var seed: UInt64
  var onComputationStateChange: ((Bool) -> Void)?

  @State private var cachedPlacedSymbolDescriptors: [ShapePlacementEngine.PlacedSymbolDescriptor] = []

  init(
    configuration: TesseraConfiguration,
    tileSize: CGSize,
    seed: UInt64,
    onComputationStateChange: ((Bool) -> Void)? = nil,
  ) {
    self.configuration = configuration
    self.tileSize = tileSize
    self.seed = seed
    self.onComputationStateChange = onComputationStateChange
  }

  var body: some View {
    let configuration = configuration
    let tileSize = tileSize
    let placedSymbolDescriptors = cachedPlacedSymbolDescriptors
    let onComputationStateChange = onComputationStateChange
    let isCollisionOverlayEnabled = configuration.showsCollisionOverlay
    let overlayShapesBySymbolId: [UUID: CollisionOverlayShape] = isCollisionOverlayEnabled
      ? configuration.symbols.reduce(into: [:]) { cache, symbol in
        cache[symbol.id] = CollisionOverlayShape(collisionShape: symbol.collisionShape)
      }
      : [:]

    Canvas(rendersAsynchronously: true) { context, size in
      let wrappedOffset = CGSize(
        width: configuration.patternOffset.width.truncatingRemainder(dividingBy: size.width),
        height: configuration.patternOffset.height.truncatingRemainder(dividingBy: size.height),
      )

      let offsets: [CGSize] = [
        .zero,
        CGSize(width: size.width, height: 0),
        CGSize(width: -size.width, height: 0),
        CGSize(width: 0, height: size.height),
        CGSize(width: 0, height: -size.height),
        CGSize(width: size.width, height: size.height),
        CGSize(width: size.width, height: -size.height),
        CGSize(width: -size.width, height: size.height),
        CGSize(width: -size.width, height: -size.height),
      ]

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
    .clipped()
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

    await MainActor.run {
      guard snapshot.key == currentComputationKey else { return }

      cachedPlacedSymbolDescriptors = placedSymbolDescriptors
    }
  }
}
