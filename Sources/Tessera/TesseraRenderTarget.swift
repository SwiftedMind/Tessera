// By Dennis Müller

import SwiftUI

/// Describes the rendering destination for a Tessera view hierarchy.
public enum TesseraRenderTarget: Sendable {
  case screen
  case exportPNG
  case exportPDF
}

private struct TesseraRenderTargetKey: EnvironmentKey {
  static let defaultValue: TesseraRenderTarget = .screen
}

public extension EnvironmentValues {
  /// Current rendering destination for Tessera content.
  var tesseraRenderTarget: TesseraRenderTarget {
    get { self[TesseraRenderTargetKey.self] }
    set { self[TesseraRenderTargetKey.self] = newValue }
  }
}

public extension View {
  /// Sets the Tessera rendering destination for the view hierarchy.
  func tesseraRenderTarget(_ target: TesseraRenderTarget) -> some View {
    environment(\.tesseraRenderTarget, target)
  }
}
