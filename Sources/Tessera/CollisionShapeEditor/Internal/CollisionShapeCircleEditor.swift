// By Dennis Müller

import SwiftUI

extension CollisionShapeEditor {
  /// Allows interactive editing of a circle collision shape.
  struct CircleEditor: View {
    var renderedContent: AnyView
    var canvasState: CanvasState

    private static var coordinateSpaceName: String { "collisionCircleEditor" }
    private static var handleHitRadius: CGFloat { 18 }
    private static var circleHitTolerance: CGFloat { 14 }
    private static var handleSize: CGFloat { 12 }
    private static var canvasHitTestPadding: CGFloat { 18 }

    @State private var dragInteraction: DragInteraction?
    @Environment(CollisionEditorState.self) private var editorState

    var body: some View {
      CanvasView(
        renderedContent: renderedContent,
        renderedContentSize: canvasState.renderedContentSize,
        zoomScale: canvasState.zoomScale,
        hitTestPadding: Self.canvasHitTestPadding,
      ) {
        ZStack {
          circleOverlay
          handleOverlay
        }
      }
      .coordinateSpace(name: Self.coordinateSpaceName)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpaceName))
          .onChanged { value in
            let startLocation = contentLocation(fromCanvasLocation: value.startLocation)
            let location = contentLocation(fromCanvasLocation: value.location)

            if dragInteraction == nil {
              if isResizingStart(at: startLocation) {
                dragInteraction = .resize(
                  startingCenter: editorState.circleCenter,
                  startingRadius: editorState.circleRadius,
                )
              } else if isMovingStart(at: startLocation) {
                dragInteraction = .move(startingCenter: editorState.circleCenter)
              }
            }

            switch dragInteraction {
            case let .move(startingCenter):
              editorState.moveCircle(
                from: startingCenter,
                by: value.translation,
                using: symbolLocalViewTransform,
              )
            case let .resize(startingCenter, startingRadius):
              editorState.resizeCircle(
                from: startingCenter,
                startingRadius: startingRadius,
                to: location,
                using: symbolLocalViewTransform,
              )
            case .none:
              break
            }
          }
          .onEnded { _ in
            dragInteraction = nil
          },
      )
    }

    private var symbolLocalViewTransform: ViewTransform {
      ViewTransform(
        renderedContentSize: canvasState.renderedContentSize,
        zoomScale: canvasState.zoomScale,
      )
    }

    private var circleOverlay: some View {
      let center = displayPoint(for: editorState.circleCenter)
      let radius = displayRadius(for: editorState.circleRadius)

      return Circle()
        .fill(Color.accentColor.opacity(0.4))
        .overlay {
          Circle()
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: radius * 2, height: radius * 2)
        .position(center)
        .allowsHitTesting(false)
    }

    private var handleOverlay: some View {
      let center = displayPoint(for: editorState.circleCenter)
      let radius = displayRadius(for: editorState.circleRadius)
      let handlePoint = CGPoint(x: center.x + radius, y: center.y)

      return Circle()
        .fill(Color.white)
        .overlay {
          Circle()
            .strokeBorder(.black.opacity(0.2), lineWidth: 1)
        }
        .frame(width: Self.handleSize, height: Self.handleSize)
        .position(handlePoint)
        .allowsHitTesting(false)
    }

    private func displayPoint(for symbolLocalPoint: CGPoint) -> CGPoint {
      symbolLocalViewTransform.viewPoint(fromSymbolLocalPoint: symbolLocalPoint)
    }

    private func displayRadius(for symbolLocalRadius: CGFloat) -> CGFloat {
      symbolLocalViewTransform.viewRadius(fromSymbolLocalRadius: symbolLocalRadius)
    }

    private func isResizingStart(at location: CGPoint) -> Bool {
      let center = displayPoint(for: editorState.circleCenter)
      let radius = displayRadius(for: editorState.circleRadius)
      let handlePoint = CGPoint(x: center.x + radius, y: center.y)
      let distance = hypot(location.x - handlePoint.x, location.y - handlePoint.y)
      return distance <= Self.handleHitRadius
    }

    private func isMovingStart(at location: CGPoint) -> Bool {
      let center = displayPoint(for: editorState.circleCenter)
      let radius = displayRadius(for: editorState.circleRadius)
      let distance = hypot(location.x - center.x, location.y - center.y)
      return distance <= radius + Self.circleHitTolerance
    }

    private func contentLocation(fromCanvasLocation canvasLocation: CGPoint) -> CGPoint {
      CGPoint(
        x: canvasLocation.x - Self.canvasHitTestPadding,
        y: canvasLocation.y - Self.canvasHitTestPadding,
      )
    }

    private enum DragInteraction {
      case move(startingCenter: CGPoint)
      case resize(startingCenter: CGPoint, startingRadius: CGFloat)
    }
  }

}
