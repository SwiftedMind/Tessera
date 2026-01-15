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
  ///   - randomGenerator: The random number generator that drives placement.
  /// - Returns: The placed symbols for the tile.
  static func placeSymbols(
    in size: CGSize,
    configuration: TesseraConfiguration,
    pinnedSymbols: [TesseraPinnedSymbol] = [],
    edgeBehavior: TesseraEdgeBehavior = .seamlessWrapping,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedSymbol] {
    guard !configuration.symbols.isEmpty else { return [] }

    let symbolDescriptors = configuration.symbols.map { symbol in
      let scaleRange = resolvedScaleRange(for: symbol, placement: configuration.placement)
      return PlacementSymbolDescriptor(
        id: symbol.id,
        weight: symbol.weight,
        allowedRotationRangeDegrees: symbol.allowedRotationRange.lowerBound.degrees...symbol.allowedRotationRange
          .upperBound
          .degrees,
        resolvedScaleRange: scaleRange,
        collisionShape: symbol.collisionShape,
      )
    }

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
      randomGenerator: &randomGenerator,
    )

    let symbolLookup: [UUID: TesseraSymbol] = configuration.symbols.reduce(into: [:]) { cache, symbol in
      cache[symbol.id] = symbol
    }

    return placedDescriptors.compactMap { descriptor in
      guard let symbol = symbolLookup[descriptor.symbolId] else { return nil }

      return PlacedSymbol(
        symbol: symbol,
        position: descriptor.position,
        rotation: .radians(descriptor.rotationRadians),
        scale: descriptor.scale,
      )
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
  ///   - randomGenerator: The random number generator that drives placement.
  /// - Returns: The placed symbol descriptors for the tile.
  static func placeSymbolDescriptors(
    in size: CGSize,
    symbolDescriptors: [PlacementSymbolDescriptor],
    pinnedSymbolDescriptors: [PinnedSymbolDescriptor] = [],
    edgeBehavior: TesseraEdgeBehavior = .seamlessWrapping,
    placement: TesseraPlacement,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [PlacedSymbolDescriptor] {
    guard !symbolDescriptors.isEmpty else { return [] }

    return switch placement {
    case let .organic(organicConfiguration):
      OrganicShapePlacementEngine.placeSymbolDescriptors(
        in: size,
        symbolDescriptors: symbolDescriptors,
        pinnedSymbolDescriptors: pinnedSymbolDescriptors,
        edgeBehavior: edgeBehavior,
        configuration: organicConfiguration,
        randomGenerator: &randomGenerator,
      )
    case let .grid(gridConfiguration):
      GridShapePlacementEngine.placeSymbolDescriptors(
        in: size,
        symbolDescriptors: symbolDescriptors,
        pinnedSymbolDescriptors: pinnedSymbolDescriptors,
        edgeBehavior: edgeBehavior,
        configuration: gridConfiguration,
      )
    }
  }

  private static func resolvedScaleRange(
    for symbol: TesseraSymbol,
    placement: TesseraPlacement,
  ) -> ClosedRange<Double> {
    switch placement {
    case let .organic(organicConfiguration):
      symbol.scaleRange ?? organicConfiguration.baseScaleRange
    case .grid:
      symbol.scaleRange ?? 1...1
    }
  }
}
