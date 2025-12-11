// By Dennis Müller

import SwiftUI

@main
struct TesseraApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: TesseraDocument()) { file in
      Root(document: file.$document)
    }
    .defaultPosition(.center)
    .defaultSize(width: 1000, height: 800)
  }
}
