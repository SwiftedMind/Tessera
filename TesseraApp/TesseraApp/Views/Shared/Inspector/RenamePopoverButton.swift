// By Dennis Müller

import SwiftUI

struct RenamePopoverButton: View {
  @Binding var customName: String?
  var dialogTitle: LocalizedStringKey
  var placeholder: LocalizedStringKey
  var popoverWidth: CGFloat
  @State private var nameDraft: String
  @State private var isRenaming: Bool

  init(
    customName: Binding<String?>,
    dialogTitle: LocalizedStringKey,
    placeholder: LocalizedStringKey,
    popoverWidth: CGFloat = 260,
  ) {
    _customName = customName
    self.dialogTitle = dialogTitle
    self.placeholder = placeholder
    self.popoverWidth = popoverWidth
    _nameDraft = State(initialValue: customName.wrappedValue ?? "")
    _isRenaming = State(initialValue: false)
  }

  var body: some View {
    Button {
      beginRenaming()
    } label: {
      Image(systemName: "pencil")
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $isRenaming) {
      VStack(alignment: .leading, spacing: .medium) {
        Text(dialogTitle)
          .font(.headline)
        OptionTextField(text: $nameDraft, placeholder: placeholder)
          .onSubmit(commitNameChange)
        HStack {
          Spacer()
          Button("Cancel") {
            isRenaming = false
          }
          Button("Save") {
            commitNameChange()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.return)
        }
      }
      .padding(.mediumRelaxed)
      .frame(width: popoverWidth)
    }
  }

  private func beginRenaming() {
    nameDraft = customName ?? ""
    isRenaming = true
  }

  private func commitNameChange() {
    let trimmedName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    customName = trimmedName.isEmpty ? nil : trimmedName
    isRenaming = false
  }
}
