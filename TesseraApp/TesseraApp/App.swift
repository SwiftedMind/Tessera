// By Dennis Müller

import SwiftPackageListUI
import SwiftUI

@main
struct TesseraApp: App {
  @Environment(\.openWindow) private var openWindow

  var body: some Scene {
    DocumentGroup(newDocument: TesseraDocument()) { file in
      Root(document: file.$document)
    }
    .defaultPosition(.center)
    .defaultSize(width: 1000, height: 800)
    .commands {
      CommandGroup(replacing: CommandGroupPlacement.appInfo) {
        Button(action: {
          openWindow(id: "about")
        }, label: {
          Text("About My App")
        })
      }
    }
    Window("About My App", id: "about") {
      AboutView()
    }
    .defaultSize(width: 250, height: 300)
    Window("Acknowledgements", id: "acknowledgements") {
      NavigationStack {
        AcknowledgementsView()
      }
    }
    .defaultSize(width: 520, height: 640)
  }
}

struct AboutView: View {
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    NavigationStack {
      VStack( spacing: .medium) {
        Image(.tesseraAppIcon)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 100, height: 100)
          .clipShape(.rect(cornerRadius: 15))
        Text("Tessera")
          .font(.title)
          .fontWeight(.semibold)
        
        Spacer()
        
        Divider()
        
        Button("Acknowledgements…") {
          openWindow(id: "acknowledgements")
        }
      }
      .padding()
      .frame(minWidth: 250)
    }
  }
}

struct AcknowledgementsView: View {
  var body: some View {
    NavigationStack {
      AcknowledgmentsList()
    }
  }
}
