// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// Describes a single tessellated pattern configuration.
public struct Tessera: View {
  public var size: CGSize
  public var items: [TesseraItem]
  public var seed: UInt64
  public var minimumSpacing: CGFloat
  /// Desired fill density between 0 and 1; scales how many items are attempted.
  public var density: Double
  public var baseScaleRange: ClosedRange<CGFloat>

  /// Creates a tessera definition.
  /// - Parameters:
  ///   - size: Size of the square tile that will be repeated.
  ///   - items: Items that can be placed inside each tile.
  ///   - seed: Seed for deterministic randomness. Defaults to a random seed.
  ///   - minimumSpacing: Minimum distance between item centers.
  ///   - density: Desired fill density between 0 and 1.
  ///   - baseScaleRange: Default scale range applied when an item does not provide its own scale range.
  public init(
    size: CGSize,
    items: [TesseraItem],
    seed: UInt64 = Tessera.randomSeed(),
    minimumSpacing: CGFloat,
    density: Double = 0.5,
    baseScaleRange: ClosedRange<CGFloat> = 0.9...1.1,
  ) {
    self.size = size
    self.items = items
    self.seed = seed
    self.minimumSpacing = minimumSpacing
    self.density = density
    self.baseScaleRange = baseScaleRange
  }

  /// Renders the tessera as a single tile view.
  public var body: some View {
    TesseraCanvasTile(tessera: self, seed: seed)
  }

  /// Generates a new random seed.
  public static func randomSeed() -> UInt64 {
    UInt64.random(in: 1...UInt64.max)
  }
}
