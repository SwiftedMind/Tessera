// By Dennis Müller

import CoreGraphics
import Foundation
import SwiftUI

/// A fixed view placed once into a finite tessera canvas.
///
/// Fixed symbols participate in collision checks so generated symbols fill around them.
public struct TesseraPinnedSymbol: Identifiable, @unchecked Sendable {
  /// Stable identity for the pinned symbol.
  public var id: UUID
  /// Center position inside the canvas.
  public var position: TesseraPlacementPosition
  /// Draw order shared with generated and other pinned symbols. Lower values render behind higher values.
  ///
  /// This affects rendering only. Placement and collisions stay unchanged.
  public var zIndex: Double
  /// Rotation applied to drawing and collision checks.
  public var rotation: Angle
  /// Uniform scale applied to drawing and collision checks.
  public var scale: CGFloat
  /// Collision geometry used as an obstacle for generated symbols.
  ///
  /// Complex polygons and multi-polygon shapes increase placement cost.
  public var collisionShape: CollisionShape
  private let builder: () -> AnyView

  /// Creates a fixed symbol.
  /// - Parameters:
  ///   - position: Center position inside the canvas.
  ///   - zIndex: Draw order shared with generated and other pinned symbols. Lower values render behind higher values.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - collisionShape: Obstacle shape in local space. Complex polygons and multi-polygon shapes increase placement
  ///     cost.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: TesseraPlacementPosition,
    zIndex: Double = 0,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    collisionShape: CollisionShape,
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.id = id
    self.position = position
    self.zIndex = zIndex
    self.rotation = rotation
    self.scale = scale
    self.collisionShape = collisionShape
    builder = { AnyView(content()) }
  }

  /// Convenience initializer for absolute positions.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    zIndex: Double = 0,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    collisionShape: CollisionShape,
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.init(
      id: id,
      position: .absolute(position),
      zIndex: zIndex,
      rotation: rotation,
      scale: scale,
      collisionShape: collisionShape,
      content: content,
    )
  }

  /// Convenience initializer that derives a circular collision shape from an approximate size.
  /// - Parameters:
  ///   - position: Center position inside the canvas.
  ///   - zIndex: Draw order shared with generated and other pinned symbols. Lower values render behind higher values.
  ///   - rotation: Rotation applied to drawing and collisions.
  ///   - scale: Uniform scale applied to drawing and collisions.
  ///   - approximateSize: Size used to build a conservative circular collider.
  ///   - content: View builder for the fixed symbol.
  public init(
    id: UUID = UUID(),
    position: TesseraPlacementPosition,
    zIndex: Double = 0,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    approximateSize: CGSize = CGSize(width: 30, height: 30),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    let radius = hypot(approximateSize.width, approximateSize.height) / 2
    self.init(
      id: id,
      position: position,
      zIndex: zIndex,
      rotation: rotation,
      scale: scale,
      collisionShape: .circle(center: .zero, radius: radius),
      content: content,
    )
  }

  /// Convenience initializer for absolute positions.
  public init(
    id: UUID = UUID(),
    position: CGPoint,
    zIndex: Double = 0,
    rotation: Angle = .degrees(0),
    scale: CGFloat = 1,
    approximateSize: CGSize = CGSize(width: 30, height: 30),
    @ViewBuilder content: @escaping () -> some View,
  ) {
    self.init(
      id: id,
      position: .absolute(position),
      zIndex: zIndex,
      rotation: rotation,
      scale: scale,
      approximateSize: approximateSize,
      content: content,
    )
  }

  @ViewBuilder
  func makeView() -> some View {
    builder()
  }

  func resolvedPosition(in canvasSize: CGSize) -> CGPoint {
    position.resolvedPoint(in: canvasSize)
  }
}
