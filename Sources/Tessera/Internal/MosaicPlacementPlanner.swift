// By Dennis Müller

import CoreGraphics
import Foundation

/// Plans all placement layers (base + mosaics) and assembles a render-ready snapshot.
struct MosaicPlacementPlanner {
  /// Immutable request inputs for one snapshot computation.
  struct Inputs {
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
      maskPreparationDurations: maskPreparation.mosaicMaskPreparationDurations,
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
    return TesseraSnapshot(
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
        mosaics: mosaicPlacements.layers,
        pinnedSymbols: inputs.pinnedSymbols,
        resolvedRegion: resolvedRegion,
        resolvedGlobalAlphaMask: resolvedGlobalAlphaMask,
        performanceDiagnostics: SnapshotPerformanceDiagnostics(
          baseLayer: basePlacement.diagnostics,
          mosaicLayers: mosaicPlacements.diagnostics,
        ),
      ),
    )
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
    struct ExcludedMosaic {
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
    mosaicMaskPreparationDurations: [Double],
    mosaicPlacementMasks: [MosaicPlacementMask],
    baseAllowedMask: (any PlacementMask)?,
  ) {
    let mosaics = inputs.pattern.mosaics
    guard mosaics.isEmpty == false else {
      return (
        mosaicMasks: [],
        mosaicMaskPreparationDurations: [],
        mosaicPlacementMasks: [],
        baseAllowedMask: globalMask,
      )
    }

    onEvent(.preparingMasks(completed: 0, total: mosaics.count))
    let rawMasks = try await buildRawMosaicShapeMasks(
      mosaics: mosaics,
      onEvent: onEvent,
    )
    let mosaicMasks = rawMasks.map(\.mask)
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
      mosaicMaskPreparationDurations: rawMasks.map(\.durationSeconds),
      mosaicPlacementMasks: mosaicPlacementMasks,
      baseAllowedMask: baseAllowedMask,
    )
  }

  /// Builds raw shape masks in parallel before declaration-order overlap resolution.
  @concurrent
  func buildRawMosaicShapeMasks(
    mosaics: [Mosaic],
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> [(mask: MosaicShapeMask, durationSeconds: Double)] {
    var rawMasks = [(mask: MosaicShapeMask, durationSeconds: Double)?](repeating: nil, count: mosaics.count)
    var completed = 0

    try await withThrowingTaskGroup(of: (Int, MosaicShapeMask, Double).self) { group in
      for (index, mosaic) in mosaics.enumerated() {
        group.addTask {
          try Task.checkCancellation()
          let startedAt = Date().timeIntervalSinceReferenceDate
          let mask = MosaicShapeMask(
            mosaicMask: mosaic.mask,
            canvasSize: inputs.resolvedSize,
          )
          return (
            index,
            mask,
            Date().timeIntervalSinceReferenceDate - startedAt,
          )
        }
      }

      for try await (index, rawMask, durationSeconds) in group {
        rawMasks[index] = (mask: rawMask, durationSeconds: durationSeconds)
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
    maskPreparationDurations: [Double],
    edgeBehavior: TesseraEdgeBehavior,
    resolvedRegion: TesseraResolvedPolygonRegion?,
    onEvent: @Sendable (TesseraComputationEvent) -> Void,
  ) async throws -> (
    layers: [SnapshotMosaicLayer],
    diagnostics: [SnapshotPerformanceDiagnostics.Layer],
  ) {
    let mosaics = inputs.pattern.mosaics
    var layers = [SnapshotMosaicLayer?](repeating: nil, count: mosaics.count)
    var diagnosticsByIndex = [SnapshotPerformanceDiagnostics.Layer?](repeating: nil, count: mosaics.count)

    try await withThrowingTaskGroup(of: (Int, SnapshotMosaicLayer, SnapshotPerformanceDiagnostics.Layer)
      .self) { group in
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
            let placementDiagnostics = ShapePlacementCollision.Diagnostics()
            if case .grid = resolved.placement, gridPlacementBounds == nil {
              let snapshotLayer = makeSnapshotMosaicLayer(
                mosaic: mosaic,
                symbols: resolved.symbols,
                placements: [],
                mask: mosaicMasks[index],
              )
              return (
                index,
                snapshotLayer,
                SnapshotPerformanceDiagnostics.Layer(
                  id: mosaic.id,
                  maskPreparationDurationSeconds: maskPreparationDurations[index],
                  placement: placementDiagnostics.summary(),
                ),
              )
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
              diagnostics: placementDiagnostics,
            )

            let snapshotLayer = makeSnapshotMosaicLayer(
              mosaic: mosaic,
              symbols: resolved.symbols,
              placements: placed,
              mask: mosaicMasks[index],
            )
            return (
              index,
              snapshotLayer,
              SnapshotPerformanceDiagnostics.Layer(
                id: mosaic.id,
                maskPreparationDurationSeconds: maskPreparationDurations[index],
                placement: placementDiagnostics.summary(),
              ),
            )
          }
        }

        var completed = 0
        for try await (index, layer, diagnostics) in group {
          try Task.checkCancellation()
          layers[index] = layer
          diagnosticsByIndex[index] = diagnostics
          completed += 1
          onEvent(.placingMosaics(completed: completed, total: mosaics.count))
        }
      }

    return (
      layers: layers.compactMap(\.self),
      diagnostics: diagnosticsByIndex.compactMap(\.self),
    )
  }

  /// Creates a snapshot mosaic layer from resolved symbols and placed descriptors.
  func makeSnapshotMosaicLayer(
    mosaic: Mosaic,
    symbols: [Symbol],
    placements: [ShapePlacementEngine.PlacedSymbolDescriptor],
    mask: MosaicShapeMask,
  ) -> SnapshotMosaicLayer {
    let metadataBySymbolID = symbols.renderOrderMetadataBySymbolID
    let snapshotPlacements: [SnapshotPlacementDescriptor] = placements.map {
      let metadata = metadataBySymbolID[$0.symbolId]
      return SnapshotPlacementDescriptor(
        symbolId: $0.symbolId,
        renderSymbolId: $0.renderSymbolId,
        zIndex: metadata?.zIndex ?? 0,
        sourceOrder: metadata?.sourceOrder ?? Int.max,
        position: $0.position,
        rotationRadians: $0.rotationRadians,
        scale: $0.scale,
        clipRect: $0.clipRect,
      )
    }
    let normalizedPlacements = ShapePlacementOrdering.normalized(
      snapshotPlacements,
      metadataBySymbolID: metadataBySymbolID,
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
  ) -> (
    symbols: [Symbol],
    placements: [SnapshotPlacementDescriptor],
    diagnostics: SnapshotPerformanceDiagnostics.Layer,
  ) {
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

    let placementDiagnostics = ShapePlacementCollision.Diagnostics()
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
      diagnostics: placementDiagnostics,
    )

    let metadataBySymbolID = resolved.symbols.renderOrderMetadataBySymbolID
    let snapshotPlacements: [SnapshotPlacementDescriptor] = placed.map {
      let metadata = metadataBySymbolID[$0.symbolId]
      return SnapshotPlacementDescriptor(
        symbolId: $0.symbolId,
        renderSymbolId: $0.renderSymbolId,
        zIndex: metadata?.zIndex ?? 0,
        sourceOrder: metadata?.sourceOrder ?? Int.max,
        position: $0.position,
        rotationRadians: $0.rotationRadians,
        scale: $0.scale,
        clipRect: $0.clipRect,
      )
    }
    let normalizedPlacements = ShapePlacementOrdering.normalized(
      snapshotPlacements,
      metadataBySymbolID: metadataBySymbolID,
    )

    return (
      symbols: resolved.symbols,
      placements: normalizedPlacements,
      diagnostics: SnapshotPerformanceDiagnostics.Layer(
        id: nil,
        maskPreparationDurationSeconds: nil,
        placement: placementDiagnostics.summary(),
      ),
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

private extension MosaicPlacementPlanner.MosaicPlacementMask {
  func shapePlacementMaskValidationResult(
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: ShapePlacementMaskConstraint.Mode,
    centerAlreadyValidated: Bool,
    boundingRadius: CGFloat,
  ) -> ShapePlacementMaskConstraint.ValidationResult {
    let shapeValidation = shapeMask.shapePlacementMaskValidationResult(
      collisionTransform: collisionTransform,
      polygons: polygons,
      mode: mode,
      centerAlreadyValidated: centerAlreadyValidated,
      boundingRadius: boundingRadius,
    )
    guard shapeValidation == .accepted else { return shapeValidation }
    guard let globalMask else { return .accepted }

    return ShapePlacementMaskConstraint.validationResult(
      globalMask,
      collisionTransform: collisionTransform,
      polygons: polygons,
      mode: mode,
      centerAlreadyValidated: centerAlreadyValidated,
      boundingRadius: boundingRadius,
    )
  }
}

extension MosaicPlacementPlanner.MosaicPlacementMask: ShapePlacementMaskOptimizing {}

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
      hasher.combine(key.zIndex)
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
      combine(organicFillStrategy: organic.fillStrategy, into: &hasher)
      hasher.combine(organic.showsCollisionOverlay)
    case let .grid(grid):
      hasher.combine(1)
      combine(gridSizing: grid.sizing, into: &hasher)
      combine(gridOffsetStrategy: grid.offsetStrategy, into: &hasher)
      combine(gridSymbolOrder: grid.symbolOrder, into: &hasher)
      hasher.combine(grid.seed)
      hasher.combineSequence(grid.symbolPhases.keys.sorted(by: { $0.uuidString < $1.uuidString })) { hasher, symbolID in
        hasher.combine(symbolID)
        if let phase = grid.symbolPhases[symbolID] {
          hasher.combine(phase.x)
          hasher.combine(phase.y)
        }
      }
      combine(gridSteering: grid.steering, into: &hasher)
      hasher.combine(grid.showsGridOverlay)
      hasher.combineSequence(grid.subgrids) { hasher, subgrid in
        hasher.combine(subgrid.origin.row)
        hasher.combine(subgrid.origin.column)
        hasher.combine(subgrid.span.rows)
        hasher.combine(subgrid.span.columns)
        hasher.combine(subgrid.clipsToBounds)
        hasher.combineSequence(subgrid.resolvedSymbolIDs) { hasher, symbolID in
          hasher.combine(symbolID)
        }
        if let localGrid = subgrid.grid {
          hasher.combine(1)
          combine(gridSizing: localGrid.sizing, into: &hasher)
          combine(gridOffsetStrategy: localGrid.offsetStrategy, into: &hasher)
          combine(gridSymbolOrder: localGrid.symbolOrder, into: &hasher)
          if let seed = localGrid.seed {
            hasher.combine(1)
            hasher.combine(seed)
          } else {
            hasher.combine(0)
          }
        } else {
          hasher.combine(0)
          combine(gridSymbolOrder: subgrid.symbolOrder, into: &hasher)
          if let seed = subgrid.seed {
            hasher.combine(1)
            hasher.combine(seed)
          } else {
            hasher.combine(0)
          }
        }
      }
    }
  }

  private static func combine(
    organicFillStrategy: PlacementModel.OrganicFillStrategy,
    into hasher: inout DeterministicHasher,
  ) {
    switch organicFillStrategy {
    case .rejection:
      hasher.combine(0)
    case .dense:
      hasher.combine(1)
    }
  }

  private static func combine(gridSizing: PlacementModel.Grid.Sizing, into hasher: inout DeterministicHasher) {
    switch gridSizing {
    case let .count(columns, rows):
      hasher.combine(0)
      hasher.combine(columns)
      hasher.combine(rows)
    case let .fixed(cellSize, origin):
      hasher.combine(1)
      hasher.combine(cellSize)
      hasher.combine(origin)
    }
  }

  private static func combine(
    gridOffsetStrategy: PlacementModel.GridOffsetStrategy,
    into hasher: inout DeterministicHasher,
  ) {
    switch gridOffsetStrategy {
    case .none:
      hasher.combine(0)
    case let .rowShift(fraction):
      hasher.combine(1)
      hasher.combine(fraction)
    case let .columnShift(fraction):
      hasher.combine(2)
      hasher.combine(fraction)
    case let .checkerShift(fraction):
      hasher.combine(3)
      hasher.combine(fraction)
    }
  }

  private static func combine(
    gridSymbolOrder: PlacementModel.GridSymbolOrder,
    into hasher: inout DeterministicHasher,
  ) {
    switch gridSymbolOrder {
    case .rowMajor:
      hasher.combine(0)
    case .columnMajor:
      hasher.combine(1)
    case .randomWeightedPerCell:
      hasher.combine(2)
    case .shuffle:
      hasher.combine(3)
    case .diagonal:
      hasher.combine(4)
    case .snake:
      hasher.combine(5)
    }
  }

  private static func combine(
    gridSteering: PlacementModel.GridSteering,
    into hasher: inout DeterministicHasher,
  ) {
    combine(steeringField: gridSteering.scaleMultiplier, into: &hasher)
    combine(steeringField: gridSteering.rotationMultiplier, into: &hasher)
    combine(steeringField: gridSteering.rotationOffsetDegrees, into: &hasher)
  }

  private static func combine(
    steeringField: PlacementModel.SteeringField?,
    into hasher: inout DeterministicHasher,
  ) {
    guard let steeringField else {
      hasher.combine(0)
      return
    }

    hasher.combine(1)
    hasher.combine(steeringField.values.lowerBound)
    hasher.combine(steeringField.values.upperBound)
    switch steeringField.shape {
    case let .linear(from, to):
      hasher.combine(0)
      hasher.combine(from.x)
      hasher.combine(from.y)
      hasher.combine(to.x)
      hasher.combine(to.y)
    case let .radial(center, radius):
      hasher.combine(1)
      hasher.combine(center.x)
      hasher.combine(center.y)
      switch radius {
      case .autoFarthestCorner:
        hasher.combine(0)
      case let .shortestSideFraction(fraction):
        hasher.combine(1)
        hasher.combine(fraction)
      }
    }
    switch steeringField.easing {
    case .linear:
      hasher.combine(0)
    case .smoothStep:
      hasher.combine(1)
    case .easeIn:
      hasher.combine(2)
    case .easeOut:
      hasher.combine(3)
    case .easeInOut:
      hasher.combine(4)
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
