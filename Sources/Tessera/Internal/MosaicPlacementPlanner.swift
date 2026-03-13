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
    let resolvedGlobalAlphaMask: TesseraAlphaMask? = if inputs.region.isAlphaMask {
      await MainActor.run {
        inputs.region.resolvedAlphaMask(in: inputs.resolvedSize)
      }
    } else {
      nil
    }

    let maskPreparation = try await prepareMosaicAndBaseMasks(
      globalMask: resolvedGlobalAlphaMask,
      onEvent: onEvent,
    )

    onEvent(.placingMosaics(completed: 0, total: inputs.pattern.mosaics.count))
    let mosaicPlacements = try await placeMosaicLayers(
      placementMasks: maskPreparation.mosaicPlacementMasks,
      mosaicMasks: maskPreparation.mosaicMasks,
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

extension MosaicPlacementPlanner {
  /// Internal test hook for regression coverage of occupancy estimation.
  static func testingEstimatedFilledFraction(
    in canvasSize: CGSize,
    bounds: CGRect,
    sampleGridSide: Int,
    contains: (CGPoint) -> Bool,
  ) -> Double {
    estimatedFilledFraction(
      in: canvasSize,
      bounds: bounds,
      sampleGridSide: sampleGridSide,
      contains: contains,
    )
  }
}

private extension MosaicPlacementPlanner {
  /// Placement mask for one mosaic, optionally intersected with a global alpha mask region.
  struct MosaicPlacementMask: PlacementMask {
    var shapeMask: MosaicShapeMask
    var globalMask: TesseraAlphaMask?
    var cachedFilledFraction: Double
    var cachedFilledBounds: CGRect?

    init(shapeMask: MosaicShapeMask, globalMask: TesseraAlphaMask?) {
      self.shapeMask = shapeMask
      self.globalMask = globalMask

      let shapeBounds = shapeMask.filledBounds()
      if let globalMask {
        let globalBounds = globalMask.filledBounds()
        let intersection = shapeBounds.flatMap { shapeBounds in
          globalBounds?.intersection(shapeBounds)
        }
        if let intersection, intersection.isNull == false, intersection.isEmpty == false {
          cachedFilledBounds = intersection
          cachedFilledFraction = MosaicPlacementPlanner.estimatedFilledFraction(
            in: shapeMask.size,
            bounds: intersection,
            sampleGridSide: 56,
          ) { point in
            shapeMask.contains(point) && globalMask.contains(point)
          }
        } else {
          cachedFilledBounds = nil
          cachedFilledFraction = 0
        }
      } else {
        cachedFilledBounds = shapeBounds
        cachedFilledFraction = shapeMask.filledFraction
      }
    }

    func contains(_ point: CGPoint) -> Bool {
      guard shapeMask.contains(point) else { return false }

      if let globalMask {
        return globalMask.contains(point)
      }
      return true
    }

    var filledFraction: Double {
      cachedFilledFraction
    }

    func filledBounds() -> CGRect? {
      cachedFilledBounds
    }
  }

  /// Placement mask for the base layer (global region minus all mosaic areas).
  struct BaseAllowedPlacementMask: PlacementMask {
    struct ExcludedMosaic: Sendable {
      var bounds: CGRect
      var mask: MosaicShapeMask
    }

    var canvasSize: CGSize
    var globalMask: TesseraAlphaMask?
    var excludedMosaics: [ExcludedMosaic]
    var cachedFilledFraction: Double
    var cachedFilledBounds: CGRect?

    init(canvasSize: CGSize, globalMask: TesseraAlphaMask?, mosaicMasks: [MosaicShapeMask]) {
      let localMosaicMasks = mosaicMasks
      let localExcludedMosaics = localMosaicMasks.compactMap { mosaicMask -> ExcludedMosaic? in
        guard let bounds = mosaicMask.filledBounds() else { return nil }

        return ExcludedMosaic(bounds: bounds, mask: mosaicMask)
      }
      let estimatedFraction = MosaicPlacementPlanner.estimatedFilledFraction(
        in: canvasSize,
        bounds: CGRect(origin: .zero, size: canvasSize),
        sampleGridSide: 96,
      ) { point in
        if let globalMask, globalMask.contains(point) == false {
          return false
        }
        for excludedMosaic in localExcludedMosaics {
          guard excludedMosaic.bounds.contains(point) else { continue }

          if excludedMosaic.mask.contains(point) {
            return false
          }
        }
        return true
      }

      self.canvasSize = canvasSize
      self.globalMask = globalMask
      excludedMosaics = localExcludedMosaics
      cachedFilledFraction = estimatedFraction
      if estimatedFraction <= 0 {
        cachedFilledBounds = nil
      } else {
        cachedFilledBounds = globalMask?.filledBounds() ?? CGRect(origin: .zero, size: canvasSize)
      }
    }

    func contains(_ point: CGPoint) -> Bool {
      guard point.x >= 0, point.x <= canvasSize.width, point.y >= 0, point.y <= canvasSize.height else {
        return false
      }

      if let globalMask, globalMask.contains(point) == false {
        return false
      }
      for excludedMosaic in excludedMosaics {
        guard excludedMosaic.bounds.contains(point) else { continue }

        if excludedMosaic.mask.contains(point) {
          return false
        }
      }
      return true
    }

    var filledFraction: Double {
      cachedFilledFraction
    }

    func filledBounds() -> CGRect? {
      cachedFilledBounds
    }
  }

  @concurrent
  func prepareMosaicAndBaseMasks(
    globalMask: TesseraAlphaMask?,
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> (
    mosaicMasks: [MosaicShapeMask],
    mosaicPlacementMasks: [MosaicPlacementMask],
    baseAllowedMask: (any PlacementMask)?,
  ) {
    let mosaics = inputs.pattern.mosaics
    guard mosaics.isEmpty == false else {
      return (
        mosaicMasks: [],
        mosaicPlacementMasks: [],
        baseAllowedMask: globalMask,
      )
    }

    onEvent(.preparingMasks(completed: 0, total: mosaics.count))
    let mosaicMasks = try await buildRawMosaicShapeMasks(
      mosaics: mosaics,
      onEvent: onEvent,
    )
    let mosaicPlacementMasks = mosaicMasks.map { mosaicMask in
      MosaicPlacementMask(
        shapeMask: mosaicMask,
        globalMask: globalMask,
      )
    }
    let baseAllowedMask = BaseAllowedPlacementMask(
      canvasSize: inputs.resolvedSize,
      globalMask: globalMask,
      mosaicMasks: mosaicMasks,
    )
    return (
      mosaicMasks: mosaicMasks,
      mosaicPlacementMasks: mosaicPlacementMasks,
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

  /// Fast, coarse occupancy estimate used for symbol-count heuristics.
  static func estimatedFilledFraction(
    in canvasSize: CGSize,
    bounds: CGRect,
    sampleGridSide: Int,
    contains: (CGPoint) -> Bool,
  ) -> Double {
    guard canvasSize.width > 0, canvasSize.height > 0 else { return 0 }
    guard bounds.isNull == false, bounds.isEmpty == false else { return 0 }

    let clampedBounds = bounds.intersection(CGRect(origin: .zero, size: canvasSize))
    guard clampedBounds.isNull == false, clampedBounds.isEmpty == false else { return 0 }

    let baseSide = max(sampleGridSide, 8)
    let refinedSides = [baseSide, baseSide * 2, baseSide * 4]
    let phaseOffsets: [CGFloat] = [0.5, 0.25, 0.75]
    var fractionInBounds = 0.0

    for (refinementIndex, side) in refinedSides.enumerated() {
      let phases = refinementIndex == 0 ? [phaseOffsets[0]] : phaseOffsets
      for phaseOffset in phases {
        let sampleCount = side * side
        var included = 0
        for row in 0..<side {
          let y = clampedBounds.minY + (CGFloat(row) + phaseOffset) / CGFloat(side) * clampedBounds.height
          for column in 0..<side {
            let x = clampedBounds.minX + (CGFloat(column) + phaseOffset) / CGFloat(side) * clampedBounds.width
            if contains(CGPoint(x: x, y: y)) {
              included += 1
            }
          }
        }
        let sampledFraction = Double(included) / Double(max(sampleCount, 1))
        fractionInBounds = max(fractionInBounds, sampledFraction)
        if fractionInBounds > 0 {
          break
        }
      }
      if fractionInBounds > 0 {
        break
      }
    }

    let boundsCoverage = Double(clampedBounds.width * clampedBounds.height) /
      Double(canvasSize.width * canvasSize.height)
    return max(0, min(1, fractionInBounds * boundsCoverage))
  }

  /// Places symbols for each mosaic layer in parallel after effective masks are known.
  @concurrent
  func placeMosaicLayers(
    placementMasks: [MosaicPlacementMask],
    mosaicMasks: [MosaicShapeMask],
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
          let placementMask = placementMasks[index]
          let gridPlacementBounds = gridPlacementBounds(
            for: resolved.placement,
            alphaMask: placementMask,
          )
          if case .grid = resolved.placement, gridPlacementBounds == nil {
            let snapshotLayer = makeSnapshotMosaicLayer(
              mosaic: mosaic,
              symbols: resolved.symbols,
              placements: [],
              mask: mosaicMasks[index],
            )
            return (index, snapshotLayer)
          }
          let pinnedSymbolDescriptors = makePinnedSymbolDescriptors(
            for: inputs.resolvedSize,
            pinnedSymbols: inputs.pinnedSymbols,
            region: resolvedRegion,
            alphaMask: placementMask,
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
            alphaMask: placementMask,
            gridPlacementBounds: gridPlacementBounds,
            maskConstraintMode: maskConstraintMode,
            randomGenerator: &generator,
          )

          let snapshotLayer = makeSnapshotMosaicLayer(
            mosaic: mosaic,
            symbols: resolved.symbols,
            placements: placed,
            mask: mosaicMasks[index],
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
    mask: MosaicShapeMask,
  ) -> SnapshotMosaicLayer {
    let normalizedPlacements = ShapePlacementOrdering.normalized(
      placements.map {
        SnapshotPlacementDescriptor(
          symbolId: $0.symbolId,
          renderSymbolId: $0.renderSymbolId,
          position: $0.position,
          rotationRadians: $0.rotationRadians,
          scale: $0.scale,
        )
      },
      metadataBySymbolID: symbols.renderOrderMetadataBySymbolID,
    )

    return SnapshotMosaicLayer(
      id: mosaic.id,
      symbols: symbols,
      placements: normalizedPlacements,
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
    baseAllowedMask: (any PlacementMask)?,
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

    let normalizedPlacements = ShapePlacementOrdering.normalized(
      placed.map {
        SnapshotPlacementDescriptor(
          symbolId: $0.symbolId,
          renderSymbolId: $0.renderSymbolId,
          position: $0.position,
          rotationRadians: $0.rotationRadians,
          scale: $0.scale,
        )
      },
      metadataBySymbolID: resolved.symbols.renderOrderMetadataBySymbolID,
    )

    return (
      symbols: resolved.symbols,
      placements: normalizedPlacements,
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
    alphaMask: (any PlacementMask)?,
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
    alphaMask: (any PlacementMask)?,
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
    hasher.combine(symbol.zIndex)
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
