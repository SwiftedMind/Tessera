// By Dennis Müller

import Foundation
import SwiftUI

/// Determines how a choice symbol resolves one of its child symbols.
public enum TesseraSymbolChoiceStrategy: Hashable, Sendable {
  /// Picks a child using the child symbol's `weight` as relative probability.
  case weightedRandom
  /// Picks child symbols in deterministic order (`first`, `second`, ... then wrap).
  case sequence
  /// Picks child symbols using caller-provided indices (`indices[0]`, `indices[1]`, ... then wrap).
  /// Indices are normalized modulo child count, so negative and out-of-range values remain valid.
  case indexSequence([Int])
}

/// Describes a drawable symbol that can appear inside a tessera tile.
public struct TesseraSymbol: Identifiable, @unchecked Sendable {
  /// Stable identity for the symbol.
  public var id: UUID
  /// Relative probability of being selected during placement as a top-level symbol.
  public var weight: Double
  /// Rotation range sampled for each placed instance.
  public var allowedRotationRange: ClosedRange<Angle>
  /// Optional per-symbol scale override.
  public var scaleRange: ClosedRange<Double>?
  /// Collision geometry used during overlap checks.
  public var collisionShape: CollisionShape
  /// Strategy used when `choices` contains child symbols.
  public var choiceStrategy: TesseraSymbolChoiceStrategy
  /// Optional seed salt mixed into choice resolution.
  public var choiceSeed: UInt64?
  /// Optional child symbols. When non-empty, one child is resolved for each accepted placement.
  public var choices: [TesseraSymbol]
  private let builder: () -> AnyView

  /// Creates an symbol.
  /// - Parameters:
  ///   - id: Identifier; defaults to a random value so identical presets can coexist.
  ///   - weight: Relative probability of being chosen.
  ///   - allowedRotationRange: Range of angles the symbol may rotate within.
  ///   - scaleRange: Optional scale range overriding the tessera's base scale range.
  ///   - collisionShape: Approximate geometry used for collision checks. Complex polygons and multi-polygon shapes
  ///     increase placement cost.
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
    choiceStrategy = .weightedRandom
    choiceSeed = nil
    choices = []
    builder = { AnyView(content()) }
  }

  /// Convenience initializer that derives a circular collision shape from an approximate size.
  /// - Parameters:
  ///   - id: Identifier; defaults to a random value so identical presets can coexist.
  ///   - weight: Relative probability of being chosen.
  ///   - allowedRotationRange: Range of angles the symbol may rotate within.
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

  /// Creates a choice symbol that resolves one child symbol per accepted placement.
  /// - Parameters:
  ///   - id: Identifier of the choice symbol.
  ///   - weight: Relative probability of selecting this symbol among top-level symbols.
  ///   - choiceStrategy: Strategy used to resolve from `choices`.
  ///   - choiceSeed: Optional seed salt for deterministic per-symbol choice variation.
  ///   - choices: Child symbols to choose from.
  public init(
    id: UUID = UUID(),
    weight: Double = 1,
    choiceStrategy: TesseraSymbolChoiceStrategy = .weightedRandom,
    choiceSeed: UInt64? = nil,
    choices: [TesseraSymbol],
  ) {
    self.id = id
    self.weight = weight
    allowedRotationRange = Angle.fullCircle
    scaleRange = nil
    collisionShape = .circle(center: .zero, radius: 0)
    self.choiceStrategy = choiceStrategy
    self.choiceSeed = choiceSeed
    self.choices = choices
    builder = { AnyView(EmptyView()) }
  }

  @ViewBuilder
  func makeView() -> some View {
    builder()
  }
}

extension TesseraSymbol {
  var isChoiceSymbol: Bool {
    choices.isEmpty == false
  }

  var renderableLeafSymbols: [TesseraSymbol] {
    guard choices.isEmpty == false else { return [self] }

    return choices.flatMap(\.renderableLeafSymbols)
  }
}

extension Collection<TesseraSymbol> {
  var uniqueRenderableLeafSymbols: [TesseraSymbol] {
    var seen: Set<UUID> = []
    var result: [TesseraSymbol] = []
    for symbol in self {
      for leafSymbol in symbol.renderableLeafSymbols where seen.insert(leafSymbol.id).inserted {
        result.append(leafSymbol)
      }
    }
    return result
  }

  var renderableLeafLookupByID: [UUID: TesseraSymbol] {
    Dictionary(uniqueKeysWithValues: uniqueRenderableLeafSymbols.map { ($0.id, $0) })
  }
}

public extension Angle {
  /// The full 0°…360° range.
  static var fullCircle: ClosedRange<Angle> { .degrees(0)...(.degrees(360)) }
}
