// By Dennis Müller

import Tessera
import SwiftUI

struct TesseraDemoView: View {
  var body: some View {
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
}

#Preview {
  TesseraDemoView()
    .preferredColorScheme(.dark)
}

extension TesseraItem {
  /// A lightly stroked square outline.
  static var squareOutline: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 34, height: 34)),
    ) {
      Rectangle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.8))
        .frame(width: 30, height: 30)
    }
  }

  /// A softly rounded rectangle outline.
  static var roundedOutline: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 34, height: 34)),
    ) {
      RoundedRectangle(cornerRadius: 6)
        .stroke(lineWidth: 4)
        .frame(width: 30, height: 30)
    }
  }

  /// A celebratory SF Symbol.
  static var partyPopper: TesseraItem {
    TesseraItem(
      allowedRotationRange: .degrees(-45)...(.degrees(45)),
      collisionShape: .circle(radius: 20),
    ) {
      Image(systemName: "party.popper.fill")
        .foregroundStyle(.red.opacity(0.5))
        .font(.largeTitle)
    }
  }

  /// A minus glyph.
  static var minus: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 36, height: 4)),
    ) {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// An equals glyph.
  static var equals: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(size: CGSize(width: 36, height: 12)),
    ) {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// A subtle circle outline.
  static var circleOutline: TesseraItem {
    TesseraItem(
      collisionShape: .circle(radius: 15),
    ) {
      Circle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.2))
        .frame(width: 30, height: 30)
    }
  }
}
