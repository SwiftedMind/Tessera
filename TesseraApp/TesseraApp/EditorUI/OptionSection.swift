// By Dennis Müller

import SwiftUI

struct OptionSection<Content: View>: View {
  var title: LocalizedStringKey?
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let title {
        Text(title)
          .font(.headline)
      }

      content()
    }
    .padding(16)
    .background(
      .quaternary.opacity(0.12),
      in: RoundedRectangle(cornerRadius: 14, style: .continuous),
    )
  }
}
