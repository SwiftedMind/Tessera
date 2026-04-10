// By Dennis Müller

import CoreGraphics

protocol ShapePlacementMaskOptimizing: PlacementMask {
  func shapePlacementMaskValidationResult(
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: ShapePlacementMaskConstraint.Mode,
    centerAlreadyValidated: Bool,
    boundingRadius: CGFloat,
  ) -> ShapePlacementMaskConstraint.ValidationResult
}

/// Shared mask-boundary validation used by organic and grid placement engines.
enum ShapePlacementMaskConstraint {
  /// Defines how strictly collision geometry must stay inside an alpha mask.
  enum Mode {
    /// Requires only the placement center point to be inside the mask.
    case centerPoint
    /// Requires sampled collision geometry points to stay inside the mask.
    case sampledCollisionGeometry
  }

  enum ValidationResult: Equatable {
    case accepted
    case rejectedAtCenterPoint
    case rejectedAtSampledGeometry
  }

  /// Returns `true` when the candidate collision geometry stays inside the mask.
  static func isPlacementInsideMask(
    _ alphaMask: any PlacementMask,
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: Mode,
    centerAlreadyValidated: Bool = false,
    boundingRadius: CGFloat = 0,
  ) -> Bool {
    validationResult(
      alphaMask,
      collisionTransform: collisionTransform,
      polygons: polygons,
      mode: mode,
      centerAlreadyValidated: centerAlreadyValidated,
      boundingRadius: boundingRadius,
    ) == .accepted
  }

  /// Returns the exact stage that rejected the candidate, if any.
  static func validationResult(
    _ alphaMask: any PlacementMask,
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: Mode,
    centerAlreadyValidated: Bool = false,
    boundingRadius: CGFloat = 0,
  ) -> ValidationResult {
    if let optimizedMask = alphaMask as? any ShapePlacementMaskOptimizing {
      return optimizedMask.shapePlacementMaskValidationResult(
        collisionTransform: collisionTransform,
        polygons: polygons,
        mode: mode,
        centerAlreadyValidated: centerAlreadyValidated,
        boundingRadius: boundingRadius,
      )
    }

    return validationResult(
      contains: PlacementMaskContainment.containsFunction(for: alphaMask),
      collisionTransform: collisionTransform,
      polygons: polygons,
      mode: mode,
      centerAlreadyValidated: centerAlreadyValidated,
    )
  }

  /// Returns `true` when all required sampled points satisfy the provided inclusion closure.
  static func isPlacementInsideMask(
    contains: (CGPoint) -> Bool,
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: Mode,
    centerAlreadyValidated: Bool = false,
  ) -> Bool {
    validationResult(
      contains: contains,
      collisionTransform: collisionTransform,
      polygons: polygons,
      mode: mode,
      centerAlreadyValidated: centerAlreadyValidated,
    ) == .accepted
  }

  /// Returns the exact stage that rejected the candidate, if any.
  static func validationResult(
    contains: (CGPoint) -> Bool,
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: Mode,
    centerAlreadyValidated: Bool = false,
  ) -> ValidationResult {
    if centerAlreadyValidated == false, contains(collisionTransform.position) == false {
      return .rejectedAtCenterPoint
    }
    guard mode == .sampledCollisionGeometry else { return .accepted }
    guard polygons.isEmpty == false else { return .accepted }

    for polygon in polygons {
      for point in polygon.localMaskSamplePoints {
        if contains(CollisionMath.applyTransform(point, using: collisionTransform)) == false {
          return .rejectedAtSampledGeometry
        }
      }
    }

    return .accepted
  }

  /// Produces mask-validation sample points for transformed collision geometry.
  ///
  /// Sampling includes shape centers, polygon vertices, and edge midpoints.
  static func sampledPoints(
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
  ) -> [CGPoint] {
    var sampled: [CGPoint] = [collisionTransform.position]
    sampled.reserveCapacity(1 + polygons.reduce(0) { $0 + $1.localMaskSamplePoints.count })

    for polygon in polygons {
      for point in polygon.localMaskSamplePoints {
        sampled.append(CollisionMath.applyTransform(point, using: collisionTransform))
      }
    }

    return sampled
  }
}

