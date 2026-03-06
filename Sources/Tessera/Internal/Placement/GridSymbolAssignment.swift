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

  static func choiceSeed(
    baseSeed: UInt64,
    rowIndex: Int,
    columnIndex: Int,
    cellIndex: Int,
    symbolID: UUID,
    symbolChoiceSeed: UInt64?,
  ) -> UInt64 {
    let bytes = symbolID.uuid
    let upper = UInt64(bytes.0) << 56 | UInt64(bytes.1) << 48 | UInt64(bytes.2) << 40 | UInt64(bytes.3) << 32 |
      UInt64(bytes.4) << 24 | UInt64(bytes.5) << 16 | UInt64(bytes.6) << 8 | UInt64(bytes.7)
    let lower = UInt64(bytes.8) << 56 | UInt64(bytes.9) << 48 | UInt64(bytes.10) << 40 | UInt64(bytes.11) << 32 |
      UInt64(bytes.12) << 24 | UInt64(bytes.13) << 16 | UInt64(bytes.14) << 8 | UInt64(bytes.15)

    var seed = symbolSeed(
      baseSeed: baseSeed,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      cellIndex: cellIndex,
    ) &* 0xA076_1D64_78BD_642F
    seed ^= upper
    seed ^= lower &* 0xE703_7ED1_A0B4_28DB
    if let symbolChoiceSeed {
      seed ^= symbolChoiceSeed &* 0xD1B5_4A32_D192_ED03
    }
    seed ^= seed >> 31
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
