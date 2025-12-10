// By Dennis Müller

import SwiftUI
import Tessera

struct PatternStage: View {
  var tessera: Tessera
  var repeatPattern: Bool

  var body: some View {
    ZStack {
      if repeatPattern {
        TesseraPattern(tessera, seed: tessera.seed)
          .transition(.opacity)
      } else {
        tessera
          .padding(.large)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
          .padding(.large)
          .transition(.opacity.combined(with: .scale(1.05)))
      }
    }
    .animation(.smooth(duration: 0.28), value: repeatPattern)
  }
}

#Preview {
  PatternStage(
    tessera: Tessera(
      size: CGSize(width: 256, height: 256),
      items: EditableItem.demoItems.map { $0.makeTesseraItem() },
      seed: 0,
      minimumSpacing: 10,
      density: 0.8,
      baseScaleRange: 0.5...1.2,
    ),
    repeatPattern: true,
  )
  .frame(width: 360, height: 360)
}
