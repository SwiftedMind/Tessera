// By Dennis Müller

import SwiftUI

struct OptionTextField: View {
  @Binding var text: String
  var placeholder: LocalizedStringKey = ""
  var onCommit: () -> Void = {}

  var body: some View {
    TextField(placeholder, text: $text)
      .textFieldStyle(.plain)
      .padding(.small)
      .background(.background.secondary, in: .rect(cornerRadius: 10))
      .font(.title3.monospacedDigit().weight(.medium))
      .lineLimit(1)
      .minimumScaleFactor(0.6)
      .submitLabel(.done)
      .onSubmit(onCommit)
  }
}
