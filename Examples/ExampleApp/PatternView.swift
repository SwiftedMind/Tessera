// By Dennis Müller

import SwiftUI
import Tessera

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

    let demoConfiguration = TesseraConfiguration(
      items: demoItems,
      seed: 0,
      minimumSpacing: 10,
      density: 0.8,
      baseScaleRange: 0.5...1.2,
    )

    TabView {
      TesseraTiledCanvas(
        demoConfiguration,
        tileSize: CGSize(width: 256, height: 256),
      )
      .ignoresSafeArea()
      .tabItem {
        Label("Tiled Canvas", systemImage: "square.grid.3x3.fill")
      }

      TesseraCanvas(
        demoConfiguration,
        fixedItems: [
          TesseraFixedItem(
            position: .centered(),
            collisionShape: .circle(center: .zero, radius: 60),
          ) {
            Image(systemName: "swift")
              .resizable()
              .scaledToFit()
              .foregroundStyle(.orange)
              .frame(width: 100, height: 100)
          },
          TesseraFixedItem(
            position: .bottomTrailing(offset: CGSize(width: -120, height: -120)),
            collisionShape: .circle(center: .zero, radius: 140),
          ) {
            Text("Tessera")
              .font(.system(size: 48, weight: .bold, design: .rounded))
              .foregroundStyle(.white.opacity(0.8))
          },
        ],
        edgeBehavior: .finite,
      )
      .background(.black)
      .ignoresSafeArea()
      .tabItem {
        Label("Canvas", systemImage: "rectangle.and.pencil.and.ellipsis")
      }
    }
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
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 34, height: 34)),
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
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 34, height: 34)),
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
      collisionShape: .circle(center: .zero, radius: 20),
    ) {
      Image(systemName: "party.popper.fill")
        .foregroundStyle(.red.opacity(0.5))
        .font(.largeTitle)
    }
  }

  /// A minus glyph.
  static var minus: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 4)),
    ) {
      Text("-")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// An equals glyph.
  static var equals: TesseraItem {
    TesseraItem(
      collisionShape: .rectangle(center: .zero, size: CGSize(width: 36, height: 12)),
    ) {
      Text("=")
        .foregroundStyle(.gray)
        .font(.largeTitle)
    }
  }

  /// A subtle circle outline.
  static var circleOutline: TesseraItem {
    TesseraItem(
      collisionShape: .circle(center: .zero, radius: 15),
    ) {
      Circle()
        .stroke(lineWidth: 4)
        .foregroundStyle(.gray.opacity(0.2))
        .frame(width: 30, height: 30)
    }
  }
}
