// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

extension TesseraCanvas {
  var shouldClipPolygon: Bool {
    region.isPolygon && regionRendering == .clipped
  }

  var shouldClipAlphaMask: Bool {
    region.isAlphaMask && regionRendering == .clipped
  }

  var effectiveEdgeBehavior: TesseraEdgeBehavior {
    switch region {
    case .rectangle:
      edgeBehavior
    case .polygon:
      .finite
    case .alphaMask:
      .finite
    }
  }

  struct ComputationKey: Hashable, Sendable {
    var canvasSize: CGSize
    var edgeBehavior: TesseraEdgeBehavior
    var placement: TesseraPlacement
    var patternOffset: CGSize
    var patternRotationRadians: Double
    var patternRotationAnchorX: Double
    var patternRotationAnchorY: Double
    var symbolKeys: [SymbolKey]
    var pinnedSymbolKeys: [PinnedSymbolKey]
    var region: TesseraCanvasRegion

    struct SymbolKey: Hashable, Sendable {
      var id: UUID
      var weight: Double
      var allowedRotationRangeDegrees: ClosedRange<Double>
      var resolvedScaleRange: ClosedRange<Double>
      var collisionShape: CollisionShape
    }

    struct PinnedSymbolKey: Hashable, Sendable {
      enum PositionKind: Hashable, Sendable {
        case absolute
        case relative
      }

      var id: UUID
      var positionKind: PositionKind
      var absoluteX: Double
      var absoluteY: Double
      var unitPointX: Double
      var unitPointY: Double
      var offsetWidth: Double
      var offsetHeight: Double
      var rotationRadians: Double
      var scale: CGFloat
      var collisionShape: CollisionShape
    }
  }

  struct ComputationSnapshot: Sendable {
    var key: ComputationKey
    var symbolDescriptors: [ShapePlacementEngine.PlacementSymbolDescriptor]
    var pinnedSymbolDescriptors: [ShapePlacementEngine.PinnedSymbolDescriptor]
    var resolvedRegion: TesseraResolvedPolygonRegion?
    var resolvedAlphaMask: TesseraAlphaMask?
  }

  var resolvedPlacement: TesseraPlacement {
    switch configuration.placement {
    case var .organic(organicPlacement):
      organicPlacement.seed = seed
      return .organic(organicPlacement)
    case var .grid(gridPlacement):
      gridPlacement.seed = seed
      return .grid(gridPlacement)
    }
  }

  func makeComputationSnapshot(
    for canvasSize: CGSize,
    resolvedAlphaMask: TesseraAlphaMask?,
  ) -> ComputationSnapshot {
    let key = makeComputationKey(for: canvasSize)
    let resolvedRegion = region.resolvedPolygon(in: canvasSize)
    return ComputationSnapshot(
      key: key,
      symbolDescriptors: makeSymbolDescriptors(using: key.placement),
      pinnedSymbolDescriptors: makePinnedSymbolDescriptors(
        for: canvasSize,
        region: resolvedRegion,
        alphaMask: resolvedAlphaMask,
      ),
      resolvedRegion: resolvedRegion,
      resolvedAlphaMask: resolvedAlphaMask,
    )
  }

