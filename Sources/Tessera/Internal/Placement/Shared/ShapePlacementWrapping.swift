// By Dennis Müller

import CoreGraphics

/// Provides wrapping helpers for seamless tiling and toroidal index math.
enum ShapePlacementWrapping {
  /// Returns the set of wrap offsets for collision checks.
  ///
  /// - Parameters:
  ///   - size: The tile size that determines the wrap distance.
  ///   - edgeBehavior: The edge behavior that determines whether wrapping is needed.
  /// - Returns: A list of offsets to apply when checking collisions across edges.
  static func wrapOffsets(for size: CGSize, edgeBehavior: TesseraEdgeBehavior) -> [CGPoint] {
    switch edgeBehavior {
    case .finite:
      [.init(x: 0, y: 0)]
    case .seamlessWrapping:
      [
        .init(x: 0, y: 0),
        .init(x: size.width, y: 0),
        .init(x: -size.width, y: 0),
        .init(x: 0, y: size.height),
        .init(x: 0, y: -size.height),
        .init(x: size.width, y: size.height),
        .init(x: size.width, y: -size.height),
        .init(x: -size.width, y: size.height),
        .init(x: -size.width, y: -size.height),
      ]
    }
  }

  /// Wraps a grid index into the `[0, modulus)` range.
  ///
  /// - Parameters:
  ///   - index: The index to wrap.
  ///   - modulus: The modulus to wrap within.
  /// - Returns: A non-negative index within the modulus.
  static func wrappedIndex(_ index: Int, modulus: Int) -> Int {
    guard modulus > 0 else { return 0 }

    let remainder = index % modulus
    return remainder >= 0 ? remainder : remainder + modulus
  }

  /// Wraps a position into the tile bounds.
  ///
  /// - Parameters:
  ///   - position: The position to wrap.
  ///   - size: The tile size that determines the wrap distance.
  /// - Returns: A position mapped into the tile bounds.
  static func wrappedPosition(_ position: CGPoint, in size: CGSize) -> CGPoint {
    CGPoint(
      x: wrappedCoordinate(position.x, modulus: size.width),
      y: wrappedCoordinate(position.y, modulus: size.height),
    )
  }

  /// Wraps a single coordinate into the `[0, modulus)` range.
  ///
  /// - Parameters:
  ///   - value: The coordinate value to wrap.
  ///   - modulus: The modulus to wrap within.
  /// - Returns: A non-negative coordinate within the modulus.
  static func wrappedCoordinate(_ value: CGFloat, modulus: CGFloat) -> CGFloat {
    guard modulus > 0 else { return 0 }

    let remainder = value.truncatingRemainder(dividingBy: modulus)
    return remainder >= 0 ? remainder : remainder + modulus
  }
}
