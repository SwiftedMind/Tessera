// By Dennis Müller

import SwiftUI
import Tessera

enum DemoPinnedSymbols {
  static var hero: [PinnedSymbol] {
    [
      PinnedSymbol(
        position: .centered(),
        collider: .shape(.circle(center: .zero, radius: 62)),
      ) {
        ZStack {
          Circle()
            .stroke(DemoPalette.strokePrimary.opacity(0.9), lineWidth: 5)
            .frame(width: 108, height: 108)

          Circle()
            .fill(DemoPalette.teal.opacity(0.28))
            .frame(width: 56, height: 56)
        }
      },
      PinnedSymbol(
        position: .bottomTrailing(offset: CGSize(width: -110, height: -110)),
        collider: .shape(.rectangle(center: .zero, size: CGSize(width: 164, height: 64))),
      ) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(DemoPalette.strokeMuted.opacity(0.95), lineWidth: 3)
          .frame(width: 156, height: 56)
      },
    ]
  }
}
