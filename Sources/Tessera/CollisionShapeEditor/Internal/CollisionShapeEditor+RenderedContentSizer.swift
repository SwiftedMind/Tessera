// By Dennis Müller

import SwiftUI

extension CollisionShapeEditor {
  /// Measures the rendered content so editor overlays can match its size.
  struct RenderedContentSizer: View {
    var renderedContent: AnyView

    @Environment(\.displayScale) private var displayScale
    @Environment(CollisionEditorState.self) private var editorState

    @State private var hasMeasuredSize: Bool = false

    var body: some View {
      Color.clear
        .task(id: displayScale) {
          await updateSizeIfNeeded()
        }
    }

    @MainActor
    private func updateSizeIfNeeded() async {
      guard hasMeasuredSize == false || editorState.renderedContentSize == .zero else { return }

      let measuredSize = measureRenderedContentSize()
      guard measuredSize != .zero else { return }

      editorState.renderedContentSize = measuredSize
      hasMeasuredSize = true
    }

    @MainActor
    private func measureRenderedContentSize() -> CGSize {
      let contentToRender = renderedContent.fixedSize()

      let renderer = ImageRenderer(content: contentToRender)
      renderer.scale = displayScale

      guard let renderedImage = renderer.cgImage else { return .zero }

      return CGSize(
        width: CGFloat(renderedImage.width) / displayScale,
        height: CGFloat(renderedImage.height) / displayScale,
      )
    }
  }
}