extension MosaicShapeMask: ShapePlacementMaskOptimizing {
  func shapePlacementMaskValidationResult(
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    mode: ShapePlacementMaskConstraint.Mode,
    centerAlreadyValidated: Bool,
    boundingRadius: CGFloat,
  ) -> ShapePlacementMaskConstraint.ValidationResult {
    if centerAlreadyValidated == false, contains(collisionTransform.position) == false {
      return .rejectedAtCenterPoint
    }
    guard mode == .sampledCollisionGeometry else { return .accepted }
    guard polygons.isEmpty == false else { return .accepted }

    if fitsInsideExactShape(
      collisionTransform: collisionTransform,
      polygons: polygons,
      boundingRadius: boundingRadius,
    ) == false {
      return .rejectedAtSampledGeometry
    }

    return .accepted
  }

  private func fitsInsideExactShape(
    collisionTransform: CollisionTransform,
    polygons: [CollisionPolygon],
    boundingRadius: CGFloat,
  ) -> Bool {
    if let exactShape {
      switch exactShape {
      case let .circle(circle):
        let centerDeltaX = collisionTransform.position.x - circle.center.x
        let centerDeltaY = collisionTransform.position.y - circle.center.y
        let centerDistanceSquared = centerDeltaX * centerDeltaX + centerDeltaY * centerDeltaY
        let paddedBoundingRadius = max(0, boundingRadius)
        let maximumInsideDistance = circle.radius - paddedBoundingRadius
        let minimumOutsideDistance = circle.radius + paddedBoundingRadius

        if maximumInsideDistance >= 0,
           centerDistanceSquared <= maximumInsideDistance * maximumInsideDistance {
          return true
        }

        if centerDistanceSquared > minimumOutsideDistance * minimumOutsideDistance {
          return false
        }

        let radiusSquared = circle.radius * circle.radius
        for polygon in polygons {
          for point in polygon.localMaskSamplePoints {
            let transformedPoint = CollisionMath.applyTransform(point, using: collisionTransform)
            let deltaX = transformedPoint.x - circle.center.x
            let deltaY = transformedPoint.y - circle.center.y
            if deltaX * deltaX + deltaY * deltaY > radiusSquared {
              return false
            }
          }
        }
        return true

      case let .rectangle(rectangle):
        let expandedHalfWidth = rectangle.halfWidth + max(0, boundingRadius)
        let expandedHalfHeight = rectangle.halfHeight + max(0, boundingRadius)
        let deltaX = collisionTransform.position.x - rectangle.position.x
        let deltaY = collisionTransform.position.y - rectangle.position.y
        let localX = (deltaX * rectangle.cosineRotation + deltaY * rectangle.sineRotation) * rectangle.inverseScale
        let localY = (-deltaX * rectangle.sineRotation + deltaY * rectangle.cosineRotation) * rectangle.inverseScale
        let epsilon: CGFloat = 0.000_1
        if abs(localX - rectangle.localCenter.x) > expandedHalfWidth + epsilon ||
          abs(localY - rectangle.localCenter.y) > expandedHalfHeight + epsilon {
          return false
        }

        for polygon in polygons {
          for point in polygon.localMaskSamplePoints {
            if containsRectanglePoint(
              CollisionMath.applyTransform(point, using: collisionTransform),
              rectangle: rectangle,
            ) == false {
              return false
            }
          }
        }
        return true
      }
    }

    for polygon in polygons {
      for point in polygon.localMaskSamplePoints {
        if contains(CollisionMath.applyTransform(point, using: collisionTransform)) == false {
          return false
        }
      }
    }

    return true
  }

  private func containsRectanglePoint(
    _ point: CGPoint,
    rectangle: ExactShape.Rectangle,
  ) -> Bool {
    guard rectangle.inverseScale != 0 else {
      return false
    }

    let deltaX = point.x - rectangle.position.x
    let deltaY = point.y - rectangle.position.y
    let localX = (deltaX * rectangle.cosineRotation + deltaY * rectangle.sineRotation) * rectangle.inverseScale
    let localY = (-deltaX * rectangle.sineRotation + deltaY * rectangle.cosineRotation) * rectangle.inverseScale
    let epsilon: CGFloat = 0.000_1
    return abs(localX - rectangle.localCenter.x) <= rectangle.halfWidth + epsilon &&
      abs(localY - rectangle.localCenter.y) <= rectangle.halfHeight + epsilon
  }
}
