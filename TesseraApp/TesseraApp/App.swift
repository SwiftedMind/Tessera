// By Dennis Müller

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
  }
}

struct AboutView: View {
  var body: some View {
    Text("HELLO, World")
  }
}

