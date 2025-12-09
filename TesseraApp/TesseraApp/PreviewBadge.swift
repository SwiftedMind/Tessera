// By Dennis Müller

import SwiftUI

struct PreviewBadge: View {
  var item: EditableItem

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(.quaternary.opacity(0.4))
        .frame(width: 84, height: 84)
      item.preset.preview
        .frame(width: 64, height: 64)
    }
  }
}

#Preview {
  PreviewBadge(item: EditableItem.demoItems[0])
    .padding()
}
