// By Dennis Müller

import Foundation

extension ShapePlacementEngine {
  /// Tracks deterministic sequence progress for choice symbols.
  struct ChoiceSequenceState: Sendable {
    var nextChoiceIndexBySymbolID: [UUID: Int] = [:]
  }

  /// Resolves a renderable leaf symbol for a (potentially nested) choice symbol descriptor.
  static func resolveLeafSymbolDescriptor(
    from symbolDescriptor: PlacementSymbolDescriptor,
    randomGenerator: inout some RandomNumberGenerator,
    sequenceState: inout ChoiceSequenceState,
  ) -> PlacementSymbolDescriptor.RenderDescriptor? {
    if symbolDescriptor.choices.isEmpty {
      return symbolDescriptor.renderDescriptor
    }

    let selectedIndex: Int
    switch symbolDescriptor.choiceStrategy {
    case .weightedRandom:
      selectedIndex = randomWeightedChoiceIndex(
        for: symbolDescriptor.choices,
        randomGenerator: &randomGenerator,
      )
    case .sequence:
      let nextIndex = sequenceState.nextChoiceIndexBySymbolID[symbolDescriptor.id, default: 0]
      sequenceState.nextChoiceIndexBySymbolID[symbolDescriptor.id] = nextIndex + 1
      selectedIndex = nextIndex % symbolDescriptor.choices.count
    }

    return resolveLeafSymbolDescriptor(
      from: symbolDescriptor.choices[selectedIndex],
      randomGenerator: &randomGenerator,
      sequenceState: &sequenceState,
    )
  }

  private static func randomWeightedChoiceIndex(
    for choices: [PlacementSymbolDescriptor],
    randomGenerator: inout some RandomNumberGenerator,
  ) -> Int {
    guard choices.isEmpty == false else { return 0 }

    let normalizedWeights: [Double] = choices.map { choice in
      if choice.weight.isFinite {
        max(0, choice.weight)
      } else {
        0
      }
    }
    let totalWeight = normalizedWeights.reduce(0, +)

    guard totalWeight > 0 else {
      return Int.random(in: 0..<choices.count, using: &randomGenerator)
    }

    let randomValue = Double.random(in: 0..<totalWeight, using: &randomGenerator)
    var accumulatedWeight = 0.0

    for (index, weight) in normalizedWeights.enumerated() {
      accumulatedWeight += weight
      if randomValue < accumulatedWeight {
        return index
      }
    }

    return choices.count - 1
  }
}
