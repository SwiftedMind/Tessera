// By Dennis Müller

import SwiftUI

struct OptionSection<Content: View>: View {
  var title: LocalizedStringKey?
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: .large) {
      if let title {
        Text(title)
          .font(.headline)
      }

      content()
    }
    .padding(.large)
    .background(
      .quaternary.opacity(0.12),
      in: RoundedRectangle(cornerRadius: 14, style: .continuous),
    )
  }
}
