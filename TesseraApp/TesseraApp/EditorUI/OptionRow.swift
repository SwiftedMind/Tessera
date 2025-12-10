// By Dennis Müller

import SwiftUI

struct OptionRow<Content: View, Trailing: View>: View {
  var title: LocalizedStringKey
  var subtitle: LocalizedStringKey?
  @ViewBuilder var trailing: () -> Trailing
  @ViewBuilder var content: () -> Content

  init(
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey? = nil,
    @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
    @ViewBuilder content: @escaping () -> Content,
  ) {
    self.title = title
    self.subtitle = subtitle
    self.trailing = trailing
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.subheadline.weight(.semibold))
          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 12)
        trailing()
      }

      content()
    }
  }
}
