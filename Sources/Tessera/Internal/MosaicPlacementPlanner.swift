// By Dennis Müller

import CoreGraphics
import Foundation

/// Plans all placement layers (base + mosaics) and assembles a render-ready snapshot.
struct MosaicPlacementPlanner: Sendable {
  /// Immutable request inputs for one snapshot computation.
  struct Inputs: Sendable {
    var pattern: Pattern
    var mode: Mode
    var resolvedSize: CGSize
    var resolvedSeed: UInt64
    var region: Region
    var regionRendering: RegionRendering
    var pinnedSymbols: [PinnedSymbol]
  }

  var inputs: Inputs

  /// Computes one deterministic snapshot from the provided planner inputs.
  func makeSnapshot(
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> TesseraSnapshot {
    let edgeBehavior = resolvedEdgeBehavior(mode: inputs.mode, region: inputs.region)
    let resolvedRegion = inputs.region.resolvedPolygon(in: inputs.resolvedSize)
    let resolvedGlobalAlphaMask = await MainActor.run {
      inputs.region.resolvedAlphaMask(in: inputs.resolvedSize)
    }

    onEvent(.preparingMasks(completed: 0, total: inputs.pattern.mosaics.count))
    let rawMosaicMasks = try await rasterizeRawMosaicMasks(
      mosaics: inputs.pattern.mosaics,
      onEvent: onEvent,
    )

    let effectiveMosaicMasks = inputs.pattern.mosaics.enumerated().map { index, _ in
      let previous = Array(rawMosaicMasks.prefix(index))
      return MaskRasterizer.subtractingUnion(
        mask: rawMosaicMasks[index],
        previousMasks: previous,
        globalMask: resolvedGlobalAlphaMask,
      )
    }

    let exclusionUnionMask = MaskRasterizer.unionMask(
      masks: effectiveMosaicMasks,
      canvasSize: inputs.resolvedSize,
      pixelScale: max(
        inputs.pattern.mosaics.map(\.mask.pixelScale).max() ?? 1,
        resolvedGlobalAlphaMask?.pixelScale ?? 1,
      ),
    )
    let baseAllowedMask = makeBaseAllowedMask(
      globalMask: resolvedGlobalAlphaMask,
      excludedMask: exclusionUnionMask,
      canvasSize: inputs.resolvedSize,
      pixelScale: max(
        inputs.pattern.mosaics.map(\.mask.pixelScale).max() ?? 1,
        resolvedGlobalAlphaMask?.pixelScale ?? 1,
      ),
    )

    onEvent(.placingMosaics(completed: 0, total: inputs.pattern.mosaics.count))
    let mosaicPlacements = try await placeMosaicLayers(
      effectiveMasks: effectiveMosaicMasks,
      edgeBehavior: edgeBehavior,
      resolvedRegion: resolvedRegion,
      onEvent: onEvent,
    )

    onEvent(.placingBaseSymbols)
    let basePlacement = placeBaseLayer(
      edgeBehavior: edgeBehavior,
      resolvedRegion: resolvedRegion,
      baseAllowedMask: baseAllowedMask,
    )

    let requestKey = makeRequestKey()
    let fingerprint = TesseraFingerprint(
      rawValue: TesseraFingerprintBuilder.fingerprint(
        pattern: inputs.pattern,
        requestKey: requestKey,
      ),
    )
    let snapshot = TesseraSnapshot(
      mode: inputs.mode,
      size: inputs.resolvedSize,
      fingerprint: fingerprint,
      requestKey: requestKey,
      renderModel: SnapshotRenderModel(
        edgeBehavior: edgeBehavior,
        region: inputs.region,
        regionRendering: inputs.regionRendering,
        baseSymbols: basePlacement.symbols,
        basePlacements: basePlacement.placements,
        baseOffset: inputs.pattern.offset,
        mosaics: mosaicPlacements,
        pinnedSymbols: inputs.pinnedSymbols,
        resolvedRegion: resolvedRegion,
        resolvedGlobalAlphaMask: resolvedGlobalAlphaMask,
      ),
    )
    return snapshot
  }
}

private extension MosaicPlacementPlanner {
  /// Rasterizes declaration-order mosaic masks before overlap resolution.
  func rasterizeRawMosaicMasks(
    mosaics: [Mosaic],
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> [TesseraAlphaMask] {
    var masks: [TesseraAlphaMask] = []
    masks.reserveCapacity(mosaics.count)
    for (index, mosaic) in mosaics.enumerated() {
      let rawMask = try await MainActor.run {
        try MaskRasterizer.rasterize(
          mosaicMask: mosaic.mask,
          canvasSize: inputs.resolvedSize,
        )
      }
      masks.append(rawMask)
      onEvent(.preparingMasks(completed: index + 1, total: mosaics.count))
    }
    return masks
  }

  /// Places symbols for each mosaic layer in parallel after effective masks are known.
  func placeMosaicLayers(
    effectiveMasks: [TesseraAlphaMask],
    edgeBehavior: TesseraEdgeBehavior,
    resolvedRegion: TesseraResolvedPolygonRegion?,
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> [SnapshotMosaicLayer] {
    let mosaics = inputs.pattern.mosaics
    var layers = [SnapshotMosaicLayer?](repeating: nil, count: mosaics.count)

    try await withThrowingTaskGroup(of: (Int, SnapshotMosaicLayer).self) { group in
      for (index, mosaic) in mosaics.enumerated() {
        group.addTask {
          try Task.checkCancellation()

          let derivedSeed = derivedMosaicSeed(baseSeed: inputs.resolvedSeed, index: index)
          let seededPlacement = apply(seed: derivedSeed, to: mosaic.placement)
          let resolved = TesseraPlacementResolver.resolve(
            symbols: mosaic.symbols,
            placement: seededPlacement,
          )
          guard resolved.symbols.isEmpty == false else {
            throw RenderError.invalidMosaicConfiguration
          }

          let symbolDescriptors = ShapePlacementEngine.makeSymbolDescriptors(
            from: resolved.symbols,
            placement: resolved.placement,
          )
          let pinnedSymbolDescriptors = makePinnedSymbolDescriptors(
            for: inputs.resolvedSize,
            pinnedSymbols: inputs.pinnedSymbols,
            region: resolvedRegion,
            alphaMask: effectiveMasks[index],
          )
          var generator = SeededGenerator(seed: seed(for: resolved.placement))
          let placed = ShapePlacementEngine.placeSymbolDescriptors(
            in: inputs.resolvedSize,
            symbolDescriptors: symbolDescriptors,
            pinnedSymbolDescriptors: pinnedSymbolDescriptors,
            edgeBehavior: edgeBehavior,
            placement: resolved.placement,
            region: resolvedRegion,
            alphaMask: effectiveMasks[index],
            randomGenerator: &generator,
          )

          let snapshotLayer = SnapshotMosaicLayer(
            id: mosaic.id,
            symbols: resolved.symbols,
            placements: placed.map {
              SnapshotPlacementDescriptor(
                symbolId: $0.symbolId,
                renderSymbolId: $0.renderSymbolId,
                position: $0.position,
                rotationRadians: $0.rotationRadians,
                scale: $0.scale,
              )
            },
            mask: effectiveMasks[index],
            rendering: mosaic.rendering,
            offset: mosaic.offset,
          )
          return (index, snapshotLayer)
        }
      }

      var completed = 0
      for try await (index, layer) in group {
        layers[index] = layer
        completed += 1
        onEvent(.placingMosaics(completed: completed, total: mosaics.count))
      }
    }

    return layers.compactMap(\.self)
  }

  /// Places base-layer symbols in the global allowed area outside mosaic masks.
  func placeBaseLayer(
    edgeBehavior: TesseraEdgeBehavior,
    resolvedRegion: TesseraResolvedPolygonRegion?,
    baseAllowedMask: TesseraAlphaMask?,
  ) -> (symbols: [Symbol], placements: [SnapshotPlacementDescriptor]) {
    let seededPlacement = apply(seed: inputs.resolvedSeed, to: inputs.pattern.placement)
    let resolved = TesseraPlacementResolver.resolve(
      symbols: inputs.pattern.symbols,
      placement: seededPlacement,
    )
    let symbolDescriptors = ShapePlacementEngine.makeSymbolDescriptors(
      from: resolved.symbols,
      placement: resolved.placement,
    )
    let pinnedSymbolDescriptors = makePinnedSymbolDescriptors(
      for: inputs.resolvedSize,
      pinnedSymbols: inputs.pinnedSymbols,
      region: resolvedRegion,
      alphaMask: baseAllowedMask,
    )

    var generator = SeededGenerator(seed: seed(for: resolved.placement))
    let placed = ShapePlacementEngine.placeSymbolDescriptors(
      in: inputs.resolvedSize,
      symbolDescriptors: symbolDescriptors,
      pinnedSymbolDescriptors: pinnedSymbolDescriptors,
      edgeBehavior: edgeBehavior,
      placement: resolved.placement,
      region: resolvedRegion,
      alphaMask: baseAllowedMask,
      randomGenerator: &generator,
    )

    return (
      symbols: resolved.symbols,
      placements: placed.map {
        SnapshotPlacementDescriptor(
          symbolId: $0.symbolId,
          renderSymbolId: $0.renderSymbolId,
          position: $0.position,
          rotationRadians: $0.rotationRadians,
          scale: $0.scale,
        )
      },
    )
  }

  /// Builds the base-layer allowed-area mask by removing all mosaic coverage.
  func makeBaseAllowedMask(
    globalMask: TesseraAlphaMask?,
    excludedMask: TesseraAlphaMask?,
    canvasSize: CGSize,
    pixelScale: CGFloat,
  ) -> TesseraAlphaMask? {
    guard globalMask != nil || excludedMask != nil else { return nil }

    let clampedScale = max(pixelScale, 0.1)
    let width = max(Int((canvasSize.width * clampedScale).rounded(.up)), 1)
    let height = max(Int((canvasSize.height * clampedScale).rounded(.up)), 1)
    var bytes = [UInt8](repeating: 0, count: width * height)

    for y in 0..<height {
      for x in 0..<width {
        let point = CGPoint(
          x: (CGFloat(x) + 0.5) / CGFloat(width) * canvasSize.width,
          y: (CGFloat(y) + 0.5) / CGFloat(height) * canvasSize.height,
        )
        let inGlobal = globalMask?.contains(point) ?? true
        let inExcluded = excludedMask?.contains(point) ?? false
        let isAllowed = inGlobal && inExcluded == false
        bytes[y * width + x] = isAllowed ? 255 : 0
      }
    }

    return TesseraAlphaMask(
      size: canvasSize,
      pixelsWide: width,
      pixelsHigh: height,
      alphaBytes: bytes,
      thresholdByte: 128,
      sampling: .nearest,
      invert: false,
    )
  }

  /// Builds fingerprint input data for the current computation request.
  func makeRequestKey() -> SnapshotRequestKey {
    SnapshotRequestKey.make(
      mode: inputs.mode,
      resolvedSeed: inputs.resolvedSeed,
      region: inputs.region,
      regionRendering: inputs.regionRendering,
      pinnedSymbols: inputs.pinnedSymbols,
    )
  }

  /// Converts pinned symbols into placement-engine descriptors with region/mask filtering.
  func makePinnedSymbolDescriptors(
    for canvasSize: CGSize,
    pinnedSymbols: [PinnedSymbol],
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

      if let alphaMask {
        let collisionTransform = CollisionTransform(
          position: position,
          rotation: CGFloat(pinnedSymbol.rotation.radians),
          scale: pinnedSymbol.scale,
        )
        let polygons = CollisionMath.polygons(for: pinnedSymbol.collisionShape)
        if ShapePlacementMaskConstraint.isPlacementInsideMask(
          alphaMask,
          collisionTransform: collisionTransform,
          polygons: polygons,
        ) == false {
          return nil
        }
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

  /// Resolves the effective edge behavior for the request mode and region.
  func resolvedEdgeBehavior(mode: Mode, region: Region) -> TesseraEdgeBehavior {
    let edgeBehavior: TesseraEdgeBehavior = switch mode {
    case let .canvas(_, edgeBehavior):
      edgeBehavior
    case .tile, .tiled:
      .seamlessWrapping
    }

    switch region {
    case .rectangle:
      return edgeBehavior
    case .polygon, .alphaMask:
      return .finite
    }
  }

  /// Applies a deterministic seed to public placement options.
  func apply(seed: UInt64, to placement: TesseraPlacement) -> TesseraPlacement {
    switch placement {
    case var .organic(options):
      options.seed = seed
      return .organic(options)
    case var .grid(options):
      options.seed = seed
      return .grid(options)
    }
  }

  /// Reads the deterministic seed from an engine placement model.
  func seed(for placement: PlacementModel) -> UInt64 {
    switch placement {
    case let .organic(organicPlacement):
      organicPlacement.seed
    case let .grid(gridPlacement):
      gridPlacement.seed
    }
  }

  /// Derives per-mosaic seeds from the root request seed.
  func derivedMosaicSeed(baseSeed: UInt64, index: Int) -> UInt64 {
    var seed = baseSeed ^ 0xD6E8_FEB8_6659_FD93
    seed ^= UInt64(truncatingIfNeeded: index) &* 0xA076_1D64_78BD_642F
    seed ^= seed >> 29
    return seed
  }
}

/// Builds deterministic fingerprints for strict snapshot compatibility checks.
enum TesseraFingerprintBuilder {
  static func fingerprint(
    pattern: Pattern,
    requestKey: SnapshotRequestKey,
  ) -> UInt64 {
    var hasher = DeterministicHasher()
    combine(pattern: pattern, into: &hasher)
    combine(requestKey: requestKey, into: &hasher)
    return hasher.finalize()
  }

  private static func combine(pattern: Pattern, into hasher: inout DeterministicHasher) {
    hasher.combine(pattern.offset)
    hasher.combineSequence(pattern.symbols) { hasher, symbol in
      combine(symbol: symbol, into: &hasher)
    }
    combine(placement: pattern.placement, into: &hasher)
    hasher.combineSequence(pattern.mosaics) { hasher, mosaic in
      combine(mosaic: mosaic, into: &hasher)
    }
  }

  private static func combine(requestKey: SnapshotRequestKey, into hasher: inout DeterministicHasher) {
    combine(mode: requestKey.mode, into: &hasher)
    hasher.combine(requestKey.resolvedSeed)
    combine(region: requestKey.region, into: &hasher)
    hasher.combine(requestKey.regionRendering == .clipped)
    hasher.combineSequence(requestKey.pinnedSymbolKeys) { hasher, key in
      hasher.combine(key.id)
      hasher.combine(key.positionKind == .absolute)
      hasher.combine(key.absoluteX)
      hasher.combine(key.absoluteY)
      hasher.combine(key.unitPointX)
      hasher.combine(key.unitPointY)
      hasher.combine(key.offsetWidth)
      hasher.combine(key.offsetHeight)
      hasher.combine(key.rotationRadians)
      hasher.combine(key.scale)
      combine(collisionShape: key.collisionShape, into: &hasher)
    }
  }

  private static func combine(mosaic: Mosaic, into hasher: inout DeterministicHasher) {
    hasher.combine(mosaic.id)
    hasher.combine(mosaic.offset)
    hasher.combine(mosaic.rendering == .clipped)
    combine(mask: mosaic.mask, into: &hasher)
    hasher.combineSequence(mosaic.symbols) { hasher, symbol in
      combine(symbol: symbol, into: &hasher)
    }
    combine(placement: mosaic.placement, into: &hasher)
  }

  private static func combine(mask: MosaicMask, into hasher: inout DeterministicHasher) {
    hasher.combine(mask.id)
    combine(symbol: mask.symbol, into: &hasher)
    switch mask.position {
    case let .absolute(point):
      hasher.combine(0)
      hasher.combine(point)
    case let .relative(unitPoint, offset):
      hasher.combine(1)
      hasher.combine(unitPoint)
      hasher.combine(offset)
    }
    hasher.combine(mask.rotation.radians)
    hasher.combine(mask.scale)
    hasher.combine(mask.alphaThreshold)
    hasher.combine(mask.pixelScale)
    hasher.combine(mask.sampling == .nearest)
  }

  private static func combine(symbol: Symbol, into hasher: inout DeterministicHasher) {
    hasher.combine(symbol.id)
    hasher.combine(symbol.weight)
    hasher.combine(symbol.allowedRotationRange.lowerBound.radians)
    hasher.combine(symbol.allowedRotationRange.upperBound.radians)
    if let scaleRange = symbol.scaleRange {
      hasher.combine(1)
      hasher.combine(scaleRange.lowerBound)
      hasher.combine(scaleRange.upperBound)
    } else {
      hasher.combine(0)
    }
    combine(collisionShape: symbol.collisionShape, into: &hasher)
    combine(choiceStrategy: symbol.choiceStrategy, into: &hasher)
    if let choiceSeed = symbol.choiceSeed {
      hasher.combine(1)
      hasher.combine(choiceSeed)
    } else {
      hasher.combine(0)
    }
    hasher.combineSequence(symbol.choices) { hasher, child in
      combine(symbol: child, into: &hasher)
    }
  }

  private static func combine(choiceStrategy: TesseraSymbolChoiceStrategy, into hasher: inout DeterministicHasher) {
    switch choiceStrategy {
    case .weightedRandom:
      hasher.combine(0)
    case .sequence:
      hasher.combine(1)
    case let .indexSequence(indices):
      hasher.combine(2)
      hasher.combineSequence(indices) { hasher, index in
        hasher.combine(index)
      }
    }
  }

  private static func combine(mode: Mode, into hasher: inout DeterministicHasher) {
    switch mode {
    case let .tile(size):
      hasher.combine(0)
      hasher.combine(size)
    case let .tiled(tileSize):
      hasher.combine(1)
      hasher.combine(tileSize)
    case let .canvas(size, edgeBehavior):
      hasher.combine(2)
      if let size {
        hasher.combine(1)
        hasher.combine(size)
      } else {
        hasher.combine(0)
      }
      hasher.combine(edgeBehavior == .finite)
    }
  }

  private static func combine(placement: TesseraPlacement, into hasher: inout DeterministicHasher) {
    switch placement {
    case let .organic(organic):
      hasher.combine(0)
      hasher.combine(organic.seed)
      hasher.combine(organic.minimumSpacing)
      hasher.combine(organic.density)
      hasher.combine(organic.baseScaleRange.lowerBound)
      hasher.combine(organic.baseScaleRange.upperBound)
      hasher.combine(organic.maximumSymbolCount)
      hasher.combine(organic.showsCollisionOverlay)
    case let .grid(grid):
      hasher.combine(1)
      hasher.combine(grid.columnCount)
      hasher.combine(grid.rowCount)
      hasher.combine(grid.seed)
      hasher.combine(grid.showsGridOverlay)
    }
  }

  private static func combine(region: Region, into hasher: inout DeterministicHasher) {
    switch region {
    case .rectangle:
      hasher.combine(0)
    case let .polygon(points, mapping, padding):
      hasher.combine(1)
      hasher.combineSequence(points) { hasher, point in
        hasher.combine(point)
      }
      combine(mapping: mapping, into: &hasher)
      hasher.combine(padding)
    case let .alphaMask(mask):
      hasher.combine(2)
      hasher.combine(mask.cacheKey.deterministicFingerprintComponent)
      combine(mapping: mask.mapping, into: &hasher)
      hasher.combine(mask.padding)
      hasher.combine(mask.pixelScale)
      hasher.combine(mask.alphaThreshold)
      hasher.combine(mask.sampling == .nearest)
      hasher.combine(mask.invert)
    }
  }

  private static func combine(mapping: TesseraPolygonMapping, into hasher: inout DeterministicHasher) {
    switch mapping {
    case .canvasCoordinates:
      hasher.combine(0)
    case let .fit(mode, alignment):
      hasher.combine(1)
      switch mode {
      case .aspectFit:
        hasher.combine(0)
      case .aspectFill:
        hasher.combine(1)
      case .stretch:
        hasher.combine(2)
      }
      hasher.combine(alignment)
    }
  }

  private static func combine(collisionShape: CollisionShape, into hasher: inout DeterministicHasher) {
    switch collisionShape {
    case let .circle(center, radius):
      hasher.combine(0)
      hasher.combine(center)
      hasher.combine(radius)
    case let .rectangle(center, size):
      hasher.combine(1)
      hasher.combine(center)
      hasher.combine(size)
    case let .polygon(points):
      hasher.combine(2)
      hasher.combineSequence(points) { hasher, point in
        hasher.combine(point)
      }
    case let .polygons(pointSets):
      hasher.combine(3)
      hasher.combineSequence(pointSets) { hasher, pointSet in
        hasher.combineSequence(pointSet) { hasher, point in
          hasher.combine(point)
        }
      }
    case let .anchoredPolygon(points, anchor, size):
      hasher.combine(4)
      hasher.combine(anchor)
      hasher.combine(size)
      hasher.combineSequence(points) { hasher, point in
        hasher.combine(point)
      }
    case let .anchoredPolygons(pointSets, anchor, size):
      hasher.combine(5)
      hasher.combine(anchor)
      hasher.combine(size)
      hasher.combineSequence(pointSets) { hasher, pointSet in
        hasher.combineSequence(pointSet) { hasher, point in
          hasher.combine(point)
        }
      }
    case let .centeredPolygon(points):
      hasher.combine(6)
      hasher.combineSequence(points) { hasher, point in
        hasher.combine(point)
      }
    case let .centeredPolygons(pointSets):
      hasher.combine(7)
      hasher.combineSequence(pointSets) { hasher, pointSet in
        hasher.combineSequence(pointSet) { hasher, point in
          hasher.combine(point)
        }
      }
    }
  }
}
