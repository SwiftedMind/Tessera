// By Dennis Müller

import CoreGraphics
import SwiftUI

/// Describes where a fixed placement should appear inside a tessera canvas.
public enum TesseraPlacementPosition: Hashable {
  /// Absolute position in canvas coordinates (origin at top-left).
  case absolute(CGPoint)
  /// Relative position as a `UnitPoint` within the canvas, with an optional point offset.
  case relative(UnitPoint, offset: CGSize = .zero)

  func resolvedPoint(in canvasSize: CGSize) -> CGPoint {
    switch self {
    case let .absolute(point):
      point
    case let .relative(unitPoint, offset):
      CGPoint(
        x: unitPoint.x * canvasSize.width + offset.width,
        y: unitPoint.y * canvasSize.height + offset.height,
      )
    }
  }

  public static func == (lhs: TesseraPlacementPosition, rhs: TesseraPlacementPosition) -> Bool {
    switch (lhs, rhs) {
    case let (.absolute(lhsPoint), .absolute(rhsPoint)):
      lhsPoint.x == rhsPoint.x && lhsPoint.y == rhsPoint.y
    case let (.relative(lhsUnitPoint, lhsOffset), .relative(rhsUnitPoint, rhsOffset)):
      lhsUnitPoint.x == rhsUnitPoint.x
        && lhsUnitPoint.y == rhsUnitPoint.y
        && lhsOffset.width == rhsOffset.width
        && lhsOffset.height == rhsOffset.height
    default:
      false
    }
  }

  public func hash(into hasher: inout Hasher) {
    switch self {
    case let .absolute(point):
      hasher.combine(0)
      hasher.combine(point.x)
      hasher.combine(point.y)
    case let .relative(unitPoint, offset):
      hasher.combine(1)
      hasher.combine(unitPoint.x)
      hasher.combine(unitPoint.y)
      hasher.combine(offset.width)
      hasher.combine(offset.height)
    }
  }
}

public extension TesseraPlacementPosition {
  /// A centered relative placement.
  static func centered(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.center, offset: offset)
  }

  static func topLeading(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.topLeading, offset: offset)
  }

  static func top(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.top, offset: offset)
  }

  static func topTrailing(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.topTrailing, offset: offset)
  }

  static func leading(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.leading, offset: offset)
  }

  static func trailing(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.trailing, offset: offset)
  }

  static func bottomLeading(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.bottomLeading, offset: offset)
  }

  static func bottom(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.bottom, offset: offset)
  }

  static func bottomTrailing(offset: CGSize = .zero) -> TesseraPlacementPosition {
    .relative(.bottomTrailing, offset: offset)
  }
}
