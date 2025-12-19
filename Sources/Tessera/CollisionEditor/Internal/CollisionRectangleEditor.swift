// By Dennis Müller

import SwiftUI

/// Allows interactive editing of a rectangle collision shape.
struct CollisionRectangleEditor: View {
  var renderedContent: AnyView
  var canvasState: CollisionEditorCanvasState

  private static var coordinateSpaceName: String { "collisionRectangleEditor" }
  private static var handleSize: CGFloat { 12 }
  private static var handleHitRadius: CGFloat { 18 }
  private static var rectangleHitTolerance: CGFloat { 10 }
  private static var canvasHitTestPadding: CGFloat { 18 }

  @State private var dragInteraction: DragInteraction?
  @Environment(CollisionEditorState.self) private var editorState

  var body: some View {
    CollisionEditorCanvasView(
      renderedContent: renderedContent,
      renderedContentSize: canvasState.renderedContentSize,
      zoomScale: canvasState.zoomScale,
      hitTestPadding: Self.canvasHitTestPadding,
    ) {
      ZStack {
        rectangleOverlay
        handlesOverlay
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
            if let handle = resizeHandle(at: startLocation) {
              dragInteraction = .resize(
                startingCenter: editorState.rectangleCenter,
                startingSize: editorState.rectangleSize,
                handle: handle,
              )
            } else if isMovingStart(at: startLocation) {
              dragInteraction = .move(startingCenter: editorState.rectangleCenter)
            }
          }

          switch dragInteraction {
          case let .move(startingCenter):
            editorState.moveRectangle(
              from: startingCenter,
              by: value.translation,
              using: symbolLocalViewTransform,
            )
          case let .resize(startingCenter, startingSize, handle):
            editorState.resizeRectangle(
              from: startingCenter,
              startingSize: startingSize,
              handle: handle,
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

  private var symbolLocalViewTransform: CollisionEditorViewTransform {
    CollisionEditorViewTransform(
      renderedContentSize: canvasState.renderedContentSize,
      zoomScale: canvasState.zoomScale,
    )
  }

  private var rectangleOverlay: some View {
    let center = displayPoint(for: editorState.rectangleCenter)
    let size = displaySize(for: editorState.rectangleSize)

    return Rectangle()
      .fill(Color.accentColor.opacity(0.4))
      .overlay {
        Rectangle()
          .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
      }
      .frame(width: size.width, height: size.height)
      .position(center)
      .allowsHitTesting(false)
  }

  private var handlesOverlay: some View {
    let cornerPoints = cornerDisplayPoints()
    return ForEach(ResizeHandle.allCases) { handle in
      Circle()
        .fill(Color.white)
        .overlay {
          Circle()
            .strokeBorder(.black.opacity(0.2), lineWidth: 1)
        }
        .frame(width: Self.handleSize, height: Self.handleSize)
        .position(cornerPoints[handle] ?? .zero)
        .allowsHitTesting(false)
    }
  }

  private func displayPoint(for symbolLocalPoint: CGPoint) -> CGPoint {
    symbolLocalViewTransform.viewPoint(fromSymbolLocalPoint: symbolLocalPoint)
  }

  private func displaySize(for symbolLocalSize: CGSize) -> CGSize {
    symbolLocalViewTransform.viewSize(fromSymbolLocalSize: symbolLocalSize)
  }

  private func cornerDisplayPoints() -> [ResizeHandle: CGPoint] {
    let center = displayPoint(for: editorState.rectangleCenter)
    let size = displaySize(for: editorState.rectangleSize)

    let halfWidth = size.width / 2
    let halfHeight = size.height / 2

    return [
      .topLeading: CGPoint(x: center.x - halfWidth, y: center.y - halfHeight),
      .topTrailing: CGPoint(x: center.x + halfWidth, y: center.y - halfHeight),
      .bottomLeading: CGPoint(x: center.x - halfWidth, y: center.y + halfHeight),
      .bottomTrailing: CGPoint(x: center.x + halfWidth, y: center.y + halfHeight),
    ]
  }

  private func resizeHandle(at location: CGPoint) -> ResizeHandle? {
    let cornerPoints = cornerDisplayPoints()

    var bestHandle: ResizeHandle?
    var bestDistance = CGFloat.greatestFiniteMagnitude

    for handle in ResizeHandle.allCases {
      guard let corner = cornerPoints[handle] else { continue }

      let distance = hypot(location.x - corner.x, location.y - corner.y)
      if distance <= Self.handleHitRadius, distance < bestDistance {
        bestDistance = distance
        bestHandle = handle
      }
    }

    return bestHandle
  }

  private func isMovingStart(at location: CGPoint) -> Bool {
    let center = displayPoint(for: editorState.rectangleCenter)
    let size = displaySize(for: editorState.rectangleSize)

    let halfWidth = size.width / 2
    let halfHeight = size.height / 2

    let deltaX = abs(location.x - center.x)
    let deltaY = abs(location.y - center.y)

    return deltaX <= halfWidth + Self.rectangleHitTolerance && deltaY <= halfHeight + Self.rectangleHitTolerance
  }

  private func contentLocation(fromCanvasLocation canvasLocation: CGPoint) -> CGPoint {
    CGPoint(
      x: canvasLocation.x - Self.canvasHitTestPadding,
      y: canvasLocation.y - Self.canvasHitTestPadding,
    )
  }

  enum ResizeHandle: String, CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: String { rawValue }
  }

  private enum DragInteraction {
    case move(startingCenter: CGPoint)
    case resize(startingCenter: CGPoint, startingSize: CGSize, handle: ResizeHandle)
  }
}
