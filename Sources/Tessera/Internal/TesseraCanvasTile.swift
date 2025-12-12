// By Dennis Müller

import SwiftUI

/// Renders a single tessera tile into a cached symbol.
struct TesseraCanvasTile: View {
  var configuration: TesseraConfiguration
  var tileSize: CGSize
  var seed: UInt64
  var onComputationStateChange: ((Bool) -> Void)?

  @State private var cachedPlacedItemDescriptors: [ShapePlacementEngine.PlacedItemDescriptor] = []

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
    let placedItemDescriptors = cachedPlacedItemDescriptors
    let onComputationStateChange = onComputationStateChange

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

      for placedItem in placedItemDescriptors {
        guard let symbol = context.resolveSymbol(id: placedItem.itemId) else { continue }

        for offset in offsets {
          var symbolContext = context
          symbolContext.translateBy(x: offset.width + wrappedOffset.width, y: offset.height + wrappedOffset.height)
          symbolContext.translateBy(x: placedItem.position.x, y: placedItem.position.y)
          symbolContext.rotate(by: .radians(placedItem.rotationRadians))
          symbolContext.scaleBy(x: placedItem.scale, y: placedItem.scale)
          symbolContext.draw(symbol, at: .zero, anchor: .center)
        }
      }
    } symbols: {
      ForEach(configuration.items) { item in
        item.makeView().tag(item.id)
      }
    }
    .frame(width: tileSize.width, height: tileSize.height)
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
    var seed: UInt64
    var minimumSpacing: Double
    var density: Double
    var baseScaleRangeLowerBound: Double
    var baseScaleRangeUpperBound: Double
    var patternOffset: CGSize
    var maximumItemCount: Int
    var itemKeys: [ItemKey]

    struct ItemKey: Hashable, Sendable {
      var id: UUID
      var weight: Double
      var allowedRotationRangeDegrees: ClosedRange<Double>
      var resolvedScaleRange: ClosedRange<Double>
      var collisionShape: CollisionShape
    }
  }

  struct ComputationSnapshot: Sendable {
    var key: ComputationKey
    var itemDescriptors: [ShapePlacementEngine.PlacementItemDescriptor]
  }

  var currentComputationKey: ComputationKey {
    let itemKeys: [ComputationKey.ItemKey] = configuration.items.map { item in
      let scaleRange = item.scaleRange ?? configuration.baseScaleRange
      return ComputationKey.ItemKey(
        id: item.id,
        weight: item.weight,
        allowedRotationRangeDegrees: item.allowedRotationRange.lowerBound.degrees...item.allowedRotationRange.upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: item.collisionShape,
      )
    }

    return ComputationKey(
      tileSize: tileSize,
      seed: seed,
      minimumSpacing: configuration.minimumSpacing,
      density: configuration.density,
      baseScaleRangeLowerBound: configuration.baseScaleRange.lowerBound,
      baseScaleRangeUpperBound: configuration.baseScaleRange.upperBound,
      patternOffset: configuration.patternOffset,
      maximumItemCount: configuration.maximumItemCount,
      itemKeys: itemKeys,
    )
  }

  func makeComputationSnapshot() -> ComputationSnapshot {
    let itemDescriptors: [ShapePlacementEngine.PlacementItemDescriptor] = configuration.items.map { item in
      let scaleRange = item.scaleRange ?? configuration.baseScaleRange
      return ShapePlacementEngine.PlacementItemDescriptor(
        id: item.id,
        weight: item.weight,
        allowedRotationRangeDegrees: item.allowedRotationRange.lowerBound.degrees...item.allowedRotationRange.upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: item.collisionShape,
      )
    }

    return ComputationSnapshot(
      key: currentComputationKey,
      itemDescriptors: itemDescriptors,
    )
  }

  func computePlacements(using snapshot: ComputationSnapshot) async {
    let computeTask = Task.detached(priority: .userInitiated) {
      var randomGenerator = SeededGenerator(seed: snapshot.key.seed)
      return ShapePlacementEngine.placeItemDescriptors(
        in: snapshot.key.tileSize,
        itemDescriptors: snapshot.itemDescriptors,
        edgeBehavior: .seamlessWrapping,
        minimumSpacing: snapshot.key.minimumSpacing,
        density: snapshot.key.density,
        maximumItemCount: snapshot.key.maximumItemCount,
        randomGenerator: &randomGenerator,
      )
    }

    let placedItemDescriptors = await withTaskCancellationHandler {
      await computeTask.value
    } onCancel: {
      computeTask.cancel()
    }

    await MainActor.run {
      guard snapshot.key == currentComputationKey else { return }

      cachedPlacedItemDescriptors = placedItemDescriptors
    }
  }
}
