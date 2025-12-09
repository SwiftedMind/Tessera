// By Dennis Müller

import SwiftUI

/// A ready-to-run demonstration of Tessera.
public struct TesseraDemoView: View {
  public var body: some View {
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
    
    TesseraPattern(demoTessera)
      .ignoresSafeArea()
  }

  public init() {}
}

#Preview {
  TesseraDemoView()
    .preferredColorScheme(.dark)
}
