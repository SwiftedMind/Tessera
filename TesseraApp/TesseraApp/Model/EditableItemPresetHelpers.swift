// By Dennis Müller

import CoreText
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum EditableItemPresetHelpers {
  /// Expands a rectangle's collision shape to account for stroke width.
  ///
  /// - Parameter style: Style providing the base size and stroke width.
  /// - Returns: A size adjusted for the stroke radius.
  static func rectangleCollisionSize(for style: ItemStyle) -> CGSize {
    CGSize(
      width: style.size.width + style.lineWidth,
      height: style.size.height + style.lineWidth,
    )
  }

  /// Calculates a circular collision radius that includes stroke width.
  ///
  /// - Parameter style: Style providing the base diameter and stroke width.
  /// - Returns: The radius used for collision detection.
  static func circleRadius(for style: ItemStyle) -> CGFloat {
    max(style.size.width, style.size.height) / 2 + style.lineWidth / 2
  }

  /// Extracts a corner radius from preset options, falling back when missing.
  ///
  /// - Parameters:
  ///   - options: Preset options that may include a corner radius.
  ///   - fallback: Default radius to use when no value is provided.
  /// - Returns: The corner radius applied to rounded shapes.
  static func cornerRadius(from options: PresetSpecificOptions, fallback: CGFloat) -> CGFloat {
    options.cornerRadius ?? fallback
  }

  /// Selects the system symbol name from preset options or a default.
  ///
  /// - Parameters:
  ///   - options: Preset options that may include a system symbol name.
  ///   - defaultSymbolName: Fallback symbol when none is provided.
  /// - Returns: The symbol name to render.
  static func symbolName(from options: PresetSpecificOptions, defaultSymbolName: String) -> String {
    options.systemSymbolName ?? defaultSymbolName
  }

  /// Selects the text content from preset options or a default placeholder.
  ///
  /// - Parameter options: Preset options that may include custom text content.
  /// - Returns: The text string to render.
  static func textContent(from options: PresetSpecificOptions) -> String {
    options.textContent ?? "Text"
  }

  /// Measures the rendered size of text content for a preset.
  ///
  /// - Parameters:
  ///   - style: Style providing font size and weight.
  ///   - options: Preset options that may include custom text content.
  /// - Returns: The measured size including a small padding buffer.
  static func measuredTextSize(for style: ItemStyle, options: PresetSpecificOptions) -> CGSize {
    let content = textContent(from: options)
    let font = NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)

    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let attributedString = NSAttributedString(string: content, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributedString)

    let width = ceil(CTLineGetTypographicBounds(line, nil, nil, nil))

    let coreTextFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
    let ascent = CTFontGetAscent(coreTextFont)
    let descent = CTFontGetDescent(coreTextFont)
    let leading = CTFontGetLeading(coreTextFont)

    let height = ceil(ascent + descent + leading)
    let padding: CGFloat = 2

    return CGSize(width: width + padding, height: height + padding)
  }

  /// Loads an embedded image playground asset and wraps it in a SwiftUI Image.
  ///
  /// - Parameter options: Preset options that may include embedded image data.
  /// - Returns: A SwiftUI image when embedded data is available, otherwise `nil`.
  static func playgroundImage(from options: PresetSpecificOptions) -> Image? {
    guard let data = options.imagePlaygroundImageData else { return nil }

    #if os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }

    return Image(nsImage: nsImage)
    #else
    guard let uiImage = UIImage(data: data) else { return nil }

    return Image(uiImage: uiImage)
    #endif
  }

  /// Loads an embedded uploaded image asset and wraps it in a SwiftUI Image.
  ///
  /// - Parameter options: Preset options that may include embedded image data.
  /// - Returns: A SwiftUI image when embedded data is available, otherwise `nil`.
  static func uploadedImage(from options: PresetSpecificOptions) -> Image? {
    guard let data = options.uploadedImageData else { return nil }

    #if os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }

    return Image(nsImage: nsImage)
    #else
    guard let uiImage = UIImage(data: data) else { return nil }

    return Image(uiImage: uiImage)
    #endif
  }
}
