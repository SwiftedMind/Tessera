// By Dennis Müller

import SwiftUI

/// Allows interactive editing of polygon collision shapes.
struct CollisionPolygonEditor: View {
  struct CanvasState: Equatable {
    var renderedContentSize: CGSize
    var zoomScale: CGFloat
    var itemLocalPoints: [CGPoint]
    var isPolygonClosed: Bool
  }

  private static var coordinateSpaceName: String { "collisionPolygonEditor" }
  private static var pointSelectionRadius: CGFloat { 18 }
  private static var closePolygonTapTolerance: CGFloat { 3 }
  private static var polygonHitTestStrokeWidth: CGFloat { 28 }
  private static var canvasHitTestPadding: CGFloat { 18 }

  var renderedContent: AnyView
  var canvasState: CanvasState

  @State private var dragInteraction: DragInteraction?
  @Environment(CollisionEditorState.self) private var editorState

  var body: some View {
    CollisionEditorCanvasView(
      renderedContent: renderedContent,
      renderedContentSize: canvasState.renderedContentSize,
      zoomScale: canvasState.zoomScale,
      hitTestPadding: Self.canvasHitTestPadding,
    ) {
      overlay
    }
    .coordinateSpace(name: Self.coordinateSpaceName)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpaceName))
        .onChanged { value in
          let startLocation = contentLocation(fromCanvasLocation: value.startLocation)
          let location = contentLocation(fromCanvasLocation: value.location)

          if dragInteraction == nil {
            if let draggedPointIndex = nearestPointIndex(to: startLocation) {
              dragInteraction = .point(index: draggedPointIndex)
            } else if shouldBeginPolygonDrag(at: startLocation) {
              dragInteraction = .polygon(startingItemLocalPoints: canvasState.itemLocalPoints)
            }
          }

          switch dragInteraction {
          case let .point(draggedPointIndex):
            editorState.movePoint(at: draggedPointIndex, to: location, using: itemLocalViewTransform)
          case let .polygon(startingItemLocalPoints):
            editorState.movePolygon(
              from: startingItemLocalPoints,
              by: value.translation,
              using: itemLocalViewTransform,
            )
          case .none:
            break
          }
        }
        .onEnded { value in
          defer { dragInteraction = nil }

          let startLocation = contentLocation(fromCanvasLocation: value.startLocation)
          let location = contentLocation(fromCanvasLocation: value.location)

          switch dragInteraction {
          case let .point(draggedPointIndex):
            let dragDistance = hypot(
              location.x - startLocation.x,
              location.y - startLocation.y,
            )
            if shouldClosePolygonAfterTap(onPointAt: draggedPointIndex, dragDistance: dragDistance) {
              editorState.closePolygon()
              return
            }

            editorState.movePoint(at: draggedPointIndex, to: location, using: itemLocalViewTransform)
            return
          case .polygon:
            return
          case .none:
            editorState.addPoint(at: location, using: itemLocalViewTransform)
            return
          }
        },
    )
  }

  private var itemLocalViewTransform: CollisionEditorViewTransform {
    CollisionEditorViewTransform(
      renderedContentSize: canvasState.renderedContentSize,
      zoomScale: canvasState.zoomScale,
    )
  }

  private var overlay: some View {
    ZStack {
      polygonPath
      pointHandles
    }
  }

  private var polygonPath: some View {
    Path { path in
      guard canvasState.itemLocalPoints.isEmpty == false else { return }

      let points = canvasState.itemLocalPoints.map(displayPoint(for:))
      path.move(to: points[0])
      for point in points.dropFirst() {
        path.addLine(to: point)
      }

      if canvasState.isPolygonClosed, points.count >= 3 {
        path.addLine(to: points[0])
      }
    }
    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    .overlay {
      if canvasState.isPolygonClosed, canvasState.itemLocalPoints.count >= 3 {
        Path { path in
          let points = canvasState.itemLocalPoints.map(displayPoint(for:))
          path.move(to: points[0])
          for point in points.dropFirst() {
            path.addLine(to: point)
          }
          path.addLine(to: points[0])
        }
        .fill(Color.accentColor.opacity(0.4))
      }
    }
  }

  private var pointHandles: some View {
    ForEach(canvasState.itemLocalPoints.indices, id: \.self) { index in
      let handleSize: CGFloat = 14

      Circle()
        .fill(index == canvasState.itemLocalPoints.startIndex ? Color.accentColor : Color.white)
        .overlay {
          Circle()
            .strokeBorder(.black.opacity(0.2), lineWidth: 1)
        }
        .frame(width: handleSize, height: handleSize)
        .position(displayPoint(for: canvasState.itemLocalPoints[index]))
        .allowsHitTesting(false)
    }
  }

  private func displayPoint(for itemLocalPoint: CGPoint) -> CGPoint {
    itemLocalViewTransform.viewPoint(fromItemLocalPoint: itemLocalPoint)
  }

  private func shouldBeginPolygonDrag(at location: CGPoint) -> Bool {
    guard canvasState.isPolygonClosed else { return false }
    guard canvasState.itemLocalPoints.count >= 3 else { return false }

    let polygonPath = polygonHitTestPath()
    return polygonPath.contains(location)
  }

  private func polygonHitTestPath() -> Path {
    let closedPolygonPath = polygonClosedPath()

    let strokedPath = closedPolygonPath.strokedPath(
      StrokeStyle(
        lineWidth: Self.polygonHitTestStrokeWidth,
        lineCap: .round,
        lineJoin: .round,
      ),
    )

    var hitTestPath = closedPolygonPath
    hitTestPath.addPath(strokedPath)
    return hitTestPath
  }

  private func polygonClosedPath() -> Path {
    Path { path in
      guard canvasState.itemLocalPoints.count >= 3 else { return }

      let points = canvasState.itemLocalPoints.map(displayPoint(for:))
      path.move(to: points[0])
      for point in points.dropFirst() {
        path.addLine(to: point)
      }
      path.closeSubpath()
    }
  }

  private func nearestPointIndex(to location: CGPoint) -> Int? {
    guard canvasState.itemLocalPoints.isEmpty == false else { return nil }

    var bestIndex: Int?
    var bestDistance = CGFloat.greatestFiniteMagnitude

    for index in canvasState.itemLocalPoints.indices {
      let pointLocation = displayPoint(for: canvasState.itemLocalPoints[index])
      let distance = hypot(location.x - pointLocation.x, location.y - pointLocation.y)

      if distance <= Self.pointSelectionRadius, distance < bestDistance {
        bestDistance = distance
        bestIndex = index
      }
    }

    return bestIndex
  }

  private func shouldClosePolygonAfterTap(onPointAt index: Int, dragDistance: CGFloat) -> Bool {
    guard canvasState.isPolygonClosed == false else { return false }
    guard canvasState.itemLocalPoints.count >= 3 else { return false }
    guard index == canvasState.itemLocalPoints.startIndex else { return false }

    return dragDistance <= Self.closePolygonTapTolerance
  }

  private func contentLocation(fromCanvasLocation canvasLocation: CGPoint) -> CGPoint {
    CGPoint(
      x: canvasLocation.x - Self.canvasHitTestPadding,
      y: canvasLocation.y - Self.canvasHitTestPadding,
    )
  }

  private enum DragInteraction {
    case point(index: Int)
    case polygon(startingItemLocalPoints: [CGPoint])
  }
}
