// By Dennis Müller

import SwiftUI

struct OptionRow<Content: View, Trailing: View>: View {
  var title: LocalizedStringKey?
  var subtitle: LocalizedStringKey?
  @ViewBuilder var trailing: () -> Trailing
  @ViewBuilder var content: () -> Content

  init(
    _ title: LocalizedStringKey? = nil,
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
    VStack(alignment: .leading, spacing: .small) {
      HStack(alignment: .firstTextBaseline, spacing: .small) {
        VStack(alignment: .leading, spacing: .extraSmall) {
          if let title {
            Text(title)
              .font(.subheadline)
              .fontWeight(.semibold)
          }
          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: Layout.Spacing.medium.value)
        trailing()
          .foregroundStyle(.secondary)
      }

      content()
    }
  }
}
