// By Dennis Müller

import CoreGraphics

/// Evaluates value-based steering fields in normalized tile space.
enum ShapePlacementSteering {
  /// Prepared evaluator for repeated sampling of a steering field on a fixed canvas.
  struct Evaluator {
    private enum PreparedShape {
      case linear(
        from: PlacementModel.SteeringField.Point,
        axisX: Double,
        axisY: Double,
        axisLengthSquared: Double,
      )
      case radial(center: CGPoint, radius: Double)
    }

    private var preparedShape: PreparedShape
    private var lower: Double
    private var upper: Double
    private var easing: PlacementModel.SteeringField.Easing
    private var canvasSize: CGSize
    private var defaultValue: Double

    fileprivate init(
      field: PlacementModel.SteeringField,
      canvasSize: CGSize,
      defaultValue: Double,
    ) {
      let lower = ShapePlacementSteering.sanitize(field.values.lowerBound, fallback: defaultValue)
      let upper = ShapePlacementSteering.sanitize(field.values.upperBound, fallback: defaultValue)

      self.lower = lower
      self.upper = upper
      easing = field.easing
      self.canvasSize = canvasSize
      self.defaultValue = defaultValue

      switch field.shape {
      case let .linear(from: from, to: to):
        let normalizedFrom = ShapePlacementSteering.normalizedFieldPoint(from)
        let normalizedTo = ShapePlacementSteering.normalizedFieldPoint(to)
        let axisX = normalizedTo.x - normalizedFrom.x
        let axisY = normalizedTo.y - normalizedFrom.y
        let axisLengthSquared = axisX * axisX + axisY * axisY
        preparedShape = .linear(
          from: normalizedFrom,
          axisX: axisX,
          axisY: axisY,
          axisLengthSquared: axisLengthSquared,
        )
      case let .radial(center: center, radius: radius):
        let normalizedCenter = ShapePlacementSteering.normalizedFieldPoint(center)
        let centerPoint = ShapePlacementSteering.pointFromNormalized(
          normalizedCenter,
          canvasSize: canvasSize,
        )
        let radiusPoints = ShapePlacementSteering.resolvedRadius(
          radius,
          center: centerPoint,
          canvasSize: canvasSize,
        )
        preparedShape = .radial(center: centerPoint, radius: radiusPoints)
      }
    }

    func value(at position: CGPoint) -> Double {
      let progress: Double = switch preparedShape {
      case let .linear(from: from, axisX: axisX, axisY: axisY, axisLengthSquared: axisLengthSquared):
        linearProgress(
          position: position,
          from: from,
          axisX: axisX,
          axisY: axisY,
          axisLengthSquared: axisLengthSquared,
        )
      case let .radial(center: center, radius: radius):
        radialProgress(
          position: position,
          center: center,
          radius: radius,
        )
      }

      let eased = ShapePlacementSteering.easedProgress(progress, easing: easing)
      let interpolated = lower + (upper - lower) * eased
      return ShapePlacementSteering.sanitize(interpolated, fallback: defaultValue)
    }

    private func linearProgress(
      position: CGPoint,
      from: PlacementModel.SteeringField.Point,
      axisX: Double,
      axisY: Double,
      axisLengthSquared: Double,
    ) -> Double {
      guard axisLengthSquared > 0.000_000_1 else {
        return 0
      }

      let normalizedPoint = ShapePlacementSteering.normalizedPosition(position, canvasSize: canvasSize)
      let pointOffsetX = normalizedPoint.x - from.x
      let pointOffsetY = normalizedPoint.y - from.y
      let projected = (pointOffsetX * axisX + pointOffsetY * axisY) / axisLengthSquared
      return ShapePlacementSteering.clamp(projected, min: 0, max: 1)
    }

    private func radialProgress(
      position: CGPoint,
      center: CGPoint,
      radius: Double,
    ) -> Double {
      guard radius > 0.000_000_1 else {
        return 0
      }

      let deltaX = position.x - center.x
      let deltaY = position.y - center.y
      let distance = Double(hypot(deltaX, deltaY))
      return ShapePlacementSteering.clamp(distance / radius, min: 0, max: 1)
    }
  }

  static func evaluator(
    for field: PlacementModel.SteeringField?,
    canvasSize: CGSize,
    defaultValue: Double = 1,
  ) -> Evaluator? {
    guard let field else { return nil }

    return Evaluator(field: field, canvasSize: canvasSize, defaultValue: defaultValue)
  }

