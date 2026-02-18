// By Dennis Müller

import SwiftUI

/// Applies the shared navigation chrome for all demo destination screens.
struct DemoExampleScreen<Content: View>: View {
  let title: String
  let ignoresSafeArea: Bool
  private let content: Content

  init(
    title: String,
    ignoresSafeArea: Bool = true,
    @ViewBuilder content: () -> Content,
  ) {
    self.title = title
    self.ignoresSafeArea = ignoresSafeArea
    self.content = content()
  }

  var body: some View {
    Group {
      if ignoresSafeArea {
        content.ignoresSafeArea()
      } else {
        content
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
