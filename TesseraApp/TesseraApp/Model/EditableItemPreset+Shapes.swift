// By Dennis Müller

import SwiftUI
import Tessera

extension EditableItem.PresetGroup {
  static var shapes: EditableItem.PresetGroup {
    EditableItem.PresetGroup(
      id: "shapes",
      title: "Shapes",
      iconName: "square.on.circle",
      presets: [
        .squareOutline,
        .roundedOutline,
        .circleOutline,
        .dotFill,
        .hexagonFill,
        .diamondFill,
        .chevronStroke,
        .arcStroke,
        .spiralStroke,
        .crossFill,
        .wavyLine,
        .zigZagLine,
        .starBurst,
        .triangleDots,
        .circleDots,
      ],
    )
  }
}

extension EditableItem.Preset {
  static var squareOutline: EditableItem.Preset {
    EditableItem.Preset(
      id: "squareOutline",
      title: "Square Outline",
      iconName: "square.dashed",
      defaultStyle: ItemStyle(
        size: CGSize(width: 30, height: 30),
        color: .gray.opacity(0.8),
        lineWidth: 4,
        fontSize: 32,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          Rectangle()
            .stroke(lineWidth: style.lineWidth)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var roundedOutline: EditableItem.Preset {
    EditableItem.Preset(
      id: "roundedOutline",
      title: "Rounded Outline",
      iconName: "app",
      defaultStyle: ItemStyle(
        size: CGSize(width: 30, height: 30),
        color: .primary,
        lineWidth: 4,
        fontSize: 32,
      ),
      defaultSpecificOptions: .roundedRectangle(cornerRadius: 6),
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: true,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, options in
        AnyView(
          RoundedRectangle(cornerRadius: EditableItemPresetHelpers.cornerRadius(from: options, fallback: 6))
            .stroke(lineWidth: style.lineWidth)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var circleOutline: EditableItem.Preset {
    EditableItem.Preset(
      id: "circleOutline",
      title: "Circle Outline",
      iconName: "circle",
      defaultStyle: ItemStyle(
        size: CGSize(width: 26, height: 26),
        color: .gray.opacity(0.2),
        lineWidth: 4,
        fontSize: 32,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          Circle()
            .stroke(lineWidth: style.lineWidth)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .circle(radius: EditableItemPresetHelpers.circleRadius(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var dotFill: EditableItem.Preset {
    EditableItem.Preset(
      id: "dotFill",
      title: "Dot",
      iconName: "circle.fill",
      defaultStyle: ItemStyle(
        size: CGSize(width: 12, height: 12),
        color: .primary,
        lineWidth: 1,
        fontSize: 20,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          Circle()
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .circle(radius: EditableItemPresetHelpers.circleRadius(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var hexagonFill: EditableItem.Preset {
    EditableItem.Preset(
      id: "hexagonFill",
      title: "Hexagon",
      iconName: "hexagon.fill",
      defaultStyle: ItemStyle(
        size: CGSize(width: 30, height: 30),
        color: .teal.opacity(0.8),
        lineWidth: 1,
        fontSize: 24,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          RegularPolygonShape(sideCount: 6)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var chevronStroke: EditableItem.Preset {
    EditableItem.Preset(
      id: "chevronStroke",
      title: "Chevron",
      iconName: "chevron.left.forwardslash.chevron.right",
      defaultStyle: ItemStyle(
        size: CGSize(width: 34, height: 22),
        color: .indigo.opacity(0.9),
        lineWidth: 3,
        fontSize: 22,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          ChevronShape()
            .stroke(style.color, lineWidth: style.lineWidth)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var arcStroke: EditableItem.Preset {
    EditableItem.Preset(
      id: "arcStroke",
      title: "Arc",
      iconName: "moonphase.first.quarter",
      defaultStyle: ItemStyle(
        size: CGSize(width: 34, height: 22),
        color: .mint.opacity(0.9),
        lineWidth: 3,
        fontSize: 22,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          ArcShape()
            .stroke(style.color, lineWidth: style.lineWidth)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .circle(radius: EditableItemPresetHelpers.circleRadius(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var spiralStroke: EditableItem.Preset {
    EditableItem.Preset(
      id: "spiralStroke",
      title: "Spiral",
      iconName: "tornado",
      defaultStyle: ItemStyle(
        size: CGSize(width: 32, height: 32),
        color: .pink.opacity(0.9),
        lineWidth: 2.5,
        fontSize: 22,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          SpiralShape(turns: 2.2, pointCount: 140)
            .stroke(style.color, lineWidth: style.lineWidth)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var crossFill: EditableItem.Preset {
    EditableItem.Preset(
      id: "crossFill",
      title: "Cross",
      iconName: "xmark",
      defaultStyle: ItemStyle(
        size: CGSize(width: 30, height: 30),
        color: .gray.opacity(0.9),
        lineWidth: 2,
        fontSize: 22,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          CrossShape()
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var wavyLine: EditableItem.Preset {
    EditableItem.Preset(
      id: "wavyLine",
      title: "Wavy Line",
      iconName: "squiggly",
      defaultStyle: ItemStyle(
        size: CGSize(width: 52, height: 20),
        color: .blue.opacity(0.7),
        lineWidth: 3,
        fontSize: 30,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          WavyLineShape(amplitude: style.size.height / 3, waveCount: 3)
            .stroke(style.color, lineWidth: style.lineWidth)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var zigZagLine: EditableItem.Preset {
    EditableItem.Preset(
      id: "zigZagLine",
      title: "Zigzag Line",
      iconName: "chart.line.uptrend.xyaxis",
      defaultStyle: ItemStyle(
        size: CGSize(width: 44, height: 22),
        color: .orange.opacity(0.9),
        lineWidth: 3,
        fontSize: 30,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: true,
        usesFillStyle: false,
        supportsLineWidth: true,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          ZigZagLineShape(segmentCount: 7)
            .stroke(style.color, lineWidth: style.lineWidth)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var starBurst: EditableItem.Preset {
    EditableItem.Preset(
      id: "starBurst",
      title: "Star Burst",
      iconName: "star.circle.fill",
      defaultStyle: ItemStyle(
        size: CGSize(width: 34, height: 34),
        color: .yellow.opacity(0.85),
        lineWidth: 1,
        fontSize: 30,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          StarShape(points: 7, innerRadiusRatio: 0.48)
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .circle(radius: EditableItemPresetHelpers.circleRadius(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var diamondFill: EditableItem.Preset {
    EditableItem.Preset(
      id: "diamondFill",
      title: "Diamond",
      iconName: "rhombus.fill",
      defaultStyle: ItemStyle(
        size: CGSize(width: 30, height: 30),
        color: .purple.opacity(0.75),
        lineWidth: 1,
        fontSize: 30,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          DiamondShape()
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var triangleDots: EditableItem.Preset {
    EditableItem.Preset(
      id: "triangleDots",
      title: "Triangle Dots",
      iconName: "ellipsis.circle.fill",
      defaultStyle: ItemStyle(
        size: CGSize(width: 26, height: 24),
        color: .purple.opacity(0.85),
        lineWidth: 1,
        fontSize: 18,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          TriangleDotsShape()
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }

  static var circleDots: EditableItem.Preset {
    EditableItem.Preset(
      id: "circleDots",
      title: "Orbit Dots",
      iconName: "record.circle.fill",
      defaultStyle: ItemStyle(
        size: CGSize(width: 28, height: 28),
        color: .orange.opacity(0.9),
        lineWidth: 1,
        fontSize: 18,
      ),
      defaultSpecificOptions: .none,
      capabilities: EditableItem.PresetCapabilities(
        usesStrokeStyle: false,
        usesFillStyle: true,
        supportsLineWidth: false,
        supportsFontSize: false,
        supportsCornerRadius: false,
        supportsSymbolSelection: false,
        supportsTextContent: false,
      ),
      render: { style, _ in
        AnyView(
          OrbitDotsShape()
            .foregroundStyle(style.color)
            .frame(width: style.size.width, height: style.size.height),
        )
      },
      collisionShape: { style, _ in
        .rectangle(size: EditableItemPresetHelpers.rectangleCollisionSize(for: style))
      },
      measuredSize: { style, _ in
        style.size
      },
    )
  }
}

// MARK: - Custom Shapes

private struct RegularPolygonShape: Shape {
  var sideCount: Int

  func path(in rect: CGRect) -> Path {
    let clampedSideCount = max(sideCount, 3)
    let angleIncrement = 2 * CGFloat.pi / CGFloat(clampedSideCount)
    let radius = min(rect.width, rect.height) / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)

    var path = Path()
    for index in 0..<clampedSideCount {
      let angle = angleIncrement * CGFloat(index) - .pi / 2
      let point = CGPoint(
        x: center.x + radius * cos(angle),
        y: center.y + radius * sin(angle),
      )
      if index == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }

    path.closeSubpath()
    return path
  }
}

private struct ChevronShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    return path
  }
}

private struct ArcShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    path.addArc(
      center: center,
      radius: radius,
      startAngle: .degrees(200),
      endAngle: .degrees(-20),
      clockwise: true,
    )
    return path
  }
}

private struct SpiralShape: Shape {
  var turns: Double
  var pointCount: Int

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let clampedPointCount = max(pointCount, 10)
    let maxRadius = min(rect.width, rect.height) / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)

    for index in 0..<clampedPointCount {
      let progress = Double(index) / Double(clampedPointCount - 1)
      let angle = progress * turns * 2 * Double.pi - Double.pi / 2
      let radius = Double(maxRadius) * progress
      let point = CGPoint(
        x: center.x + CGFloat(radius * cos(angle)),
        y: center.y + CGFloat(radius * sin(angle)),
      )

      if index == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }

    return path
  }
}

private struct CrossShape: Shape {
  func path(in rect: CGRect) -> Path {
    let thickness = min(rect.width, rect.height) / 3
    let verticalRect = CGRect(
      x: rect.midX - thickness / 2,
      y: rect.minY,
      width: thickness,
      height: rect.height,
    )
    let horizontalRect = CGRect(
      x: rect.minX,
      y: rect.midY - thickness / 2,
      width: rect.width,
      height: thickness,
    )

    var path = Path(verticalRect)
    path.addPath(Path(horizontalRect))
    return path
  }
}

private struct SerpentineCurveShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let midY = rect.midY
    let quarterX = rect.width / 4

    path.move(to: CGPoint(x: rect.minX, y: midY))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: midY),
      control1: CGPoint(x: quarterX, y: rect.minY),
      control2: CGPoint(x: quarterX, y: rect.maxY),
    )
    path.addCurve(
      to: CGPoint(x: rect.maxX, y: midY),
      control1: CGPoint(x: rect.width - quarterX, y: rect.minY),
      control2: CGPoint(x: rect.width - quarterX, y: rect.maxY),
    )

    return path
  }
}

private struct TriangleDotsShape: Shape {
  func path(in rect: CGRect) -> Path {
    let radius = min(rect.width, rect.height) / 6
    let top = CGPoint(x: rect.midX, y: rect.minY + radius * 1.5)
    let bottomLeft = CGPoint(x: rect.minX + radius * 1.5, y: rect.maxY - radius * 1.2)
    let bottomRight = CGPoint(x: rect.maxX - radius * 1.5, y: rect.maxY - radius * 1.2)

    var path = Path()
    for point in [top, bottomLeft, bottomRight] {
      let circle = CGRect(
        x: point.x - radius,
        y: point.y - radius,
        width: radius * 2,
        height: radius * 2,
      )
      path.addEllipse(in: circle)
    }

    return path
  }
}

private struct OrbitDotsShape: Shape {
  func path(in rect: CGRect) -> Path {
    let radius = min(rect.width, rect.height) / 6
    let orbitRadius = min(rect.width, rect.height) / 2.5
    let center = CGPoint(x: rect.midX, y: rect.midY)

    var path = Path()
    for index in 0..<3 {
      let angle = 2 * CGFloat.pi * CGFloat(index) / 3 - .pi / 2
      let orbitPoint = CGPoint(
        x: center.x + orbitRadius * cos(angle),
        y: center.y + orbitRadius * sin(angle),
      )
      let circleRect = CGRect(
        x: orbitPoint.x - radius,
        y: orbitPoint.y - radius,
        width: radius * 2,
        height: radius * 2,
      )
      path.addEllipse(in: circleRect)
    }

    return path
  }
}

private struct WavyLineShape: Shape {
  var amplitude: CGFloat
  var waveCount: Int

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let midY = rect.midY
    let wavelength = rect.width / CGFloat(max(waveCount, 1))

    path.move(to: CGPoint(x: rect.minX, y: midY))

    for index in 0..<waveCount {
      let startX = CGFloat(index) * wavelength
      let controlX = startX + wavelength / 2
      let endX = startX + wavelength
      let controlY = index.isMultiple(of: 2) ? midY - amplitude : midY + amplitude

      path.addQuadCurve(
        to: CGPoint(x: endX, y: midY),
        control: CGPoint(x: controlX, y: controlY),
      )
    }

    return path
  }
}

private struct ZigZagLineShape: Shape {
  var segmentCount: Int

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let stepX = rect.width / CGFloat(max(segmentCount - 1, 1))
    let minY = rect.minY
    let maxY = rect.maxY

    path.move(to: CGPoint(x: rect.minX, y: minY))

    for index in 1..<segmentCount {
      let xPosition = CGFloat(index) * stepX
      let yPosition = index.isMultiple(of: 2) ? maxY : minY
      path.addLine(to: CGPoint(x: xPosition, y: yPosition))
    }

    return path
  }
}

private struct StarShape: Shape {
  var points: Int
  var innerRadiusRatio: CGFloat

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let outerRadius = min(rect.width, rect.height) / 2
    let innerRadius = outerRadius * innerRadiusRatio
    let totalPoints = max(points, 3) * 2
    let angleIncrement = .pi * 2 / CGFloat(totalPoints)

    var path = Path()

    for index in 0..<totalPoints {
      let isOuter = index.isMultiple(of: 2)
      let radius = isOuter ? outerRadius : innerRadius
      let angle = CGFloat(index) * angleIncrement - .pi / 2

      let point = CGPoint(
        x: center.x + radius * cos(angle),
        y: center.y + radius * sin(angle),
      )

      if index == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }

    path.closeSubpath()
    return path
  }
}

private struct DiamondShape: Shape {
  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)

    var path = Path()
    path.move(to: CGPoint(x: center.x, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
    path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: center.y))
    path.closeSubpath()

    return path
  }
}
