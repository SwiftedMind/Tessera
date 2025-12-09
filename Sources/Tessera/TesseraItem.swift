// By Dennis Müller

import SwiftUI

/// Describes a drawable item that can appear inside a tessera tile.
public struct TesseraItem: Identifiable {
  public var id: UUID
  public var weight: Double
  public var allowedRotationRange: ClosedRange<Angle>
  public var scaleRange: ClosedRange<CGFloat>?
  private let builder: () -> AnyView

  /// Creates an item.
  /// - Parameters:
  ///   - id: Identifier; defaults to a random value so identical presets can coexist.
  ///   - weight: Relative probability of being chosen.
  ///   - allowedRotationRange: Range of angles the item may rotate within.
  ///   - scaleRange: Optional scale range overriding the tessera's base scale range.
  ///   - content: View builder for the rendered symbol.
  public init(
    id: UUID = UUID(),
    weight: Double = 1,
    allowedRotationRange: ClosedRange<Angle> = Angle.fullCircle,
    scaleRange: ClosedRange<CGFloat>? = nil,
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.id = id
    self.weight = weight
    self.allowedRotationRange = allowedRotationRange
    self.scaleRange = scaleRange
    builder = { AnyView(content()) }
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
    TesseraItem {
      Rectangle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.8))
        .frame(width: 30, height: 30)
    }
  }

  /// A softly rounded rectangle outline.
  static var roundedOutline: TesseraItem {
    TesseraItem {
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 4)
        .frame(width: 30, height: 30)
    }
  }

  /// A celebratory SF Symbol.
  static var partyPopper: TesseraItem {
    TesseraItem(allowedRotationRange: (.degrees(-45))...(.degrees(45))) {
      Image(systemName: "party.popper.fill")
        .foregroundStyle(.red.opacity(0.5))
        .font(.largeTitle)
    }
  }

  /// A minus glyph.
  static var minus: TesseraItem {
    TesseraItem {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// An equals glyph.
  static var equals: TesseraItem {
    TesseraItem {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// A subtle circle outline.
  static var circleOutline: TesseraItem {
    TesseraItem {
      Circle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.2))
        .frame(width: 30, height: 30)
    }
  }
}
