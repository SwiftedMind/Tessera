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
  @concurrent
  func makeSnapshot(
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> TesseraSnapshot {
    let edgeBehavior = resolvedEdgeBehavior(mode: inputs.mode, region: inputs.region)
    let resolvedRegion = inputs.region.resolvedPolygon(in: inputs.resolvedSize)
    let resolvedGlobalAlphaMask = await MainActor.run {
      inputs.region.resolvedAlphaMask(in: inputs.resolvedSize)
    }

    let maskPreparation = try await prepareMosaicAndBaseMasks(
      globalMask: resolvedGlobalAlphaMask,
      onEvent: onEvent,
    )

    onEvent(.placingMosaics(completed: 0, total: inputs.pattern.mosaics.count))
    let mosaicPlacements = try await placeMosaicLayers(
      effectiveMasks: maskPreparation.effectiveMasks,
      edgeBehavior: edgeBehavior,
      resolvedRegion: resolvedRegion,
      onEvent: onEvent,
    )

    onEvent(.placingBaseSymbols)
    let basePlacement = placeBaseLayer(
      edgeBehavior: edgeBehavior,
      resolvedRegion: resolvedRegion,
      baseAllowedMask: maskPreparation.baseAllowedMask,
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
  /// Prepares effective mosaic masks and base-layer allowed area using collision-shape-derived coverage.
  static let mosaicMaskPixelScale: CGFloat = 2

  @concurrent
  func prepareMosaicAndBaseMasks(
    globalMask: TesseraAlphaMask?,
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> (
    effectiveMasks: [TesseraAlphaMask],
    baseAllowedMask: TesseraAlphaMask?,
  ) {
    let mosaics = inputs.pattern.mosaics
    guard mosaics.isEmpty == false else {
      return (
        effectiveMasks: [],
        baseAllowedMask: globalMask,
      )
    }

    onEvent(.preparingMasks(completed: 0, total: mosaics.count))
    let rawShapeMasks = try await buildRawMosaicShapeMasks(
      mosaics: mosaics,
      onEvent: onEvent,
    )
    let rasterGrid = ShapeMaskRasterGrid(
      canvasSize: inputs.resolvedSize,
      pixelScale: resolvedMaskPixelScale(globalMask: globalMask),
    )
    let globalCoverage = globalMask.map { mask in
      rasterGrid.alignedCoverage(for: mask)
    }
    let effectiveMaskRasterization = try buildEffectiveMosaicMasks(
      rawShapeMasks: rawShapeMasks,
      mosaics: mosaics,
      globalCoverage: globalCoverage,
      rasterGrid: rasterGrid,
    )
    let baseAllowedMask = makeBaseAllowedMask(
      globalCoverage: globalCoverage,
      excludedCoverage: effectiveMaskRasterization.exclusionCoverage,
      rasterGrid: rasterGrid,
    )
    return (
      effectiveMasks: effectiveMaskRasterization.effectiveMasks,
      baseAllowedMask: baseAllowedMask,
    )
  }

  /// Builds raw shape masks in parallel before declaration-order overlap resolution.
  @concurrent
  func buildRawMosaicShapeMasks(
    mosaics: [Mosaic],
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> [MosaicShapeMask] {
    var rawMasks = [MosaicShapeMask?](repeating: nil, count: mosaics.count)
    var completed = 0

    try await withThrowingTaskGroup(of: (Int, MosaicShapeMask).self) { group in
      for (index, mosaic) in mosaics.enumerated() {
        group.addTask {
          try Task.checkCancellation()
          return (
            index,
            MosaicShapeMask(
              mosaicMask: mosaic.mask,
              canvasSize: inputs.resolvedSize,
            ),
          )
        }
      }

      for try await (index, rawMask) in group {
        rawMasks[index] = rawMask
        completed += 1
        onEvent(.preparingMasks(completed: completed, total: mosaics.count))
      }
    }

    let resolvedMasks = rawMasks.compactMap(\.self)
    guard resolvedMasks.count == mosaics.count else {
      throw CancellationError()
    }

    return resolvedMasks
  }

  /// Converts raw shape masks into first-wins effective alpha masks and returns exclusion coverage.
  func buildEffectiveMosaicMasks(
    rawShapeMasks: [MosaicShapeMask],
    mosaics: [Mosaic],
    globalCoverage: [UInt8]?,
    rasterGrid: ShapeMaskRasterGrid,
  ) throws -> (effectiveMasks: [TesseraAlphaMask], exclusionCoverage: [UInt8]) {
    var exclusionCoverage = [UInt8](repeating: 0, count: rasterGrid.pixelCount)
    var effectiveMasks: [TesseraAlphaMask] = []
    effectiveMasks.reserveCapacity(mosaics.count)

    for (index, _) in mosaics.enumerated() {
      try Task.checkCancellation()

      let shapeMask = rawShapeMasks[index]
      var alphaBytes = [UInt8](repeating: 0, count: rasterGrid.pixelCount)
      guard let pixelRange = rasterGrid.pixelRange(for: shapeMask.bounds) else {
        effectiveMasks.append(
          rasterGrid.makeMask(alphaBytes: alphaBytes),
        )
        continue
      }

      for pixelY in pixelRange.y {
        if (pixelY - pixelRange.y.lowerBound).isMultiple(of: 8) {
          try Task.checkCancellation()
        }
        for pixelX in pixelRange.x {
          let coverageIndex = pixelY * rasterGrid.pixelsWide + pixelX
          if exclusionCoverage[coverageIndex] != 0 {
            continue
          }
          if let globalCoverage, globalCoverage[coverageIndex] == 0 {
            continue
          }
          let point = rasterGrid.point(pixelX: pixelX, pixelY: pixelY)
          if shapeMask.contains(point) {
            alphaBytes[coverageIndex] = 255
            exclusionCoverage[coverageIndex] = 255
          }
        }
      }

      effectiveMasks.append(
        rasterGrid.makeMask(alphaBytes: alphaBytes),
      )
    }

    return (effectiveMasks: effectiveMasks, exclusionCoverage: exclusionCoverage)
  }

  func resolvedMaskPixelScale(globalMask: TesseraAlphaMask?) -> CGFloat {
    max(
      Self.mosaicMaskPixelScale,
      globalMask?.pixelScale ?? 1,
    )
  }

  /// Builds the base-layer allowed-area mask by removing all mosaic coverage.
  func makeBaseAllowedMask(
    globalCoverage: [UInt8]?,
    excludedCoverage: [UInt8],
    rasterGrid: ShapeMaskRasterGrid,
  ) -> TesseraAlphaMask? {
    guard globalCoverage != nil || excludedCoverage.contains(where: { $0 != 0 }) else { return nil }

    var bytes = [UInt8](repeating: 0, count: rasterGrid.pixelCount)
    for index in bytes.indices {
      let inGlobal = globalCoverage?[index] != 0 || globalCoverage == nil
      let inExcluded = excludedCoverage[index] != 0
      bytes[index] = (inGlobal && inExcluded == false) ? 255 : 0
    }

    return rasterGrid.makeMask(alphaBytes: bytes)
  }

  /// Places symbols for each mosaic layer in parallel after effective masks are known.
  @concurrent
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
          let maskConstraintMode = maskConstraintMode(for: mosaic.rendering)
          let gridPlacementBounds = gridPlacementBounds(
            for: resolved.placement,
            alphaMask: effectiveMasks[index],
          )
          if case .grid = resolved.placement, gridPlacementBounds == nil {
            let snapshotLayer = makeSnapshotMosaicLayer(
              mosaic: mosaic,
              symbols: resolved.symbols,
              placements: [],
              mask: effectiveMasks[index],
            )
            return (index, snapshotLayer)
          }
          let pinnedSymbolDescriptors = makePinnedSymbolDescriptors(
            for: inputs.resolvedSize,
            pinnedSymbols: inputs.pinnedSymbols,
            region: resolvedRegion,
            alphaMask: effectiveMasks[index],
            maskConstraintMode: maskConstraintMode,
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
            gridPlacementBounds: gridPlacementBounds,
            maskConstraintMode: maskConstraintMode,
            randomGenerator: &generator,
          )

          let snapshotLayer = makeSnapshotMosaicLayer(
            mosaic: mosaic,
            symbols: resolved.symbols,
            placements: placed,
            mask: effectiveMasks[index],
          )
          return (index, snapshotLayer)
        }
      }

      var completed = 0
      for try await (index, layer) in group {
        try Task.checkCancellation()
        layers[index] = layer
        completed += 1
        onEvent(.placingMosaics(completed: completed, total: mosaics.count))
      }
    }

    return layers.compactMap(\.self)
  }

  /// Creates a snapshot mosaic layer from resolved symbols and placed descriptors.
  func makeSnapshotMosaicLayer(
    mosaic: Mosaic,
    symbols: [Symbol],
    placements: [ShapePlacementEngine.PlacedSymbolDescriptor],
    mask: TesseraAlphaMask,
  ) -> SnapshotMosaicLayer {
    SnapshotMosaicLayer(
      id: mosaic.id,
      symbols: symbols,
      placements: placements.map {
        SnapshotPlacementDescriptor(
          symbolId: $0.symbolId,
          renderSymbolId: $0.renderSymbolId,
          position: $0.position,
          rotationRadians: $0.rotationRadians,
          scale: $0.scale,
        )
      },
      mask: mask,
      maskDefinition: mosaic.mask,
      rendering: mosaic.rendering,
      offset: mosaic.offset,
    )
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
    maskConstraintMode: ShapePlacementMaskConstraint.Mode = .sampledCollisionGeometry,
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
          mode: maskConstraintMode,
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

  /// Resolves placement mask constraints from the mosaic rendering mode.
  func maskConstraintMode(for rendering: MosaicRendering) -> ShapePlacementMaskConstraint.Mode {
    switch rendering {
    case .contained:
      .sampledCollisionGeometry
    case .clipped:
      .centerPoint
    case .unclipped:
      .centerPoint
    }
  }

  /// Resolves canvas-space bounds for grid placement inside a mosaic mask.
  func gridPlacementBounds(
    for placement: PlacementModel,
    alphaMask: TesseraAlphaMask?,
  ) -> CGRect? {
    guard case .grid = placement else { return nil }

    return alphaMask?.filledBounds()
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
    combine(mosaicRendering: mosaic.rendering, into: &hasher)
    combine(mask: mosaic.mask, into: &hasher)
    hasher.combineSequence(mosaic.symbols) { hasher, symbol in
      combine(symbol: symbol, into: &hasher)
    }
    combine(placement: mosaic.placement, into: &hasher)
  }

  private static func combine(mosaicRendering: MosaicRendering, into hasher: inout DeterministicHasher) {
    switch mosaicRendering {
    case .contained:
      hasher.combine(0)
    case .clipped:
      hasher.combine(1)
    case .unclipped:
      hasher.combine(2)
    }
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