  func computePlacements(
    key: ComputationKey,
    symbolDescriptors: [ShapePlacementEngine.PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [ShapePlacementEngine.PinnedSymbolDescriptor],
    resolvedRegion: TesseraResolvedPolygonRegion?,
    resolvedAlphaMask: TesseraAlphaMask?,
  ) async {
    let placementSeed = seed(for: key.placement)
    let canvasSize = key.canvasSize
    let edgeBehavior = key.edgeBehavior
    let placement = key.placement

    let computeTask = Task.detached(priority: .userInitiated) {
      var randomGenerator = SeededGenerator(seed: placementSeed)
      let patternRotationAnchor = CGPoint(
        x: canvasSize.width * CGFloat(key.patternRotationAnchorX),
        y: canvasSize.height * CGFloat(key.patternRotationAnchorY),
      )
      return ShapePlacementEngine.placeSymbolDescriptors(
        in: canvasSize,
        symbolDescriptors: symbolDescriptors,
        pinnedSymbolDescriptors: pinnedSymbolDescriptors,
        edgeBehavior: edgeBehavior,
        placement: placement,
        region: resolvedRegion,
        alphaMask: resolvedAlphaMask,
        patternRotationRadians: key.patternRotationRadians,
        patternRotationAnchor: patternRotationAnchor,
        randomGenerator: &randomGenerator,
      )
    }

    let placedSymbolDescriptors = await withTaskCancellationHandler {
      await computeTask.value
    } onCancel: {
      computeTask.cancel()
    }

    await MainActor.run {
      guard activeComputationKey == key else { return }

      cachedPlacedSymbolDescriptors = placedSymbolDescriptors
    }
  }

  @MainActor func makeSynchronousPlacedDescriptors(
    for canvasSize: CGSize,
    resolvedAlphaMask: TesseraAlphaMask? = nil,
  ) -> [ShapePlacementEngine.PlacedSymbolDescriptor] {
    let placement = resolvedPlacement
    let symbolDescriptors = makeSymbolDescriptors(using: placement)
    let resolvedRegion = region.resolvedPolygon(in: canvasSize)
    let resolvedAlphaMask = resolvedAlphaMask ?? region.resolvedAlphaMask(in: canvasSize)
    let pinnedSymbolDescriptors = makePinnedSymbolDescriptors(
      for: canvasSize,
      region: resolvedRegion,
      alphaMask: resolvedAlphaMask,
    )
    var randomGenerator = SeededGenerator(seed: seed(for: placement))
    let patternRotationRadians = RotationMath.normalizedRadians(configuration.patternRotation.radians)
    let patternRotationAnchor = CGPoint(
      x: canvasSize.width * configuration.patternRotationAnchor.x,
      y: canvasSize.height * configuration.patternRotationAnchor.y,
    )
    return ShapePlacementEngine.placeSymbolDescriptors(
      in: canvasSize,
      symbolDescriptors: symbolDescriptors,
      pinnedSymbolDescriptors: pinnedSymbolDescriptors,
      edgeBehavior: effectiveEdgeBehavior,
      placement: placement,
      region: resolvedRegion,
      alphaMask: resolvedAlphaMask,
      patternRotationRadians: patternRotationRadians,
      patternRotationAnchor: patternRotationAnchor,
      randomGenerator: &randomGenerator,
    )
  }

  func makeSymbolDescriptors(using placement: TesseraPlacement) -> [ShapePlacementEngine.PlacementSymbolDescriptor] {
    configuration.symbols.map { symbol in
      let scaleRange = resolvedScaleRange(for: symbol, placement: placement)
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
  }

  func makePinnedSymbolDescriptors(
    for canvasSize: CGSize,
    region: TesseraResolvedPolygonRegion?,
    alphaMask: TesseraAlphaMask?,
  ) -> [ShapePlacementEngine.PinnedSymbolDescriptor] {
    pinnedSymbols.compactMap { pinnedSymbol in
      let position = pinnedSymbol.resolvedPosition(in: canvasSize)
      let radius = pinnedSymbol.collisionShape.boundingRadius(atScale: pinnedSymbol.scale)
      if let region {
        let expandedBounds = region.bounds.insetBy(dx: -radius, dy: -radius)
        if expandedBounds.contains(position) == false {
          return nil
        }
      }

      if let alphaMask, alphaMaskContainsPinnedSymbol(alphaMask, center: position, radius: radius) == false {
        return nil
      }

      return ShapePlacementEngine.PinnedSymbolDescriptor(
        id: pinnedSymbol.id,
        position: position,
        rotationRadians: pinnedSymbol.rotation.radians,
        scale: pinnedSymbol.scale,
        collisionShape: pinnedSymbol.collisionShape,
      )
    }
  }

  func alphaMaskContainsPinnedSymbol(_ alphaMask: TesseraAlphaMask, center: CGPoint, radius: CGFloat) -> Bool {
    if alphaMask.contains(center) {
      return true
    }

    guard radius > 0 else { return false }

    let diagonal = radius * 0.707_106_781_186_547_6
    let samplePoints = [
      CGPoint(x: center.x + radius, y: center.y),
      CGPoint(x: center.x - radius, y: center.y),
      CGPoint(x: center.x, y: center.y + radius),
      CGPoint(x: center.x, y: center.y - radius),
      CGPoint(x: center.x + diagonal, y: center.y + diagonal),
      CGPoint(x: center.x + diagonal, y: center.y - diagonal),
      CGPoint(x: center.x - diagonal, y: center.y + diagonal),
      CGPoint(x: center.x - diagonal, y: center.y - diagonal),
    ]

    return samplePoints.contains(where: alphaMask.contains)
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
    case let .grid(gridPlacement):
      gridPlacement.seed
    }
  }

  func makeComputationKey(for canvasSize: CGSize) -> ComputationKey {
    let placement = resolvedPlacement
    let patternRotationRadians = RotationMath.normalizedRadians(configuration.patternRotation.radians)
    let symbolKeys: [ComputationKey.SymbolKey] = configuration.symbols.map { symbol in
      let scaleRange = resolvedScaleRange(for: symbol, placement: placement)
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

    let pinnedSymbolKeys: [ComputationKey.PinnedSymbolKey] = pinnedSymbols.map { pinnedSymbol in
      let positionKey = makePinnedSymbolPositionKey(from: pinnedSymbol.position)
      return ComputationKey.PinnedSymbolKey(
        id: pinnedSymbol.id,
        positionKind: positionKey.positionKind,
        absoluteX: positionKey.absoluteX,
        absoluteY: positionKey.absoluteY,
        unitPointX: positionKey.unitPointX,
        unitPointY: positionKey.unitPointY,
        offsetWidth: positionKey.offsetWidth,
        offsetHeight: positionKey.offsetHeight,
        rotationRadians: pinnedSymbol.rotation.radians,
        scale: pinnedSymbol.scale,
        collisionShape: pinnedSymbol.collisionShape,
      )
    }

    return ComputationKey(
      canvasSize: canvasSize,
      edgeBehavior: effectiveEdgeBehavior,
      placement: placement,
      patternOffset: configuration.patternOffset,
      patternRotationRadians: patternRotationRadians,
      patternRotationAnchorX: Double(configuration.patternRotationAnchor.x),
      patternRotationAnchorY: Double(configuration.patternRotationAnchor.y),
      symbolKeys: symbolKeys,
      pinnedSymbolKeys: pinnedSymbolKeys,
      region: region,
    )
  }

  private func makePinnedSymbolPositionKey(from position: TesseraPlacementPosition) -> (
    positionKind: ComputationKey.PinnedSymbolKey.PositionKind,
    absoluteX: Double,
    absoluteY: Double,
    unitPointX: Double,
    unitPointY: Double,
    offsetWidth: Double,
    offsetHeight: Double,
  ) {
    switch position {
    case let .absolute(point):
      (
        positionKind: .absolute,
        absoluteX: Double(point.x),
        absoluteY: Double(point.y),
        unitPointX: 0,
        unitPointY: 0,
        offsetWidth: 0,
        offsetHeight: 0,
      )
    case let .relative(unitPoint, offset):
      (
        positionKind: .relative,
        absoluteX: 0,
        absoluteY: 0,
        unitPointX: Double(unitPoint.x),
        unitPointY: Double(unitPoint.y),
        offsetWidth: Double(offset.width),
        offsetHeight: Double(offset.height),
      )
    }
  }
}
