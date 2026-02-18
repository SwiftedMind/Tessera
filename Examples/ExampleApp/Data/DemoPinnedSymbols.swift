// By Dennis Müller

import SwiftUI
import Tessera

enum DemoPinnedSymbols {
  static var hero: [PinnedSymbol] {
    [
      PinnedSymbol(
        position: .centered(),
        collider: .shape(.circle(center: .zero, radius: 60)),
      ) {
        Image(systemName: "swift")
          .resizable()
          .scaledToFit()
          .foregroundStyle(.orange)
          .frame(width: 100, height: 100)
      },
      PinnedSymbol(
        position: .bottomTrailing(offset: CGSize(width: -120, height: -120)),
        collider: .shape(.circle(center: .zero, radius: 140)),
      ) {
        Text("Tessera")
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundStyle(.white.opacity(0.8))
      },
    ]
  }
}
