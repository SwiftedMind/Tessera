// By Dennis Müller

import Foundation

enum GridSymbolAssignment {
  typealias PlacementSymbolDescriptor = ShapePlacementEngine.PlacementSymbolDescriptor

  static func shuffledSymbolIndices(
    symbolCount: Int,
    totalCellCount: Int,
    seed: UInt64,
  ) -> [Int] {
    var indices = Array(repeating: 0, count: totalCellCount)
    for index in 0..<totalCellCount {
      indices[index] = index % symbolCount
    }

    var randomGenerator = SeededGenerator(seed: seed)
    indices.shuffle(using: &randomGenerator)
    return indices
  }

  static func cumulativeWeights(for symbolDescriptors: [PlacementSymbolDescriptor]) -> [Double] {
    var cumulativeWeights: [Double] = []
    cumulativeWeights.reserveCapacity(symbolDescriptors.count)

    var runningTotal = 0.0
    for symbol in symbolDescriptors {
      let normalizedWeight = symbol.weight.isFinite ? max(0, symbol.weight) : 0
      runningTotal += normalizedWeight
      cumulativeWeights.append(runningTotal)
    }

    return cumulativeWeights
  }

  static func symbolSeed(
    baseSeed: UInt64,
    rowIndex: Int,
    columnIndex: Int,
    cellIndex: Int,
  ) -> UInt64 {
    var seed = baseSeed
    seed ^= UInt64(truncatingIfNeeded: rowIndex) &* 0x9E37_79B9_7F4A_7C15
    seed ^= UInt64(truncatingIfNeeded: columnIndex) &* 0xBF58_476D_1CE4_E5B9
    seed ^= UInt64(truncatingIfNeeded: cellIndex) &* 0x94D0_49BB_1331_11EB
    seed ^= seed >> 29
    return seed
  }

  static func randomWeightedSymbolIndex(
    symbolCount: Int,
    cumulativeWeights: [Double],
    totalWeight: Double,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> Int {
    guard symbolCount > 0 else { return 0 }
    guard totalWeight > 0 else {
      return Int.random(in: 0..<symbolCount, using: &randomGenerator)
    }

    let value = Double.random(in: 0..<totalWeight, using: &randomGenerator)
    var lowerBound = 0
    var upperBound = cumulativeWeights.count - 1
    while lowerBound < upperBound {
      let mid = (lowerBound + upperBound) / 2
      if value < cumulativeWeights[mid] {
        upperBound = mid
      } else {
        lowerBound = mid + 1
      }
    }

    return lowerBound
  }
}
