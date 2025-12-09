// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Generates evenly spaced random points with wrap-around edges.
enum PoissonDiskGenerator {
  static func makePoints(
    in size: CGSize,
    minimumSpacing: CGFloat,
    fillProbability: Double,
    randomGenerator: inout some RandomNumberGenerator,
  ) -> [CGPoint] {
    let clampedProbability = max(0, min(1, fillProbability))
    let radius = minimumSpacing
    let radiusSquared = radius * radius
    let cellSize = radius / CGFloat(Double(2).squareRoot())

    let columnCount = max(Int(ceil(size.width / cellSize)), 1)
    let rowCount = max(Int(ceil(size.height / cellSize)), 1)
    var grid = Array(repeating: -1, count: columnCount * rowCount)

    let approximateCapacity = (size.width * size.height) / (radius * radius)
    let targetCount = max(0, Int(ceil(Double(approximateCapacity) * clampedProbability)))
    guard targetCount > 0 else { return [] }

    func wrapped(_ value: CGFloat, max: CGFloat) -> CGFloat {
      let modulo = value.truncatingRemainder(dividingBy: max)
      return modulo < 0 ? modulo + max : modulo
    }

    func gridIndex(for point: CGPoint) -> Int {
      let wrappedX = wrapped(point.x, max: size.width)
      let wrappedY = wrapped(point.y, max: size.height)
      let column = Int(wrappedX / cellSize) % columnCount
      let row = Int(wrappedY / cellSize) % rowCount
      return row * columnCount + column
    }

    func isFarEnough(from candidate: CGPoint, comparedTo points: [CGPoint]) -> Bool {
      let position = gridIndex(for: candidate)
      let column = position % columnCount
      let row = position / columnCount

      for rowOffset in -2...2 {
        for columnOffset in -2...2 {
          let neighborColumn = (column + columnOffset + columnCount) % columnCount
          let neighborRow = (row + rowOffset + rowCount) % rowCount
          let neighborIndex = neighborRow * columnCount + neighborColumn

          let pointIndex = grid[neighborIndex]
          guard pointIndex != -1 else { continue }

          let neighborPoint = points[pointIndex]
          let deltaX = abs(neighborPoint.x - candidate.x)
          let deltaY = abs(neighborPoint.y - candidate.y)
          let wrappedDeltaX = min(deltaX, size.width - deltaX)
          let wrappedDeltaY = min(deltaY, size.height - deltaY)

          if (wrappedDeltaX * wrappedDeltaX + wrappedDeltaY * wrappedDeltaY) < radiusSquared {
            return false
          }
        }
      }
      return true
    }

    var points: [CGPoint] = []
    var activePoints: [CGPoint] = []

    let initialPoint = CGPoint(
      x: CGFloat.random(in: 0..<size.width, using: &randomGenerator),
      y: CGFloat.random(in: 0..<size.height, using: &randomGenerator),
    )

    let initialIndex = gridIndex(for: initialPoint)
    grid[initialIndex] = 0
    points.append(initialPoint)
    activePoints.append(initialPoint)

    let maximumAttemptsPerPoint = 30

    while !activePoints.isEmpty, points.count < targetCount {
      let activeIndex = Int.random(in: 0..<activePoints.count, using: &randomGenerator)
      let activePoint = activePoints[activeIndex]
      var didFind = false

      for _ in 0..<maximumAttemptsPerPoint {
        let angle = Double.random(in: 0..<(2 * .pi), using: &randomGenerator)
        let distance = CGFloat.random(in: radius...(2 * radius), using: &randomGenerator)
        let candidate = CGPoint(
          x: wrapped(activePoint.x + distance * CGFloat(cos(angle)), max: size.width),
          y: wrapped(activePoint.y + distance * CGFloat(sin(angle)), max: size.height),
        )

        guard isFarEnough(from: candidate, comparedTo: points) else { continue }

        let slot = gridIndex(for: candidate)
        grid[slot] = points.count
        points.append(candidate)
        activePoints.append(candidate)
        didFind = true
        break
      }

      if !didFind {
        activePoints.remove(at: activeIndex)
      }
    }

    return points
  }
}
