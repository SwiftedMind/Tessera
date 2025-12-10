// By Dennis Müller

import CompactSlider
import SwiftUI

private struct SliderCommitModifier: ViewModifier {
  @State private var isDragging = false
  var onCommit: () -> Void

  func body(content: Content) -> some View {
    content.compactSliderOnChange { configuration in
      let isCurrentlyDragging = configuration.focusState.isDragging
      if isDragging == isCurrentlyDragging { return }

      let wasDragging = isDragging
      Task {
        if wasDragging, isCurrentlyDragging == false {
          onCommit()
        }
        isDragging = isCurrentlyDragging
      }
    }
  }
}

extension View {
  func onSliderCommit(_ onCommit: @escaping () -> Void) -> some View {
    modifier(SliderCommitModifier(onCommit: onCommit))
  }
}
