// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Places tessera symbols while respecting their approximate collision shapes.
enum ShapePlacementEngine {
  /// Generates placed symbols for a single tile using rejection sampling with wrap-aware collisions.
  ///
  /// - Parameters:
  ///   - size: The size of the tile to populate with symbols.
  ///   - configuration: The full tessera configuration, including placement mode.
  ///   - pinnedSymbols: Symbols that must be placed at fixed positions before sampling.
  ///   - edgeBehavior: The edge behavior to apply when testing collisions.
  ///   - region: Optional polygon region in tile space used to constrain placement.
  ///   - alphaMask: Optional alpha mask used to constrain placement.
  ///   - randomGenerator: The random number generator that drives placement.
  /// - Returns: The placed symbols for the tile.
  static func placeSymbols(
    in size: CGSize,
    configuration: TesseraConfiguration,
    pinnedSymbols: [TesseraPinnedSymbol] = [],
    edgeBehavior: TesseraEdgeBehavior = .seamlessWrapping,
    region: TesseraResolvedPolygonRegion? = nil,
    alphaMask: (any PlacementMask)? = nil,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedSymbol] {
    guard !configuration.symbols.isEmpty else { return [] }

    let symbolDescriptors = makeSymbolDescriptors(
      from: configuration.symbols,
      placement: configuration.placement,
    )

    let pinnedSymbolDescriptors = pinnedSymbols.map { pinnedSymbol in
      PinnedSymbolDescriptor(
        id: pinnedSymbol.id,
        position: pinnedSymbol.resolvedPosition(in: size),
        rotationRadians: pinnedSymbol.rotation.radians,
        scale: pinnedSymbol.scale,
        collisionShape: pinnedSymbol.collisionShape,
      )
    }

    let placedDescriptors = placeSymbolDescriptors(
      in: size,
      symbolDescriptors: symbolDescriptors,
      pinnedSymbolDescriptors: pinnedSymbolDescriptors,
      edgeBehavior: edgeBehavior,
      placement: configuration.placement,
      region: region,
      alphaMask: alphaMask,
      randomGenerator: &randomGenerator,
    )

    let symbolLookup = configuration.symbols.renderableLeafLookupByID

    return placedDescriptors.compactMap { descriptor in
      guard let symbol = symbolLookup[descriptor.renderSymbolId] else { return nil }

      return PlacedSymbol(
        symbol: symbol,
        position: descriptor.position,
        rotation: .radians(descriptor.rotationRadians),
        scale: descriptor.scale,
      )
    }
  }

  static func makeSymbolDescriptors(
    from symbols: [TesseraSymbol],
    placement: PlacementModel,
  ) -> [PlacementSymbolDescriptor] {
    symbols.enumerated().map { sourceOrder, symbol in
      makeSymbolDescriptor(from: symbol, placement: placement)
        .updatingRenderOrder(zIndex: symbol.zIndex, sourceOrder: sourceOrder)
    }
  }

  /// Generates placed symbol descriptors without capturing SwiftUI view builders.
  ///
  /// This is safe to run on a background task and is used by `TesseraCanvas` caching.
  ///
  /// - Parameters:
  ///   - size: The size of the tile to populate with symbol descriptors.
  ///   - symbolDescriptors: The available symbols with resolved collision metadata.
  ///   - pinnedSymbolDescriptors: Symbols that must be placed at fixed positions before sampling.
  ///   - edgeBehavior: The edge behavior to apply when testing collisions.
  ///   - placement: The placement mode configuration to use.
  ///   - region: Optional polygon region in tile space used to constrain placement.
  ///   - alphaMask: Optional alpha mask used to constrain placement.
  ///   - gridPlacementBounds: Optional canvas-space bounds used to resolve grid cell size and centers.
  ///   - maskConstraintMode: How strictly the alpha mask constrains collision geometry.
  ///   - randomGenerator: The random number generator that drives placement.
  /// - Returns: The placed symbol descriptors for the tile.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor] = [],
    edgeBehavior: TesseraEdgeBehavior = .seamlessWrapping,
    placement: PlacementModel,
    region: TesseraResolvedPolygonRegion? = nil,
    alphaMask: (any PlacementMask)? = nil,
    gridPlacementBounds: CGRect? = nil,
    maskConstraintMode: ShapePlacementMaskConstraint.Mode = .sampledCollisionGeometry,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedSymbolDescriptor] {
    guard !symbolDescriptors.isEmpty else { return [] }

    let placedDescriptors = switch placement {
    case let .organic(organicConfiguration):
      OrganicShapePlacementEngine.placeSymbolDescriptors(
        in: size,
        symbolDescriptors: symbolDescriptors,
        pinnedSymbolDescriptors: pinnedSymbolDescriptors,
        edgeBehavior: edgeBehavior,
        configuration: organicConfiguration,
        region: region,
        alphaMask: alphaMask,
        maskConstraintMode: maskConstraintMode,
        randomGenerator: &randomGenerator,
      )
    case let .grid(gridConfiguration):
      GridShapePlacementEngine.placeSymbolDescriptors(
        in: size,
        symbolDescriptors: symbolDescriptors,
        pinnedSymbolDescriptors: pinnedSymbolDescriptors,
        edgeBehavior: edgeBehavior,
        configuration: gridConfiguration,
        region: region,
        alphaMask: alphaMask,
        placementBounds: gridPlacementBounds,
        maskConstraintMode: maskConstraintMode,
      )
    }

    return ShapePlacementOrdering.normalized(placedDescriptors)
  }

  private static func resolvedScaleRange(
    for symbol: TesseraSymbol,
    placement: PlacementModel,
  ) -> ClosedRange<Double> {
    switch placement {
    case let .organic(organicConfiguration):
      symbol.scaleRange ?? organicConfiguration.baseScaleRange
    case .grid:
      symbol.scaleRange ?? 1...1
    }
  }

  private static func makeSymbolDescriptor(
    from symbol: TesseraSymbol,
    placement: PlacementModel,
  ) -> PlacementSymbolDescriptor {
    let childDescriptors = symbol.choices.map { childSymbol in
      makeSymbolDescriptor(
        from: childSymbol,
        placement: placement,
      )
    }
    let renderDescriptor: PlacementSymbolDescriptor.RenderDescriptor? = childDescriptors.isEmpty
      ? PlacementSymbolDescriptor.RenderDescriptor(
        id: symbol.id,
        allowedRotationRangeDegrees: symbol.allowedRotationRange.lowerBound.degrees...symbol.allowedRotationRange
          .upperBound
          .degrees,
        resolvedScaleRange: resolvedScaleRange(for: symbol, placement: placement),
        collisionShape: symbol.collisionShape,
      )
      : nil

    return PlacementSymbolDescriptor(
      id: symbol.id,
      weight: symbol.weight,
      zIndex: symbol.zIndex,
      sourceOrder: 0,
      choiceStrategy: symbol.choiceStrategy,
      choiceSeed: symbol.choiceSeed,
      renderDescriptor: renderDescriptor,
      choices: childDescriptors,
    )
  }
}

private extension ShapePlacementEngine.PlacementSymbolDescriptor {
  func updatingRenderOrder(zIndex: Double, sourceOrder: Int) -> Self {
    var copy = self
    copy.zIndex = zIndex
    copy.sourceOrder = sourceOrder
    copy.choices = copy.choices.map { childDescriptor in
      childDescriptor.updatingRenderOrder(zIndex: zIndex, sourceOrder: sourceOrder)
    }
    return copy
  }
}
