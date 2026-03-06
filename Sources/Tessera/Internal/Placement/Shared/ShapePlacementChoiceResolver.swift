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

    let selectedIndex: Int = switch symbolDescriptor.choiceStrategy {
    case .weightedRandom:
      randomWeightedChoiceIndex(
        for: symbolDescriptor.choices,
        randomGenerator: &randomGenerator,
      )
    case .sequence:
      sequenceChoiceIndex(
        for: symbolDescriptor,
        sequenceState: &sequenceState,
      )
    case let .indexSequence(indices):
      indexSequenceChoiceIndex(
        for: symbolDescriptor,
        indices: indices,
        sequenceState: &sequenceState,
      )
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

    var totalWeight = 0.0
    for choice in choices {
      if choice.weight.isFinite {
        totalWeight += max(0, choice.weight)
      }
    }

    guard totalWeight > 0 else {
      return Int.random(in: 0..<choices.count, using: &randomGenerator)
    }

    let randomValue = Double.random(in: 0..<totalWeight, using: &randomGenerator)
    var accumulatedWeight = 0.0

    for (index, choice) in choices.enumerated() {
      if choice.weight.isFinite {
        accumulatedWeight += max(0, choice.weight)
      }
      if randomValue < accumulatedWeight {
        return index
      }
    }

    return choices.count - 1
  }

  private static func sequenceChoiceIndex(
    for symbolDescriptor: PlacementSymbolDescriptor,
    sequenceState: inout ChoiceSequenceState,
  ) -> Int {
    let nextStep = nextChoiceStep(
      for: symbolDescriptor.id,
      sequenceState: &sequenceState,
    )
    return positiveModulo(nextStep, modulus: symbolDescriptor.choices.count)
  }

  private static func indexSequenceChoiceIndex(
    for symbolDescriptor: PlacementSymbolDescriptor,
    indices: [Int],
    sequenceState: inout ChoiceSequenceState,
  ) -> Int {
    let nextStep = nextChoiceStep(
      for: symbolDescriptor.id,
      sequenceState: &sequenceState,
    )

    guard indices.isEmpty == false else {
      return positiveModulo(nextStep, modulus: symbolDescriptor.choices.count)
    }

    let sequenceIndex = positiveModulo(nextStep, modulus: indices.count)
    let rawChildIndex = indices[sequenceIndex]
    return positiveModulo(rawChildIndex, modulus: symbolDescriptor.choices.count)
  }

  private static func nextChoiceStep(
    for symbolID: UUID,
    sequenceState: inout ChoiceSequenceState,
  ) -> Int {
    let nextStep = sequenceState.nextChoiceIndexBySymbolID[symbolID, default: 0]
    sequenceState.nextChoiceIndexBySymbolID[symbolID] = nextStep + 1
    return nextStep
  }

  private static func positiveModulo(_ value: Int, modulus: Int) -> Int {
    guard modulus > 0 else { return 0 }

    let remainder = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
  }
}
