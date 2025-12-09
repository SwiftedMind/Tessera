// By Dennis Müller

import SwiftUI
import Tessera

struct ContentView: View {
  var body: some View {
    Button("Render") {
      let demoItems: [TesseraItem] = [
        .squareOutline,
        .roundedOutline,
        .partyPopper,
        .minus,
        .equals,
        .circleOutline,
      ]

      let demoTessera = Tessera(
        size: CGSize(width: 256, height: 256),
        items: demoItems,
        seed: 0,
        minimumSpacing: 10,
        density: 0.8,
        baseScaleRange: 0.5...1.2,
      )

      let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

      try! demoTessera
        .renderPNG(
          to: downloadsFolder,
          fileName: "tessera",
          options: TesseraRenderOptions(
            targetPixelSize: CGSize(width: 2000, height: 2000),
            isOpaque: false,
            colorMode: .extendedLinear,
          ),
        )

      try! demoTessera
        .renderPDF(to: downloadsFolder)
    }
  }
}

#Preview {
  ContentView()
}
