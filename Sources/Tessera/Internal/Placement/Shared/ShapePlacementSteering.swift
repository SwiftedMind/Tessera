// By Dennis Müller

import CoreGraphics

/// Evaluates value-based steering fields in normalized tile space.
enum ShapePlacementSteering {
  static func value(
    for field: TesseraPlacement.SteeringField?,
    position: CGPoint,
    canvasSize: CGSize,
    defaultValue: Double = 1,
  ) -> Double {
    guard let field else { return defaultValue }

    let normalizedPoint = normalizedPosition(position, canvasSize: canvasSize)
    let from = normalizedFieldPoint(field.from)
    let to = normalizedFieldPoint(field.to)
    let axisX = to.x - from.x
    let axisY = to.y - from.y
    let axisLengthSquared = axisX * axisX + axisY * axisY

    let progress: Double
    if axisLengthSquared > 0.000_000_1 {
      let pointOffsetX = normalizedPoint.x - from.x
      let pointOffsetY = normalizedPoint.y - from.y
      let projected = (pointOffsetX * axisX + pointOffsetY * axisY) / axisLengthSquared
      progress = clamp(projected, min: 0, max: 1)
    } else {
      progress = 0
    }

    let eased = easedProgress(progress, easing: field.easing)
    let lower = sanitize(field.values.lowerBound, fallback: defaultValue)
    let upper = sanitize(field.values.upperBound, fallback: defaultValue)
    let interpolated = lower + (upper - lower) * eased
    return sanitize(interpolated, fallback: defaultValue)
  }

  static func maximumValue(
    for field: TesseraPlacement.SteeringField?,
    defaultValue: Double = 1,
  ) -> Double {
    guard let field else { return defaultValue }

    let lower = sanitize(field.values.lowerBound, fallback: defaultValue)
    let upper = sanitize(field.values.upperBound, fallback: defaultValue)
    let maximum = max(lower, upper)
    return sanitize(maximum, fallback: defaultValue)
  }

  private static func normalizedPosition(
    _ position: CGPoint,
    canvasSize: CGSize,
  ) -> TesseraPlacement.SteeringField.Point {
    let x = canvasSize.width > 0 ? Double(position.x / canvasSize.width) : 0
    let y = canvasSize.height > 0 ? Double(position.y / canvasSize.height) : 0
    return TesseraPlacement.SteeringField.Point(
      x: clamp(x, min: 0, max: 1),
      y: clamp(y, min: 0, max: 1),
    )
  }

  private static func normalizedFieldPoint(
    _ point: TesseraPlacement.SteeringField.Point,
  ) -> TesseraPlacement.SteeringField.Point {
    TesseraPlacement.SteeringField.Point(
      x: clamp(sanitize(point.x, fallback: 0), min: 0, max: 1),
      y: clamp(sanitize(point.y, fallback: 0), min: 0, max: 1),
    )
  }

  private static func easedProgress(
    _ progress: Double,
    easing: TesseraPlacement.SteeringField.Easing,
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
