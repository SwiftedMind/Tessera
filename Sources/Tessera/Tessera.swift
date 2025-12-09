// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// Describes a single tessellated pattern configuration.
public struct Tessera {
  public var size: CGSize
  public var items: [TesseraItem]
  public var seed: UInt64
  public var minimumSpacing: CGFloat
  public var fillProbability: Double
  public var baseScaleRange: ClosedRange<CGFloat>

  /// Creates a tessera definition.
  /// - Parameters:
  ///   - size: Size of the square tile that will be repeated.
  ///   - items: Items that can be placed inside each tile.
  ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
  ///   - minimumSpacing: Minimum distance between item centers.
  ///   - fillProbability: Density factor between 0 and 1.
  ///   - baseScaleRange: Default scale range applied when an item does not provide its own scale range.
  public init(
    size: CGSize,
    items: [TesseraItem],
    seed: UInt64 = Tessera.randomSeed(),
    minimumSpacing: CGFloat,
    fillProbability: Double,
    baseScaleRange: ClosedRange<CGFloat> = 0.9...1.1,
  ) {
    self.size = size
    self.items = items
    self.seed = seed
    self.minimumSpacing = minimumSpacing
    self.fillProbability = fillProbability
    self.baseScaleRange = baseScaleRange
  }

  /// Generates a new random seed.
  public static func randomSeed() -> UInt64 {
    UInt64.random(in: 1...UInt64.max)
  }
}
