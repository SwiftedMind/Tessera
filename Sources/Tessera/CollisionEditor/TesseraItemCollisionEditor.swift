// By Dennis Müller

import SwiftUI

/// A collision editor for a tessera item.
///
/// Use this view to build and copy collision shapes that match the rendered item size.
public struct TesseraItemCollisionEditor: View {
  @State private var editorState: CollisionEditorState

  public var item: TesseraItem
  public var initialCollisionShape: CollisionShape?
  var renderedContent: AnyView

  /// Creates a collision editor for a tessera item.
  ///
  /// - Parameters:
  ///   - item: The tessera item to render.
  ///   - initialCollisionShape: Optional shape to edit; defaults to a circle when `nil`.
  public init(_ item: TesseraItem, initialCollisionShape: CollisionShape? = nil) {
    self.item = item
    self.initialCollisionShape = initialCollisionShape
    renderedContent = AnyView(item.makeView())
    _editorState = State(initialValue: CollisionEditorState(initialCollisionShape: initialCollisionShape))
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        CollisionEditorHeaderView(
          title: "Collision Editor",
        )
        VStack(spacing: 0) {
          CollisionEditorShapePickerView()
          editorCanvas
          CollisionEditorShapeControlsView()
        }
        Divider()
        CollisionEditorOutputSectionView()
      }
      .padding(.vertical)
      .padding(.horizontal)
      .background {
        CollisionEditorRenderedContentSizer(
          renderedContent: renderedContent,
        )
      }
    }
    .onChange(of: initialCollisionShape) { _, _ in
      editorState.initialCollisionShape = initialCollisionShape
    }
    .environment(editorState)
  }

  @ViewBuilder
  private var editorCanvas: some View {
    GeometryReader { proxy in
      let availableSize = proxy.size
      let zoomScale = preferredZoomScale(
        for: editorState.safeRenderedContentSize,
        availableSize: availableSize,
      )
      
      let canvasState = CollisionEditorCanvasState(
        renderedContentSize: editorState.safeRenderedContentSize,
        zoomScale: zoomScale,
      )
      
      let polygonCanvasState = CollisionPolygonEditor.CanvasState(
        renderedContentSize: editorState.safeRenderedContentSize,
        zoomScale: zoomScale,
        itemLocalPoints: editorState.polygonItemLocalPoints,
        isPolygonClosed: editorState.isPolygonClosed,
      )

      ZStack {
        if editorState.renderedContentSize == .zero {
          ProgressView()
        } else {
          switch editorState.selectedShapeKind {
          case .polygon:
            CollisionPolygonEditor(
              renderedContent: renderedContent,
              canvasState: polygonCanvasState,
            )
          case .circle:
            CollisionCircleEditor(
              renderedContent: renderedContent,
              canvasState: canvasState,
            )
          case .rectangle:
            CollisionRectangleEditor(
              renderedContent: renderedContent,
              canvasState: canvasState,
            )
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minHeight: 320)
  }

  private func preferredZoomScale(for renderedContentSize: CGSize, availableSize: CGSize) -> CGFloat {
    let maximumDimension = max(renderedContentSize.width, renderedContentSize.height, 1)
    let availableDimension = max(min(availableSize.width, availableSize.height) - 32, 1)
    let zoomScale = availableDimension / maximumDimension
    return min(max(zoomScale, 0.1), 10)
  }
}

#Preview {
  TesseraItemCollisionEditor(
    TesseraItem(
      collisionShape: .circle(center: .zero, radius: 18),
    ) {
      Image(systemName: "sparkles")
        .font(.system(size: 60, weight: .semibold))
        .foregroundStyle(.primary)
    },
    initialCollisionShape: .anchoredPolygon(
      points: [
        CGPoint(x: 10, y: 8),
        CGPoint(x: 54, y: 4),
        CGPoint(x: 68, y: 26),
        CGPoint(x: 36, y: 64),
        CGPoint(x: 0, y: 28),
      ],
      anchor: .topLeading,
      size: CGSize(width: 72, height: 72),
    ),
  )
  .preferredColorScheme(.dark)
}
