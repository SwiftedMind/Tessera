// By Dennis Müller

import SwiftUI

struct CollisionOverlayShape: Sendable {
  var fillPolygons: [CollisionPolygon]
  var outlinePointSets: [[CGPoint]]

  init(collisionShape: CollisionShape) {
    fillPolygons = CollisionMath.polygons(for: collisionShape)
    outlinePointSets = CollisionMath.polygonPointSets(for: collisionShape)
  }
}

enum CollisionOverlayRenderer {
  static let fillColor: Color = .blue.opacity(0.2)
  static let strokeColor: Color = .blue.opacity(0.9)
  static let strokeStyle = StrokeStyle(lineWidth: 2)

  static func draw(
    overlayShape: CollisionOverlayShape,
    in context: inout GraphicsContext,
  ) {
    for polygon in overlayShape.fillPolygons {
      let path = polygonPath(for: polygon.points)
      context.fill(path, with: .color(fillColor))
    }

    for pointSet in overlayShape.outlinePointSets {
      let path = polygonPath(for: pointSet)
      context.stroke(path, with: .color(strokeColor), style: strokeStyle)
    }
  }

  private static func polygonPath(for points: [CGPoint]) -> Path {
    var path = Path()
    guard let firstPoint = points.first else { return path }

    path.move(to: firstPoint)
    for point in points.dropFirst() {
      path.addLine(to: point)
    }
    path.closeSubpath()
    return path
  }
}
