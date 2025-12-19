// By Dennis Müller

import SwiftUI

/// Renders the symbol preview with an overlay for editor interactions.
struct CollisionEditorCanvasView<Overlay: View>: View {
  var renderedContent: AnyView
  var renderedContentSize: CGSize
  var zoomScale: CGFloat
  var hitTestPadding: CGFloat
  @ViewBuilder var overlay: () -> Overlay

  init(
    renderedContent: AnyView,
    renderedContentSize: CGSize,
    zoomScale: CGFloat,
    hitTestPadding: CGFloat = 0,
    @ViewBuilder overlay: @escaping () -> Overlay = { EmptyView() },
  ) {
    self.renderedContent = renderedContent
    self.renderedContentSize = renderedContentSize
    self.zoomScale = zoomScale
    self.hitTestPadding = hitTestPadding
    self.overlay = overlay
  }

  var body: some View {
    let displaySize = CGSize(
      width: renderedContentSize.width * zoomScale,
      height: renderedContentSize.height * zoomScale,
    )

    ZStack {
      RenderedContentSnapshotView(
        renderedContent: renderedContent,
        renderedContentSize: renderedContentSize,
        zoomScale: zoomScale,
      )
      .frame(width: displaySize.width, height: displaySize.height)
      .allowsHitTesting(false)

      overlay()
    }
    .frame(width: displaySize.width, height: displaySize.height)
    .background {
      RoundedRectangle(cornerRadius: 18)
        .fill(.quaternary.opacity(0.35))
    }
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(.secondary.opacity(0.4))
    }
    .padding(hitTestPadding)
    .contentShape(Rectangle())
  }
}

/// Caches the rendered content as an image to stabilize redraws.
private struct RenderedContentSnapshotView: View {
  var renderedContent: AnyView
  var renderedContentSize: CGSize
  var zoomScale: CGFloat

  @Environment(\.displayScale) private var displayScale

  @State private var snapshotImage: Image?

  var body: some View {
    let displaySize = CGSize(
      width: renderedContentSize.width * zoomScale,
      height: renderedContentSize.height * zoomScale,
    )

    Group {
      if let snapshotImage {
        snapshotImage
      } else {
        renderedContent
          .frame(width: renderedContentSize.width, height: renderedContentSize.height)
          .scaleEffect(zoomScale)
          .drawingGroup()
      }
    }
    .frame(width: displaySize.width, height: displaySize.height)
    .task(id: snapshotTaskIdentifier) {
      snapshotImage = renderSnapshotImage(displaySize: displaySize)
    }
  }

  private var snapshotTaskIdentifier: String {
    "\(renderedContentSize.width)x\(renderedContentSize.height)-\(zoomScale)-\(displayScale)"
  }

  @MainActor
  private func renderSnapshotImage(displaySize: CGSize) -> Image? {
    let contentToRender = renderedContent
      .frame(width: renderedContentSize.width, height: renderedContentSize.height)
      .scaleEffect(zoomScale)
      .frame(width: displaySize.width, height: displaySize.height)

    let renderer = ImageRenderer(content: contentToRender)
    renderer.scale = displayScale

    #if os(macOS)
    guard let renderedImage = renderer.nsImage else { return nil }

    return Image(nsImage: renderedImage)
    #else
    guard let renderedImage = renderer.uiImage else { return nil }

    return Image(uiImage: renderedImage)
    #endif
  }
}
