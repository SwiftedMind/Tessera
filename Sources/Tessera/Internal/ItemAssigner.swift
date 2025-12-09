// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Assigns tessera items to generated points while discouraging identical neighbors.
enum ItemAssigner {
  static func assignItems(
    to points: [CGPoint],
    in size: CGSize,
    items: [TesseraItem],
    exclusionRadius: CGFloat,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [TesseraItem] {
    guard !points.isEmpty else { return [] }

    let cellSize = exclusionRadius / CGFloat(Double(2).squareRoot())
    let columnCount = max(Int(ceil(size.width / cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / cellSize)), 1)
    var grid = Array(repeating: [Int](), count: columnCount * rowCount)

    func wrappedCoordinate(_ value: CGFloat, max: CGFloat) -> CGFloat {
      let modulo = value.truncatingRemainder(dividingBy: max)
      return modulo < 0 ? modulo + max : modulo
    }

    func gridIndex(for point: CGPoint) -> Int {
      let wrappedX = wrappedCoordinate(point.x, max: size.width)
      let wrappedY = wrappedCoordinate(point.y, max: size.height)
      let column = Int(wrappedX / cellSize) % columnCount
      let row = Int(wrappedY / cellSize) % rowCount
      return row * columnCount + column
    }

    var assignments = Array(repeating: items.first!, count: points.count)
    var order = Array(points.indices)
    order.shuffle(using: &randomGenerator)

    for index in order {
      let gridPosition = gridIndex(for: points[index])
      var neighboringIdentifiers = Set<UUID>()
      let column = gridPosition % columnCount
      let row = gridPosition / columnCount

      for rowOffset in -2...2 {
        for columnOffset in -2...2 {
          let neighborColumn = (column + columnOffset + columnCount) % columnCount
          let neighborRow = (row + rowOffset + rowCount) % rowCount
          let neighborGridIndex = neighborRow * columnCount + neighborColumn

          for pointIndex in grid[neighborGridIndex] {
            neighboringIdentifiers.insert(assignments[pointIndex].id)
          }
        }
      }

      let availableItems = items.filter { !neighboringIdentifiers.contains($0.id) }
      let chosenItem = availableItems.isEmpty
        ? pickItem(from: items, randomGenerator: &randomGenerator)
        : pickItem(from: availableItems, randomGenerator: &randomGenerator)

      assignments[index] = chosenItem
      grid[gridPosition].append(index)
    }

    return assignments
  }

  private static func pickItem(
    from items: [TesseraItem],
    randomGenerator: inout some RandomNumberGenerator,
  ) -> TesseraItem {
    let totalWeight = items.reduce(0) { $0 + $1.weight }
    let randomValue = Double.random(in: 0..<totalWeight, using: &randomGenerator)

    var accumulator = 0.0
    for item in items {
      accumulator += item.weight
      if randomValue < accumulator { return item }
    }
    return items.last!
  }
}
