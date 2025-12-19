// By Dennis Müller

import SwiftUI

extension CollisionShapeEditor {
  /// Displays a single collision editor output snippet with a copy action.
  struct OutputBlockView: View {
    var title: LocalizedStringKey
    var snippet: String
    var onCopy: () -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(title)
            .font(.headline)
          Spacer()
          Button("Copy") {
            onCopy()
          }
        }
        .padding(.horizontal, 12)

        ScrollView(.horizontal) {
          Text(snippet)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background {
          RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary.opacity(0.2))
        }
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(.secondary.opacity(0.3))
        }
      }
    }
  }
}
