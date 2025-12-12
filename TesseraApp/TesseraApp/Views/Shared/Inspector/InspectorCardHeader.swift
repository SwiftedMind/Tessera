// By Dennis Müller

import SwiftUI

struct InspectorCardHeader: View {
  var title: LocalizedStringKey
  var groupIconName: String?
  var isExpanded: Bool
  var onToggleExpansion: () -> Void
  var customName: Binding<String?>
  var renameDialogTitle: LocalizedStringKey
  var renamePlaceholder: LocalizedStringKey
  var renamePopoverWidth: CGFloat
  var isVisible: Binding<Bool>
  var onRemove: () -> Void

  init(
    title: LocalizedStringKey,
    groupIconName: String?,
    isExpanded: Bool,
    onToggleExpansion: @escaping () -> Void,
    customName: Binding<String?>,
    renameDialogTitle: LocalizedStringKey,
    renamePlaceholder: LocalizedStringKey,
    renamePopoverWidth: CGFloat = 260,
    isVisible: Binding<Bool>,
    onRemove: @escaping () -> Void,
  ) {
    self.title = title
    self.groupIconName = groupIconName
    self.isExpanded = isExpanded
    self.onToggleExpansion = onToggleExpansion
    self.customName = customName
    self.renameDialogTitle = renameDialogTitle
    self.renamePlaceholder = renamePlaceholder
    self.renamePopoverWidth = renamePopoverWidth
    self.isVisible = isVisible
    self.onRemove = onRemove
  }

  var body: some View {
    Button {
      onToggleExpansion()
    } label: {
      HStack(alignment: .center, spacing: .medium) {
        Image(systemName: "chevron.right")
          .rotationEffect(.degrees(isExpanded ? 90 : 0))
          .foregroundStyle(.secondary)
          .animation(.default, value: isExpanded)
        if let groupIconName {
          Image(systemName: groupIconName)
            .foregroundStyle(.secondary)
        }
        HStack(spacing: .extraSmall) {
          Text(title)
            .font(.headline)
          RenamePopoverButton(
            customName: customName,
            dialogTitle: renameDialogTitle,
            placeholder: renamePlaceholder,
            popoverWidth: renamePopoverWidth,
          )
        }
        Spacer()
        Button {
          isVisible.wrappedValue.toggle()
        } label: {
          Image(systemName: isVisible.wrappedValue ? "eye" : "eye.slash")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        Button(role: .destructive, action: onRemove) {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
      }
      .padding(.mediumRelaxed)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
