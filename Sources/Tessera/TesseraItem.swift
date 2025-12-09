// By Dennis Müller

import SwiftUI

/// Describes a drawable item that can appear inside a tessera tile.
public struct TesseraItem: Identifiable {
  public var id: UUID
  public var weight: Double
  public var allowedRotationRange: ClosedRange<Angle>
  public var scaleRange: ClosedRange<CGFloat>?
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
    scaleRange: ClosedRange<CGFloat>? = nil,
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
    scaleRange: ClosedRange<CGFloat>? = nil,
    approximateSize: CGSize = CGSize(width: 30, height: 30),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    let radius = hypot(approximateSize.width, approximateSize.height) / 2
    self.init(
      id: id,
      weight: weight,
      allowedRotationRange: allowedRotationRange,
      scaleRange: scaleRange,
      collisionShape: .circle(radius: radius),
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

public extension TesseraItem {
  /// A lightly stroked square outline.
  static var squareOutline: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 34, height: 34)),
    ) {
      Rectangle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.8))
        .frame(width: 30, height: 30)
    }
  }

  /// A softly rounded rectangle outline.
  static var roundedOutline: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 34, height: 34)),
    ) {
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 4)
        .frame(width: 30, height: 30)
    }
  }

  /// A celebratory SF Symbol.
  static var partyPopper: TesseraItem {
    TesseraItem(
      allowedRotationRange: .degrees(-45)...(.degrees(45)),
      collisionShape: .circle(radius: 20),
    ) {
      Image(systemName: "party.popper.fill")
        .foregroundStyle(.red.opacity(0.5))
        .font(.largeTitle)
    }
  }

  /// A minus glyph.
  static var minus: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 36, height: 4)),
    ) {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// An equals glyph.
  static var equals: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 36, height: 12)),
    ) {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// A subtle circle outline.
  static var circleOutline: TesseraItem {
    TesseraItem(
      collisionShape: .circle(radius: 15),
    ) {
      Circle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.2))
        .frame(width: 30, height: 30)
    }
  }
}
