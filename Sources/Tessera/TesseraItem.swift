// By Dennis Müller

import SwiftUI

/// Describes a drawable item that can appear inside a tessera tile.
public struct TesseraItem: Identifiable {
  public var id: UUID
  public var weight: Double
  public var allowedRotationRange: ClosedRange<Angle>
  public var scaleRange: ClosedRange<Double>?
  public var collisionShape: CollisionShape
  private let builder: () -> AnyView

  /// Creates an item.
  /// - Parameters:
  ///   - id: Identifier; defaults to a random value so identical presets can coexist.
  ///   - weight: Relative probability of being chosen.
  ///   - allowedRotationRange: Range of angles the item may rotate within.
  ///   - scaleRange: Optional scale range overriding the tessera's base scale range.
  ///   - collisionShape: Approximate geometry used for collision checks.
  ///   - content: View builder for the rendered symbol.
  public init(
    id: UUID = UUID(),
    weight: Double = 1,
    allowedRotationRange: ClosedRange<Angle> = Angle.fullCircle,
    scaleRange: ClosedRange<Double>? = nil,
    collisionShape: CollisionShape,
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.id = id
    self.weight = weight
    self.allowedRotationRange = allowedRotationRange
    self.scaleRange = scaleRange
    self.collisionShape = collisionShape
    builder = { AnyView(content()) }
  }

  /// Convenience initializer that derives a circular collision shape from an approximate size.
  /// - Parameters:
  ///   - id: Identifier; defaults to a random value so identical presets can coexist.
  ///   - weight: Relative probability of being chosen.
  ///   - allowedRotationRange: Range of angles the item may rotate within.
  ///   - scaleRange: Optional scale range overriding the tessera's base scale range.
  ///   - approximateSize: Size used to build a conservative circular collider.
  ///   - content: View builder for the rendered symbol.
  public init(
    id: UUID = UUID(),
    weight: Double = 1,
    allowedRotationRange: ClosedRange<Angle> = Angle.fullCircle,
    scaleRange: ClosedRange<Double>? = nil,
    approximateSize: CGSize = CGSize(width: 30, height: 30),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    let radius = hypot(approximateSize.width, approximateSize.height) / 2
    self.init(
      id: id,
      weight: weight,
      allowedRotationRange: allowedRotationRange,
      scaleRange: scaleRange,
      collisionShape: .circle(center: .zero, radius: radius),
      content: content,
    )
  }

  @ViewBuilder
  func makeView() -> some View {
    builder()
  }
}

public extension Angle {
  /// The full 0°…360° range.
  static var fullCircle: ClosedRange<Angle> { .degrees(0)...(.degrees(360)) }
}
