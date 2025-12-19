// By Dennis Müller

import SwiftUI

/// A collision editor for a tessera symbol.
///
/// Use this view to build and copy collision shapes that match the rendered symbol size.
public struct CollisionShapeEditor: View {
  @State private var editorState: CollisionEditorState

  public var symbol: TesseraSymbol
  public var initialCollisionShape: CollisionShape?
  var renderedContent: AnyView

  /// Creates a collision editor for a tessera symbol.
  ///
  /// - Parameters:
  ///   - symbol: The tessera symbol to render.
  ///   - initialCollisionShape: Optional shape to edit; defaults to a circle when `nil`.
  public init(_ symbol: TesseraSymbol, initialCollisionShape: CollisionShape? = nil) {
    self.symbol = symbol
    self.initialCollisionShape = initialCollisionShape
    renderedContent = AnyView(symbol.makeView())
    _editorState = State(initialValue: CollisionEditorState(initialCollisionShape: initialCollisionShape))
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        HeaderView(
          title: "Collision Editor",
        )
        VStack(spacing: 0) {
          PickerView()
          editorCanvas
          ControlsView()
        }
        Divider()
        OutputSectionView()
      }
      .padding(.vertical)
      .padding(.horizontal)
      .background {
        RenderedContentSizer(
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
      
      let canvasState = CanvasState(
        renderedContentSize: editorState.safeRenderedContentSize,
        zoomScale: zoomScale,
      )
      
      let polygonCanvasState = PolygonEditor.CanvasState(
        renderedContentSize: editorState.safeRenderedContentSize,
        zoomScale: zoomScale,
        symbolLocalPoints: editorState.polygonSymbolLocalPoints,
        isPolygonClosed: editorState.isPolygonClosed,
      )

      ZStack {
        if editorState.renderedContentSize == .zero {
          ProgressView()
        } else {
          switch editorState.selectedShapeKind {
          case .polygon:
            PolygonEditor(
              renderedContent: renderedContent,
              canvasState: polygonCanvasState,
            )
          case .circle:
            CircleEditor(
              renderedContent: renderedContent,
              canvasState: canvasState,
            )
          case .rectangle:
            RectangleEditor(
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
  CollisionShapeEditor(
    TesseraSymbol(
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
