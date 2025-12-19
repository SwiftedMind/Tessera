// By Dennis Müller

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Copies collision editor output to the system pasteboard.
enum CollisionEditorPasteboard {
  static func copy(_ value: String) {
    #if os(iOS)
    UIPasteboard.general.string = value
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #endif
    
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
      print(value)
    }
  }
}
