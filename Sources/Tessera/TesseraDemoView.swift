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
      .circleOutline
    ]

    let demoTessera = Tessera(
      size: CGSize(width: 256, height: 256),
      items: demoItems,
      seed: 20,
      minimumSpacing: 50,
      fillProbability: 0.5,
      baseScaleRange: 0.9...1.05
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