  static func value(
    for field: PlacementModel.SteeringField?,
    position: CGPoint,
    canvasSize: CGSize,
    defaultValue: Double = 1,
  ) -> Double {
    guard let evaluator = evaluator(for: field, canvasSize: canvasSize, defaultValue: defaultValue) else {
      return defaultValue
    }

    return evaluator.value(at: position)
  }

  static func maximumValue(
    for field: PlacementModel.SteeringField?,
    defaultValue: Double = 1,
  ) -> Double {
    guard let field else { return defaultValue }

    let lower = sanitize(field.values.lowerBound, fallback: defaultValue)
    let upper = sanitize(field.values.upperBound, fallback: defaultValue)
    let maximum = max(lower, upper)
    return sanitize(maximum, fallback: defaultValue)
  }

  private static func resolvedRadius(
    _ radius: PlacementModel.SteeringField.Radius,
    center: CGPoint,
    canvasSize: CGSize,
  ) -> Double {
    switch radius {
    case .autoFarthestCorner:
      return autoFarthestCornerRadius(center: center, canvasSize: canvasSize)
    case let .shortestSideFraction(fraction):
      let width = max(0, Double(canvasSize.width))
      let height = max(0, Double(canvasSize.height))
      let sanitizedFraction = sanitize(fraction, fallback: 0)
      guard sanitizedFraction > 0 else {
        return autoFarthestCornerRadius(center: center, canvasSize: canvasSize)
      }

      let resolved = sanitizedFraction * min(width, height)
      let sanitizedResolved = sanitize(resolved, fallback: 0)
      guard sanitizedResolved > 0 else {
        return autoFarthestCornerRadius(center: center, canvasSize: canvasSize)
      }

      return sanitizedResolved
    }
  }

  private static func autoFarthestCornerRadius(
    center: CGPoint,
    canvasSize: CGSize,
  ) -> Double {
    let width = max(0, Double(canvasSize.width))
    let height = max(0, Double(canvasSize.height))

    let corners = [
      CGPoint(x: 0, y: 0),
      CGPoint(x: CGFloat(width), y: 0),
      CGPoint(x: 0, y: CGFloat(height)),
      CGPoint(x: CGFloat(width), y: CGFloat(height)),
    ]

    var maximumDistance = 0.0
    for corner in corners {
      let deltaX = corner.x - center.x
      let deltaY = corner.y - center.y
      let distance = Double(hypot(deltaX, deltaY))
      maximumDistance = max(maximumDistance, distance)
    }
    return maximumDistance
  }

  private static func normalizedPosition(
    _ position: CGPoint,
    canvasSize: CGSize,
  ) -> PlacementModel.SteeringField.Point {
    let x = canvasSize.width > 0 ? Double(position.x / canvasSize.width) : 0
    let y = canvasSize.height > 0 ? Double(position.y / canvasSize.height) : 0
    return PlacementModel.SteeringField.Point(
      x: clamp(x, min: 0, max: 1),
      y: clamp(y, min: 0, max: 1),
    )
  }

  private static func normalizedFieldPoint(
    _ point: PlacementModel.SteeringField.Point,
  ) -> PlacementModel.SteeringField.Point {
    PlacementModel.SteeringField.Point(
      x: clamp(sanitize(point.x, fallback: 0), min: 0, max: 1),
      y: clamp(sanitize(point.y, fallback: 0), min: 0, max: 1),
    )
  }

  private static func pointFromNormalized(
    _ point: PlacementModel.SteeringField.Point,
    canvasSize: CGSize,
  ) -> CGPoint {
    let width = max(0, canvasSize.width)
    let height = max(0, canvasSize.height)
    return CGPoint(
      x: CGFloat(point.x) * width,
      y: CGFloat(point.y) * height,
    )
  }

  private static func easedProgress(
    _ progress: Double,
    easing: PlacementModel.SteeringField.Easing,
  ) -> Double {
    switch easing {
    case .linear:
      return progress
    case .smoothStep:
      return progress * progress * (3 - 2 * progress)
    case .easeIn:
      return progress * progress
    case .easeOut:
      return 1 - (1 - progress) * (1 - progress)
    case .easeInOut:
      if progress < 0.5 {
        return 4 * progress * progress * progress
      } else {
        let value = -2 * progress + 2
        return 1 - (value * value * value) / 2
      }
    }
  }

  private static func sanitize(_ value: Double, fallback: Double) -> Double {
    value.isFinite ? value : fallback
  }

  private static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
    Swift.max(minimum, Swift.min(maximum, value))
  }
}
