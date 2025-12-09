// By Dennis Müller

import SwiftUI
import Tessera

/*
 
 TODOS:
 - Add/Remove Tessera Items in UI (Start with the demo items as list)
 - Manage each item's options in the UI
 - Manage overall Tessera options in the UI
 - Export button must be split into a menu with png and pdf and must show a file picker to specify the target location
 
 */

struct Root: View {
  @State private var isPresented: Bool = true
  @State private var isEnabled: Bool = true

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

    ZStack {
      if isEnabled {
        TesseraPattern(demoTessera, seed: 0)
          .ignoresSafeArea()
          .transition(.opacity)
          .backgroundExtensionEffect()
      }
      
      ZStack {
        if isEnabled == false {
          demoTessera
            .transition(.opacity.combined(with: .scale(1.2)))
        }
      }
    }
    .animation(.default, value: isEnabled)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Toggle("Repeat Pattern", isOn: $isEnabled)
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Export") {
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
    .inspector(isPresented: $isPresented) {
      VStack {
        Image(systemName: "heart.fill")
          .imageScale(.large)
          .foregroundStyle(.red)
        Text("This is an inspector")
      }
      .toolbar {
        Button {
          isPresented.toggle()
        } label: {
          Image(systemName: "sidebar.right")
        }
      }
    }
  }
}

#Preview {
  Root()
    .frame(width: 800, height: 500)
}
